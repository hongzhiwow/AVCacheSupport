//
//  AVPlayerItem+WGCacheSupport.m
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/7/6.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

#import "AVPlayerItem+WGCacheSupport.h"
#import "WGCacheLoader.h"
#import <objc/runtime.h>
#import "WGCacheSupportUtils.h"

@implementation AVPlayerItem (WGCacheSupport)

+ (void)load
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self excuteSchedule];
    });
}

+ (AVPlayerItem *)wg_playerItemWithURL:(NSURL *)URL
{
    WGCacheLoader *loader = [[WGCacheLoader alloc] initWithURL:URL];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[self valideURL:URL]  options:nil];
    [asset.resourceLoader setDelegate:loader queue:loader.underlyingQueue];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    objc_setAssociatedObject(item, @selector(wg_playerItemWithURL:), loader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return item;
}

- (void)cancelPendings
{
    WGCacheLoader *loader = objc_getAssociatedObject(self, @selector(wg_playerItemWithURL:));
    [loader cancelLoader];
}

- (void)setSuspend:(BOOL)suspend
{
    WGCacheLoader *loader = objc_getAssociatedObject(self, @selector(wg_playerItemWithURL:));
    [loader setSuspend:suspend];
}

+ (NSURL *)valideURL:(NSURL *)URL
{
    if ([URL isFileURL]) {
        return URL;
    }
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    components.scheme = @"stream";
    return components.URL;
}

+ (void)removeVideoCache
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:WGCacheDocumentyDirectory()];
        NSString *fileName;
        while (fileName = [enumerator nextObject]) {
            NSString *filePath = [WGCacheDocumentyDirectory() stringByAppendingPathComponent:fileName];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    });
}

+ (void)excuteSchedule
{
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:WGCacheDocumentyDirectory()];
    NSString *fileName;
    while (fileName = [enumerator nextObject]) {
        NSString *filePath = [WGCacheDocumentyDirectory() stringByAppendingPathComponent:fileName];
        NSDate *date = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil].fileModificationDate;
        
        if ([[NSDate date] timeIntervalSinceDate:date] > 24 * 60 * 60) {
            if ([[filePath pathExtension] isEqualToString:@"idx"]) {
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[[filePath componentsSeparatedByString:@"."] firstObject] error:nil];
            }
        }
    }
}

@end
