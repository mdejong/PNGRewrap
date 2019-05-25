#import <Foundation/Foundation.h>

@interface NSData (NSDataExtension)

// ZLIB
- (NSData *) zlibInflate;
- (NSData *) zlibDeflate;

- (void)zlibInflateIntoBuffer:(void*)buffer numBytes:(int)numBytes;

// Decompress file created by gzip (gzip header + data)
- (NSData *) gzipInflate;

// Compress gzip file

- (NSData *) gzipDeflate;

// Decompres a gzip file and save the data to the tmp dir,
// all the data is not stored in memory, instead one
// chunk at a time is written to the output file. This
// method returns the path of the decompressed file.

+ (NSString*) uncompressGZIPFileToTmpFile:(NSString*)gzPath;

// CRC32
- (unsigned int)crc32;

// Get last path component for either a URL string or a filename.

+ (NSString*) lastURLOrPathComponent:(NSString*)path;

// Trim extenson off the filename. For example, a "foo.bar.bz2" path without
// the extension would be "foo.bar".

+ (NSString*) filenameWithoutExtension:(NSString*)filename extension:(NSString*)extension;	

@end