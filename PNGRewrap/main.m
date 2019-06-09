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

#import "CGFrameBuffer.h"

#import "EPNGDecoder.h"

#import <zlib.h>

// Calculate width and height of PNG image that will contain the binary
// data chunk.

void calcWidthAndHeight(int numBytes, int *widthPtr, int *heightPtr) {
  const int widthMAX = 16384;
  int widthMAXPixels = (widthMAX / 3);
  if ((widthMAX % 3) > 0) {
    widthMAXPixels++;
  }
  
  int numPixelsNeeded = numBytes / 3;
  if ((numBytes % 3) != 0) {
    numPixelsNeeded++;
  }
  
  if ((numPixelsNeeded % 2) != 0) {
    // Width is always an even number of pixels
    numPixelsNeeded++;
  }
  
  // FIXME: output should group sets of 3 bytes into 24 BPP pixels, so the
  // width of the output should handle 3x more?
  
  if (numBytes <= widthMAXPixels) {
    *widthPtr = numPixelsNeeded;
    *heightPtr = 1;
    return;
  } else {
    int n = numPixelsNeeded / widthMAXPixels;
    if ((numPixelsNeeded % widthMAXPixels) != 0) {
      n++;
    }
    
    *widthPtr = widthMAXPixels;
    *heightPtr = n;
    return;
  }
}

// Write a binary data buffer into PNG context bytes and then
// save the context data out to PNG

NSData* renderDataAsPNG(NSData *inData, int bitmapWidth, int bitmapHeight)
{
  int byteLen = (int) inData.length;
  
  int bitmapLength = (int) (bitmapWidth * bitmapHeight);
  
  //assert(bitmapLength >= byteLen);
  
  CGFrameBuffer *fb = [CGFrameBuffer cGFrameBufferWithBppDimensions:24 width:bitmapWidth height:bitmapHeight];
  
  // Explicitly mark colorspace as sRGB
  
//  CGColorSpaceRef colorSpace = NULL;
//  colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
//  assert(colorSpace);
//  fb.colorspace = colorSpace;
//  CGColorSpaceRelease(colorSpace);
  
  // Each 24 bit RGB pixel will contain 3 bytes, so break input up into triples and zero fill.
  
  int numPixels = byteLen / 3;
  int numBytesOver = (byteLen % 3);
  
  int totalNumPixels = numPixels;
  if (numBytesOver > 0) {
    totalNumPixels += 1;
  }
  if ((totalNumPixels % 2) != 0) {
    totalNumPixels += 1;
  }
  //assert(totalNumPixels == bitmapLength);
  assert(totalNumPixels <= bitmapLength);
  
  uint8_t *inBytePtr = (uint8_t *) inData.bytes;
  uint32_t *outPixelPtr = (uint32_t *) fb.pixels;
  
  for (int i = 0; i < numPixels; i++) {
    uint32_t B = *inBytePtr++;
    uint32_t G = *inBytePtr++;
    uint32_t R = *inBytePtr++;
    
    uint32_t pixel = (R << 16) | (G << 8) | (B);
    
    *outPixelPtr++ = pixel;
  }
  
  // Emit 1 or 2 more bytes (zero padded)
  
  if (numBytesOver == 1) {
    uint32_t B = *inBytePtr++;
    uint32_t pixel = B;
    *outPixelPtr++ = pixel;
  } else if (numBytesOver == 2) {
    uint32_t B = *inBytePtr++;
    uint32_t G = *inBytePtr++;
    uint32_t pixel = (G << 8) | (B);
    *outPixelPtr++ = pixel;
  }
  
  if ((0)) {
    outPixelPtr = (uint32_t *) fb.pixels;
    
    for (int y = 0; y < bitmapHeight; y++) {
      for (int x = 0; x < bitmapWidth; x++) {
        uint32_t pixel = outPixelPtr[(y * bitmapWidth) + x];
        fprintf(stdout, "0x%08X ", pixel);
      }
      fprintf(stdout, "\n");
    }
  }
  
  // FIXME: trailing size as 16 bit value to indicate num zeros?
  
  // Create bitmap image info from pixel data in current context
  CGImageRef imageRef = [fb createCGImageRef];
  
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
      printf("wrap the contents of infile as IDAT chunk and write as output.png\n");
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
    
    // A really really large file cannot be represented by a 4 byte size value
    
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
