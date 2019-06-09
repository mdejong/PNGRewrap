//
//  main.m
//  PNGRewrap
//
//  Created by Mo DeJong on 5/24/19.
//  See LICENSE for license terms.
//
//  pngrewrap infile output.png
//
//  Wrap the bytes of infile as a PNG format file and write to output.png.

#import <Foundation/Foundation.h>

#import "EPNGDecoder.h"

#import <zlib.h>

// Calculate width and height of PNG image, this size was determined from
// the IDAT chunk size that xcode optimized PNG files seem to emit.

void calcWidthAndHeight(int numBytes, int *widthPtr, int *heightPtr) {
  const int widthMAX = 16384;
  
  if (numBytes <= widthMAX) {
    *widthPtr = numBytes;
    *heightPtr = 1;
    return;
  } else {
    int n = numBytes / widthMAX;
    if ((numBytes % widthMAX) != 0) {
      n++;
    }
    
    *widthPtr = widthMAX;
    *heightPtr = n;
    return;
  }
}

// Write a binary data buffer into PNG context bytes and then
// save the context data out to PNG

NSData* renderDataAsPNG(NSData *inData, int bitmapWidth, int bitmapHeight)
{
  int len = (int) inData.length;
  
  int bitmapLength = bitmapWidth * bitmapHeight;
  
  // Grayscale color space
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  
  // Create bitmap content with current image size and grayscale colorspace
  CGContextRef context = CGBitmapContextCreate(nil, bitmapWidth, bitmapHeight, 8, bitmapWidth, colorSpace, kCGImageAlphaNone);
  
  assert(CGBitmapContextGetBytesPerRow(context) == bitmapWidth);
  
  // Copy input data into context buffer
  
  uint8_t *contextPtr = (uint8_t *) CGBitmapContextGetData(context);
  assert(contextPtr != NULL);
  assert(len <= bitmapLength);
  
  memset(contextPtr, 0, bitmapLength);
  memcpy(contextPtr, inData.bytes, len);
  
  if ((0)) {
    uint8_t *outPixelPtr = contextPtr;
    
    for (int y = 0; y < bitmapHeight; y++) {
      for (int x = 0; x < bitmapWidth; x++) {
        uint8_t pixel = outPixelPtr[(y * bitmapWidth) + x];
        fprintf(stdout, "0x%02X ", pixel);
      }
      fprintf(stdout, "\n");
    }
  }
  
  // Create bitmap image info from pixel data in current context
  CGImageRef imageRef = CGBitmapContextCreateImage(context);
  
  // Generate PNG from CGImageRef
  
  NSMutableData *mData = [NSMutableData data];
  
  @autoreleasepool {
    
    // Render buffer as a PNG image
    
    CFStringRef type = kUTTypePNG;
    size_t count = 1;
    CGImageDestinationRef dataDest;
    dataDest = CGImageDestinationCreateWithData((CFMutableDataRef)mData,
                                                type,
                                                count,
                                                NULL);
    assert(dataDest);
    
    //CGImageRef imgRef = [self createCGImageRef];
    
    CGImageDestinationAddImage(dataDest, imageRef, NULL);
    CGImageDestinationFinalize(dataDest);
    
    CFRelease(dataDest);
  }
  
  CGImageRelease(imageRef);
  
  return [NSData dataWithData:mData];
}

int main(int argc, const char * argv[]) {
  @autoreleasepool {
    if (argc != 3) {
      printf("pngrewrap infile output.png\n");
      printf("wrap the raw bytes of infile as IDAT chunk(s) and write as output.png\n");
      exit(1);
    }
    
    NSString *inBinFilename = [NSString stringWithFormat:@"%s", argv[1]];
    NSString *outPNGFilename = [NSString stringWithFormat:@"%s", argv[2]];
    
    NSData *inBinData = [NSData dataWithContentsOfFile:inBinFilename];
    int inBinDataNumBytes = (int) inBinData.length;
    
    if (inBinData == nil) {
      printf("could not read input data file \"%s\"\n", (char*)[inBinFilename UTF8String]);
      exit(2);
    }
    
    // A really really large file cannot be represented by a 4 byte size value, this logic
    // now emits multiple IDAT chunks but some upper limit cannot hurt.
    
    if ((inBinData.length+1) >= 0xFFFFFFFF) {
      printf("input data file size is too large\n");
      exit(3);
    }
    
    // CRC for input data
    
    uint32_t inputCRC = (uint32_t) crc32(0L, (unsigned char *)inBinData.bytes, (int)inBinData.length);
    if (1) {
    printf("input  CRC 0x%08X based on %d input bytes\n", inputCRC, (int)inBinData.length);
    }
    
    if ((0)) {
      uint8_t *pixelsPtr = (uint8_t *) inBinData.bytes;
      int numPixels = (int) inBinData.length;
      
      for (int i = 0; i < numPixels; i++) {
        uint8_t pixel = pixelsPtr[i];
        printf("buffer[%d] = 0x%02X\n", i, pixel);
      }
    }

    int imageWidth, imageHeight;
    
    calcWidthAndHeight((int)inBinData.length, &imageWidth, &imageHeight);
    
    if ((0)) {
      imageWidth = 4;
      imageHeight = 4;
      
      uint8_t inBuffer[] = {
        0, 1, 2, 3,
        4, 5, 6, 7,
        8, 9, 10, 11,
        12, 13, 14, 15
      };
      
      inBinData = [NSData dataWithBytes:inBuffer length:16];
      
      inputCRC = (uint32_t) crc32(0L, (unsigned char *)inBinData.bytes, (int)inBinData.length);
      
      if (1) {
        printf("input  CRC 0x%08X based on %d input bytes\n", inputCRC, (int)inBinData.length);
      }
    }
    
    NSData *pngBytes = renderDataAsPNG(inBinData, imageWidth, imageHeight);
    
    // Write contents of PNG buffer
    
    BOOL worked = [pngBytes writeToFile:outPNGFilename atomically:TRUE];
    if (worked == FALSE) {
      printf("write failed to \"%s\"\n", (char*)[outPNGFilename UTF8String]);
      exit(2);
    } else {
      printf("wrote \"%s\" (%d x %d) as %d bytes\n", (char*)[outPNGFilename UTF8String], imageWidth, imageHeight, (int) pngBytes.length);
    }
    
    if ((1)) {
      // Validate PNG written to disk
      
      CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)pngBytes, NULL);
      
      if (imageSource == NULL){
        fprintf(stderr, "Could not parse PNG data back into image");
        exit(1);;
      }
      
      CGImageRef pngImgRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
      
      NSString *pathPrefix = @"fileXXXXXX.bin";
      NSString *curDir = [[[NSFileManager alloc] init] currentDirectoryPath];
      int decodeCRC = 0;
      NSURL *url = [EPNGDecoder saveEmbeddedAssetToTmpDir:pngImgRef pathPrefix:pathPrefix tmpDir:curDir decodeCRC:&decodeCRC];
      
      if (url == NULL){
        fprintf(stderr, "Could not parse embedded data buffer from PNG");
        exit(2);;
      }
      
      if (inputCRC != decodeCRC){
        fprintf(stderr, "Decode CRC did not match input CRC : input != decode : %0x08X != %0x08X", inputCRC, decodeCRC);
        exit(3);;
      }
      
      NSString *path = [url path];
      unlink([path UTF8String]);
      
      CGImageRelease(pngImgRef);
      CFRelease(imageSource);
    }
  }
  return 0;
}
