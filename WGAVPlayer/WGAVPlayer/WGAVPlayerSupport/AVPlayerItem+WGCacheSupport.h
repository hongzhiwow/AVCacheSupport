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

/**
 播放器释放之前必须调用
 */
- (void)cancelPendings;

- (void)setSuspend:(BOOL)suspend;

+ (void)removeVideoCache;

@end
