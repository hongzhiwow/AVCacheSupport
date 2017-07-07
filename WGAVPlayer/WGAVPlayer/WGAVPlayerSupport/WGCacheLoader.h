//
//  WGCacheLoader.h
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/7/6.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

@import AVFoundation;
@import Foundation;

@interface WGCacheLoader : NSObject <AVAssetResourceLoaderDelegate>

@property (nonatomic, strong, readonly) dispatch_queue_t underlyingQueue;

- (instancetype)initWithURL:(NSURL *)URL preload:(BOOL)ispreload;
@end
