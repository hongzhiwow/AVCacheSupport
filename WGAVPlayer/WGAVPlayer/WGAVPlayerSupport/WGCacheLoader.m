//
//  WGCacheLoader.m
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/7/6.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

#import "WGCacheLoader.h"
#import "WGCacheSupportUtils.h"
#import <objc/runtime.h>

static NSString *WGCacheHeaderKey = @"header";
static NSString *WGCacheZoneKey = @"zone";
static NSString *WGCacheSizeKey = @"size";

const void *WGLoadingRequestKey = "wg_cache_loading_request_key";
const void *WGTaskOffsetKey = "wg_cache_loading_offset_key";

const NSRange WGPreloadRange = {0,100 * 1024};

@interface WGCacheLoader () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSDictionary *responseHeader;
@property (nonatomic, strong) NSMutableArray *ranges;
@property (nonatomic, assign) NSUInteger fileLength;
@property (nonatomic, strong) NSFileHandle *fileHandle;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *workQueue;
@property (nonatomic, strong) NSURL *currentURL;
@property (nonatomic, strong) NSMutableArray *pendingRequest;

@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, copy) NSString *indexPath;


@end

@implementation WGCacheLoader

#pragma mark -
#pragma mark - life cycle
- (instancetype)initWithURL:(NSURL *)URL preload:(BOOL)ispreload
{
    if ([URL isFileURL]) {
        return nil;
    }
    self = [super init];
    if (self) {
        _underlyingQueue = dispatch_queue_create("com.weiguan.cache.queue", DISPATCH_QUEUE_SERIAL);
        _workQueue = [[NSOperationQueue alloc] init];
        _workQueue.underlyingQueue = _underlyingQueue;
        _currentURL = URL;
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:_workQueue];
        
        if (![self initFile]) {
            return nil;
        }
        
        if (ispreload) {
            [self preloadWithRange:WGPreloadRange];
        }
        
    }
    return self;
}
- (NSMutableArray *)ranges
{
    if (!_ranges) {
        _ranges = [@[] mutableCopy];
    }
    return _ranges;
}

- (NSMutableArray *)pendingRequest
{
    if (!_pendingRequest) {
        _pendingRequest = [@[] mutableCopy];
    }
    return _pendingRequest;
}

#pragma mark -
#pragma mark - file
- (BOOL)initFile
{
    _cachePath = [WGCacheDocumentyDirectory() stringByAppendingPathComponent:[self.currentURL.absoluteString md5]];
    _indexPath = [_cachePath stringByAppendingString:[self indexFileExtension]];
    BOOL cacheFileExist = [[NSFileManager defaultManager] fileExistsAtPath:_cachePath];
    BOOL indexFileExist = [[NSFileManager defaultManager] fileExistsAtPath:_indexPath];
    
    BOOL fileExist = cacheFileExist && indexFileExist;
    if (!fileExist)
    {
        NSString *directory = [_cachePath stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:directory])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        fileExist = [[NSFileManager defaultManager] createFileAtPath:_cachePath contents:nil attributes:nil];
        fileExist = fileExist && [[NSFileManager defaultManager] createFileAtPath:_indexPath contents:nil attributes:nil];
    }
    return fileExist;
}

- (void)constructResponseWithRange:(NSRange)range
{
    if (!self.response && self.responseHeader.count > 0)
    {
        if (range.length == NSUIntegerMax)
        {
            range.length = _fileLength - range.location;
        }
        
        NSMutableDictionary *responseHeaders = [self.responseHeader mutableCopy];
        NSString *contentRangeKey = @"Content-Range";
        BOOL supportRange = responseHeaders[contentRangeKey] != nil;
        if (supportRange && WGValidByteRange(range))
        {
            responseHeaders[contentRangeKey] = WGRangeToHTTPRangeReponseHeader(range, _fileLength);
        }
        else
        {
            [responseHeaders removeObjectForKey:contentRangeKey];
        }
        responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu",range.length];
        
        NSInteger statusCode = supportRange ? 206 : 200;
        self.response = [[NSHTTPURLResponse alloc] initWithURL:self.currentURL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:responseHeaders];
    }
}

- (NSDictionary *)readIndexFile
{
    NSString *indexString = [NSString stringWithContentsOfFile:_indexPath
                                                      encoding:NSUTF8StringEncoding error:nil];
    NSData *data = [indexString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *map = [NSJSONSerialization JSONObjectWithData:data
                                                        options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
                                                          error:nil];
    return map;
}


- (BOOL)serializeIndex:(NSDictionary *)map
{
    if (![map isKindOfClass:[NSDictionary class]])
    {
        return NO;
    }
    
    NSNumber *fileSize = map[WGCacheSizeKey];
    if (fileSize && [fileSize isKindOfClass:[NSNumber class]])
    {
        _fileLength = [fileSize unsignedIntegerValue];
    }
    
    if (_fileLength == 0)
    {
        return NO;
    }
    
    
    [self.ranges removeAllObjects];
    NSMutableArray *rangeArray = map[WGCacheZoneKey];
    if (!rangeArray.count) {
        return NO;
    }
    for (NSString *rangeStr in rangeArray)
    {
        NSRange range = NSRangeFromString(rangeStr);
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    
    self.responseHeader = map[WGCacheHeaderKey];
    
    return YES;
}

- (NSString *)unserializeIndex
{
    NSMutableArray *rangeArray = [[NSMutableArray alloc] init];
    for (NSValue *range in self.ranges)
    {
        [rangeArray addObject:NSStringFromRange([range rangeValue])];
    }
    NSMutableDictionary *dict = [@{
                                   WGCacheSizeKey: @(_fileLength),
                                   WGCacheZoneKey: rangeArray
                                   } mutableCopy];
    if (self.responseHeader)
    {
        dict[WGCacheHeaderKey] = self.responseHeader;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (data)
    {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void)synchronizeIndexFile
{
    NSString *indexStr = [self unserializeIndex];
    [indexStr writeToFile:_indexPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (NSString *)indexFileExtension
{
    return @".idx";
}

#pragma mark -
#pragma mark - AVAssetResourceLoaderDelegate
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self handleLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    for (NSURLSessionDataTask *task in self.pendingRequest) {
        AVAssetResourceLoadingRequest *request = objc_getAssociatedObject(task, WGLoadingRequestKey);
        if (request.isCancelled) {
            [task cancel];
        }
    }
}


#pragma mark -
#pragma mark - handle loadingRequest

- (void)preloadWithRange:(NSRange)range
{
    NSDictionary *map = [self readIndexFile];
    NSRange r = WGInvalidRange;
    
    if ([self serializeIndex:map]) {
        r = [self cachedRangeForRange:range];
        if (!WGValidByteRange(range)) {
            r = range;
            goto sendrequest;
        }
        goto checklocal;
    } else {
        r = range;
        goto sendrequest;
    }
    
sendrequest:
    [self sendRemoteRequest:nil withRange:r];
    return;
    
checklocal:
    if (NSMaxRange(r) < NSMaxRange(range)) {
        r = NSMakeRange(NSMaxRange(r), NSMaxRange(range) - NSMaxRange(r));
        goto sendrequest;
    }
    
}

- (void)handleLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSDictionary *map = [self readIndexFile];
    NSRange range = WGInvalidRange;
    NSRange reqRange = NSMakeRange(loadingRequest.dataRequest.requestedOffset, loadingRequest.dataRequest.requestedLength);
    if ([self serializeIndex:map]) {
        range = [self cachedRangeForRange:reqRange];
        if (!WGValidByteRange(range)) {
            range = reqRange;
            goto cacheremote;
        }
        goto cachelocal;
    } else {
        goto cacheremote;
    }
    
cacheremote:
    [self sendRemoteRequest:loadingRequest withRange:range];
    return;
    
cachelocal:
    //读取本地资源
    [self getLocalRequest:loadingRequest withRange:range];
    if (NSMaxRange(range) < NSMaxRange(reqRange)) {
        range = NSMakeRange(NSMaxRange(range), NSMaxRange(reqRange) - NSMaxRange(range));
        goto cacheremote;
    }
}

- (NSRange)cachedRangeForRange:(NSRange)range
{
    NSRange cachedRange = [self cachedRangeContainsPosition:range.location];
    NSRange ret = NSIntersectionRange(cachedRange, range);
    if (ret.length > 0)
    {
        return ret;
    }
    else
    {
        return WGInvalidRange;
    }
}

- (NSRange)cachedRangeContainsPosition:(NSUInteger)pos
{
    if (pos >= _fileLength)
    {
        return WGInvalidRange;
    }
    
    for (int i = 0; i < self.ranges.count; ++i)
    {
        NSRange range = [self.ranges[i] rangeValue];
        if (NSLocationInRange(pos, range))
        {
            return range;
        }
    }
    return WGInvalidRange;
}

- (void)addRange:(NSRange)range
{
    if (range.length == 0 || range.location >= _fileLength)
    {
        return;
    }
    
    BOOL inserted = NO;
    for (int i = 0; i < self.ranges.count; ++i)
    {
        NSRange currentRange = [self.ranges[i] rangeValue];
        if (currentRange.location >= range.location)
        {
            [self.ranges insertObject:[NSValue valueWithRange:range] atIndex:i];
            inserted = YES;
            break;
        }
    }
    if (!inserted)
    {
        [self.ranges addObject:[NSValue valueWithRange:range]];
    }
    [self mergeRanges];
}

- (void)mergeRanges
{
    for (int i = 0; i < self.ranges.count; ++i)
    {
        if ((i + 1) < self.ranges.count)
        {
            NSRange currentRange = [self.ranges[i] rangeValue];
            NSRange nextRange = [self.ranges[i + 1] rangeValue];
            if (WGRangeCanMerge(currentRange, nextRange))
            {
                [self.ranges removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, 2)]];
                [self.ranges insertObject:[NSValue valueWithRange:NSUnionRange(currentRange, nextRange)] atIndex:i];
                i -= 1;
            }
        }
    }
}


- (void)sendRemoteRequest:(AVAssetResourceLoadingRequest *)loadingRequest withRange:(NSRange)range
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.currentURL
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:20.f];
    NSRange requestRange = range;
    if (!WGValidByteRange(range) && loadingRequest) {
        requestRange = NSMakeRange(loadingRequest.dataRequest.requestedOffset, loadingRequest.dataRequest.requestedLength);
    }
    [request setValue:WGRangeToHTTPRangeHeader(requestRange) forHTTPHeaderField:@"Range"];
    
    NSURLSessionTask *dataTask = [self.session dataTaskWithRequest:request];
    objc_setAssociatedObject(dataTask, WGLoadingRequestKey, loadingRequest, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSUInteger offset = requestRange.location;
    objc_setAssociatedObject(dataTask, WGTaskOffsetKey, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [dataTask resume];
    [self.pendingRequest addObject:dataTask];
}

- (void)getLocalRequest:(AVAssetResourceLoadingRequest *)loadingRequest withRange:(NSRange)range
{
    [self constructResponseWithRange:range];
    NSData *data = [NSData dataWithContentsOfFile:_cachePath options:NSDataReadingMappedIfSafe error:nil];
    [loadingRequest fillContentInformation:self.response];
    [loadingRequest.dataRequest respondWithData:[data subdataWithRange:range]];
    if (loadingRequest.dataRequest.requestedOffset + loadingRequest.dataRequest.requestedLength <= NSMaxRange(range)) {
        [loadingRequest finishLoading];
    }
}

#pragma mark -
#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {
        AVAssetResourceLoadingRequest *loadingRequest = objc_getAssociatedObject(dataTask, WGLoadingRequestKey);
        [loadingRequest fillContentInformation:httpResponse];
        self.response = httpResponse;
        self.responseHeader = [[httpResponse allHeaderFields] copy];
        _fileLength = httpResponse.fileLength;
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.cachePath];
        [self.fileHandle truncateFileAtOffset:_fileLength];
        completionHandler(NSURLSessionResponseAllow);
        
    } else {
        completionHandler(NSURLSessionResponseCancel);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    
    AVAssetResourceLoadingRequest *loadingRequest = objc_getAssociatedObject(dataTask, WGLoadingRequestKey);
    NSUInteger offset = [objc_getAssociatedObject(dataTask, WGTaskOffsetKey) unsignedIntegerValue];
    NSMutableData *currentData = [NSMutableData data];
    [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
        [currentData appendBytes:bytes length:byteRange.length];
    }];
    [loadingRequest.dataRequest respondWithData:currentData];
    
    [self.fileHandle seekToFileOffset:offset];
    [self addRange:NSMakeRange(offset, [currentData length])];
    
    offset += currentData.length;
    [self.fileHandle writeData:currentData];
    [self.fileHandle synchronizeFile];
    [self synchronizeIndexFile];
    objc_setAssociatedObject(dataTask, WGTaskOffsetKey, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    AVAssetResourceLoadingRequest *loadingRequest = objc_getAssociatedObject((NSURLSessionDataTask *)task, WGLoadingRequestKey);
    if (error) {
        [loadingRequest finishLoadingWithError:error];
    } else {
        [loadingRequest finishLoading];
    }
    [self.pendingRequest removeObject:task];

}

- (void)dealloc
{
    [self.fileHandle closeFile];
    [self.session finishTasksAndInvalidate];
}


@end
