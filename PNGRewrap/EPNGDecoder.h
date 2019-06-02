//
//  EPNGDecoder.h
//
//  Created by Mo DeJong on 6/1/19.
//  See LICENSE for license terms.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EPNGDecoder : NSObject

// Return unique file path in temp dir, pass in a template like
// @"videoXXXXXX.m4v" to define the path name tempalte. If
// tmpDir is nil then NSTemporaryDirectory() is used.
// If decodeCRC is not NULL then a CRC is calculated on
// the decoded buffer.

+ (NSURL*) saveEmbeddedAssetToTmpDir:(CGImageRef)cgImage
                          pathPrefix:(NSString*)pathPrefix
                              tmpDir:(NSString*)tmpDir
                           decodeCRC:(int*)decodeCRC;

@end

NS_ASSUME_NONNULL_END
