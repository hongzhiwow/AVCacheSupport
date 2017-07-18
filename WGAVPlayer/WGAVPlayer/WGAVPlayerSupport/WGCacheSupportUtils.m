//
//  WGCacheSupportUtils.m
//  WG
//
//  Created by wanghongzhi on 2017/7/4.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

#import "WGCacheSupportUtils.h"
#import <CommonCrypto/CommonDigest.h>

@import MobileCoreServices;

static NSString *const kAVPlayerItemWGCacheSupportUrlSchemeSuffix = @"-stream";
NSString *const WGCacheSubDirectoryName = @"PlayerCache";
const NSRange WGInvalidRange = {NSNotFound,0};

@implementation NSString (WGCacheSupport)
- (NSString *)md5
{
    const char *cStr = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (int)strlen(cStr), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

@end

@implementation NSURLRequest (WGCacheSupport)
- (NSRange)range
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    NSString *rangeString = [self allHTTPHeaderFields][@"Range"];
    if ([rangeString hasPrefix:@"bytes="])
    {
        NSArray* components = [[rangeString substringFromIndex:6] componentsSeparatedByString:@","];
        if (components.count == 1)
        {
            components = [[components firstObject] componentsSeparatedByString:@"-"];
            if (components.count == 2)
            {
                NSString* startString = [components objectAtIndex:0];
                NSInteger startValue = [startString integerValue];
                NSString* endString = [components objectAtIndex:1];
                NSInteger endValue = [endString integerValue];
                if (startString.length && (startValue >= 0) && endString.length && (endValue >= startValue))
                {  // The second 500 bytes: "500-999"
                    range.location = startValue;
                    range.length = endValue - startValue + 1;
                }
                else if (startString.length && (startValue >= 0))
                {  // The bytes after 9500 bytes: "9500-"
                    range.location = startValue;
                    range.length = NSUIntegerMax;
                }
                else if (endString.length && (endValue > 0))
                {  // The final 500 bytes: "-500"
                    range.location = NSNotFound;
                    range.length = endValue;
                }
            }
        }
    }
    return range;
}
@end

@implementation NSHTTPURLResponse (WGCacheSupport)
- (long long)fileLength
{
    NSString *range = [self allHeaderFields][@"Content-Range"];
    if (range)
    {
        NSArray *ranges = [range componentsSeparatedByString:@"/"];
        if (ranges.count > 0)
        {
            NSString *lengthString = [[ranges lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            return [lengthString longLongValue];
        }
    }
    else
    {
        return [self expectedContentLength];
    }
    return 0;
}

- (BOOL)supportRange
{
    return [self allHeaderFields][@"Content-Range"] != nil;
}
@end

@implementation AVAssetResourceLoadingRequest (WGCacheSupport)
- (void)fillContentInformation:(NSHTTPURLResponse *)response
{
    if (!response)
    {
        return;
    }
    
    self.response = response;
    
    if (!self.contentInformationRequest)
    {
        return;
    }
    
    NSString *mimeType = [response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    self.contentInformationRequest.byteRangeAccessSupported = [response supportRange];
    self.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    self.contentInformationRequest.contentLength = [response fileLength];
}
@end



