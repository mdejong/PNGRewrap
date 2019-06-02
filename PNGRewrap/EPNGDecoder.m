//
//  EPNGDecoder.m
//
//  Created by Mo DeJong on 6/1/19.
//  Copyright © 2019 HelpURock. All rights reserved.
//

#import "EPNGDecoder.h"

#import <zlib.h>

// class EPNGDecoder

@implementation EPNGDecoder

+ (EPNGDecoder*) ePNGDecoder
{
  EPNGDecoder *obj = [[EPNGDecoder alloc] init];
  return obj;
}

// FIXME: pass in tmp dir ?

+ (NSURL*) saveEmbeddedAssetToTmpDir:(CGImageRef)cgImage
                          pathPrefix:(NSString*)pathPrefix
                              tmpDir:(NSString*)tmpDir
{
  int bitmapWidth = (int) CGImageGetWidth(cgImage);
  int bitmapHeight = (int) CGImageGetHeight(cgImage);
  int bitmapNumPixels = bitmapWidth * bitmapHeight;
  
  CGRect imageRect = CGRectMake(0, 0, bitmapWidth, bitmapHeight);
  
  CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgImage);
  
  int bitsPerComponent = 8;
  int numComponents = 4;
  int bitsPerPixel = bitsPerComponent * numComponents;
  int bytesPerRow = (int) (bitmapWidth * (bitsPerPixel / 8));
  
  CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst;
  
  // Create bitmap content with current image size and grayscale colorspace
  CGContextRef context = CGBitmapContextCreate(NULL, bitmapWidth, bitmapHeight, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
  
  // Draw image into current context, with specified rectangle
  // using previously defined context (with grayscale colorspace)
  CGContextDrawImage(context, imageRect, cgImage);
  
  uint32_t *contextPtr = (uint32_t *) CGBitmapContextGetData(context);
  assert(contextPtr != NULL);
  
  assert(CGBitmapContextGetBytesPerRow(context) == bytesPerRow);
  
  // Walk backwards from the end of the buffer until a non-zero value is found.
  // Note that the alpha channel is ignored , only BGR components are considered.
  
  uint32_t *endPtr = contextPtr + bitmapNumPixels - 1;
  
  while (endPtr != contextPtr) {
    uint32_t pixel = *endPtr;
    //printf("0x%08X\n", pixel);
    pixel &= 0x00FFFFFF;
    if (pixel != 0) {
      // Break out when a non-zero pixel value has been located
      break;
    }
    endPtr--;
  }
  
  // FIXME: zero walk back should be in terms of byte values embedded
  // inside the pixels. Might need some special marker at the end
  // of the file to indicate the actual length of the data buffer in
  // bytes, so that when data is initially parsed, the output can be
  // cropped to the proper byte length considering overflow!

  int bufferNumPixels = (int) (endPtr - contextPtr + 1);
  int bufferNumBytes = (int) (bufferNumPixels * 3);
  
  // Collect sets of 3 bytes and append to data a byte at a time
  
  NSMutableData *rawBytes = [NSMutableData dataWithLength:bufferNumBytes];
  
  {
    uint32_t *pixelsPtr = (uint32_t *) contextPtr;
    int numPixels = (int) bufferNumPixels;
    
    uint8_t *outBytesPtr = (uint8_t *) rawBytes.bytes;
    
    for (int i = 0; i < numPixels; i++) {
      uint32_t pixel = pixelsPtr[i];
      
      uint32_t B = pixel & 0xFF;
      uint32_t G = (pixel >> 8) & 0xFF;
      uint32_t R = (pixel >> 16) & 0xFF;
      
      *outBytesPtr++ = B;
      *outBytesPtr++ = G;
      *outBytesPtr++ = R;
    }
    
    // Trim zero bytes off the end
    
    outBytesPtr = (uint8_t *) rawBytes.bytes;
    
    int lastOff = (int)rawBytes.length - 1;
    int lastOff2 = (int)rawBytes.length - 2;
    
    int vEnd = outBytesPtr[lastOff];
    int vEndM1 = outBytesPtr[lastOff2];
    
    int trim = 0;
    
    if (vEnd == 0) {
      trim++;
    }
    
    if (vEndM1 == 0) {
      trim++;
    }
    
    if (trim > 0) {
      [rawBytes setLength:(rawBytes.length - trim)];
    }
  }
  
  if ((0)) {
    uint8_t *pixelsPtr = (uint8_t *) rawBytes.bytes;
    int numPixels = (int) rawBytes.length;
    
    printf("buffer contains %d bytes\n", numPixels);
    
    for (int i = 0; i < numPixels; i++) {
      uint8_t pixel = pixelsPtr[i];
      printf("buffer[%d] = 0x%02X\n", i, pixel);
    }
  }
  
  // Signature of decoded PNG data
  
  if ((1)) {
    uint32_t crc = (uint32_t) crc32(0, (void*)rawBytes.bytes, (int)rawBytes.length);
    
    printf("decode CRC 0x%08X based on %d input buffer bytes\n", crc, (int)rawBytes.length);
  }
  
  // FIXME: optimize by creating NSData with no copy flag, then write,
  // then release bitmap context
  
  // Release colorspace, context and bitmap information
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  
  NSString *tmpPath = [self getUniqueTmpDirPath:pathPrefix tmpDir:tmpDir];
  
  BOOL worked = [rawBytes writeToFile:tmpPath atomically:TRUE];
  
  if (worked == FALSE) {
    return nil;
  }
  
  NSURL *url = [NSURL fileURLWithPath:tmpPath];
  return url;
}

// Return unique file path in temp dir, pass in a template like
// @"videoXXXXXX.m4v" to define the path name tempalte. If
// tmpDir is nil then NSTemporaryDirectory() is used.

+ (NSString*) getUniqueTmpDirPath:(NSString*)pathPrefix tmpDir:(NSString*)tmpDir
{
  if (tmpDir == nil) {
    tmpDir = NSTemporaryDirectory();
  }
  
  NSString *tmpPath = [tmpDir stringByAppendingPathComponent:pathPrefix];
  
  // pathPrefix must end with 6 "XXXXXX" characters
  
  NSString *templateStr = @"XXXXXX";
  
  BOOL hasTemplate = [pathPrefix containsString:templateStr];
  
  if (!hasTemplate) {
    return nil;
  }
  
  NSRange range = [tmpPath rangeOfString:templateStr options:NSLiteralSearch|NSBackwardsSearch];
  
  // Get filename up to the end of the template
  
  NSRange rangeOfTemplate;
  rangeOfTemplate.location = 0;
  rangeOfTemplate.length = range.location + range.length;
  
  NSString *upToTemplateStr = [tmpPath substringWithRange:rangeOfTemplate];

  NSRange afterTemplate;
  afterTemplate.location = rangeOfTemplate.length;
  afterTemplate.length = [tmpPath length] - afterTemplate.location;
  
  NSString *afterTemplateStr = [tmpPath substringWithRange:afterTemplate];
  
  const char *rep = [upToTemplateStr fileSystemRepresentation];
  
  char *temp_template = strdup(rep);
  int largeFD = mkstemp(temp_template);
  NSString *largeFileName = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:temp_template length:strlen(temp_template)];
  free(temp_template);
  NSAssert(largeFD != -1, @"largeFD");
  NSAssert(largeFileName, @"largeFileName");
  close(largeFD);
  unlink(temp_template);
  
  return [largeFileName stringByAppendingString:afterTemplateStr];
}

@end
