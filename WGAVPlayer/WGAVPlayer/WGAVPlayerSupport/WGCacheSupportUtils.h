//
//  WGCacheSupportUtils.h
//  WG
//
//  Created by wanghongzhi on 2017/7/4.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

@import Foundation;
@import AVFoundation.AVAssetResourceLoader;

FOUNDATION_EXTERN const NSRange WGInvalidRange;
FOUNDATION_EXTERN NSString *const WGCacheSubDirectoryName;

NS_INLINE BOOL WGValidByteRange(NSRange range)
{
    return ((range.location != NSNotFound) || (range.length > 0));
}

NS_INLINE BOOL WGValidFileRange(NSRange range)
{
    return ((range.location != NSNotFound) && range.length > 0 && range.length != NSUIntegerMax);
}

NS_INLINE BOOL WGRangeCanMerge(NSRange range1,NSRange range2)
{
    return (NSMaxRange(range1) == range2.location) || (NSMaxRange(range2) == range1.location) || NSIntersectionRange(range1, range2).length > 0;
}

NS_INLINE NSString* WGRangeToHTTPRangeHeader(NSRange range)
{
    if (WGValidByteRange(range))
    {
        if (range.location == NSNotFound)
        {
            return [NSString stringWithFormat:@"bytes=-%tu",range.length];
        }
        else if (range.length == NSUIntegerMax)
        {
            return [NSString stringWithFormat:@"bytes=%tu-",range.location];
        }
        else
        {
            return [NSString stringWithFormat:@"bytes=%tu-%tu",range.location, NSMaxRange(range) - 1];
        }
    }
    else
    {
        return nil;
    }
}

NS_INLINE NSString* WGRangeToHTTPRangeReponseHeader(NSRange range,NSUInteger length)
{
    if (WGValidByteRange(range))
    {
        NSUInteger start = range.location;
        NSUInteger end = NSMaxRange(range) - 1;
        if (range.location == NSNotFound)
        {
            start = range.location;
        }
        else if (range.length == NSUIntegerMax)
        {
            start = length - range.length;
            end = start + range.length - 1;
        }
        return [NSString stringWithFormat:@"bytes %tu-%tu/%tu",start,end,length];
    }
    else
    {
        return nil;
    }
}

NS_INLINE NSString *WGCacheDocumentyDirectory()
{
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (directories.count > 0)
    {
        return [[directories firstObject] stringByAppendingPathComponent:WGCacheSubDirectoryName];
    }
    return nil;
}

@interface NSString (WGCacheSupport)
- (NSString *)md5;
@end

@interface NSURLRequest (WGCacheSupport)
@property (nonatomic, readonly) NSRange range;
@end

@interface NSHTTPURLResponse (WGCacheSupport)
- (long long)fileLength;
- (BOOL)supportRange;
@end

@interface AVAssetResourceLoadingRequest (WGCacheSupport)
- (void)fillContentInformation:(NSHTTPURLResponse *)response;
@end



