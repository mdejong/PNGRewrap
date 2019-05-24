//
//  main.m
//  PNGRewrap
//
//  Created by Mo DeJong on 5/24/19.
//  Copyright © 2019 HelpURock. All rights reserved.
//
//  pngrewrap infile output.png
//
//  Wrap the bytes of infile as a PNG format file and write to output.png.

#import <Foundation/Foundation.h>

NSData* formatInt(uint32_t val) {
  NSMutableData *mData = [NSMutableData data];
  uint32_t bigVal = htonl(val); // Write as big endian network byte order
  [mData appendBytes:&bigVal length:sizeof(uint32_t)];
  return mData;
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
    
    // PNG Header
    
    // Hex   :   89  50  4e  47  0d  0a  1a   0a
    // Ascii : \211   P   N   G  \r  \n  \032 \n
    
    NSMutableData *pngBytes = [NSMutableData data];
    
    {
      uint8_t pngHeader[] = { 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a };
      [pngBytes appendBytes:pngHeader length:sizeof(pngHeader)];
    }
    
    // IHDR
    // 4 byte size of IHDR : 0x00 0x00 0x00 0x0d (13 bytes)
    // 4 byte IHDR bytes : 0x49 0x48 0x44 0x52
    
    {
      uint8_t pngHeader[] = { 0x00, 0x00, 0x00, 0x0d };
      [pngBytes appendBytes:pngHeader length:sizeof(pngHeader)];
    }
    
    {
      uint8_t pngHeader[] = { 0x49, 0x48, 0x44, 0x52 };
      [pngBytes appendBytes:pngHeader length:sizeof(pngHeader)];
    }
    
    // IHDR chunk
    // Width:              4 bytes
    // Height:             4 bytes
    // Bit depth:          1 byte
    // Color type:         1 byte
    // Compression method: 1 byte
    // Filter method:      1 byte
    // Interlace method:   1 byte
    
    {
      uint32_t width = inBinDataNumBytes;
      [pngBytes appendData:formatInt(width)];
    }
    
    {
      uint32_t height = 1;
      [pngBytes appendData:formatInt(height)];
    }
    
    {
      uint8_t pngData[] = {
        // Bit depth
        0x08,
        // Color type
        0x00,
        // Compression method
        0x00,
        // Filter method
        0x00,
        // Interlace method
        0x00
      };
      [pngBytes appendBytes:pngData length:sizeof(pngData)];
    }
    
    // IDAT
    // 4 byte size of IDAT : 0x00 0x00 0x00 0x0d (13 bytes)
    // IDAT : 0x49 0x44 0x41 0x54
    
    {
      uint32_t numBytes = inBinDataNumBytes;
      [pngBytes appendData:formatInt(numBytes)];
    }
    
    {
      uint8_t pngHeader[] = { 0x49, 0x44, 0x41, 0x54 };
      [pngBytes appendBytes:pngHeader length:sizeof(pngHeader)];
    }
    
    // The original file data as bytes
    
    [pngBytes appendData:inBinData];
    
    // End of IEND
    // 4 byte size of IEND : 0x00 0x00 0x00 0x00
    // 4 byte IEND bytes : 0x49 0x45 0x44 0x52
    
    {
      uint8_t pngHeader[] = { 0x00, 0x00, 0x00, 0x0d };
      [pngBytes appendBytes:pngHeader length:sizeof(pngHeader)];
    }
    
    {
      uint8_t pngHeader[] = { 0x49, 0x45, 0x44, 0x52 };
      [pngBytes appendBytes:pngHeader length:sizeof(pngHeader)];
    }

    // Write contents of PNG buffer
    
    BOOL worked = [pngBytes writeToFile:outPNGFilename atomically:TRUE];
    if (worked == FALSE) {
      printf("write failed to \"%s\"\n", (char*)[outPNGFilename UTF8String]);
      exit(2);
    } else {
      printf("wrote \"%s\" as %d bytes\n", (char*)[outPNGFilename UTF8String], (int) pngBytes.length);
    }
  }
  return 0;
}
