//
//  AVPlayerItem+WGCacheSupport.h
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/7/6.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//


@import AVFoundation;

@interface AVPlayerItem (WGCacheSupport)

+ (AVPlayerItem *)wg_playerItemWithURL:(NSURL *)URL;

+ (void)removeVideoCache;

@end
