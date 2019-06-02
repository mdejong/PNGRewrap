//
//  EPNGDecoder.h
//
//  Created by Mo DeJong on 6/1/19.
//  Copyright © 2019 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EPNGDecoder : NSObject

// Return unique file path in temp dir, pass in a template like
// @"videoXXXXXX.m4v" to define the path name tempalte. If
// tmpDir is nil then NSTemporaryDirectory() is used.

+ (NSURL*) saveEmbeddedAssetToTmpDir:(CGImageRef)cgImage
                          pathPrefix:(NSString*)pathPrefix
                              tmpDir:(NSString*)tmpDir;

@end

NS_ASSUME_NONNULL_END
