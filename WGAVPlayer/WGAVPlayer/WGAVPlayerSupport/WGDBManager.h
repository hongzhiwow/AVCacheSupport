//
//  WGDBManager.h
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/8/4.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN NSString * const kKey;
FOUNDATION_EXTERN NSString * const kValue;


@interface WGDBManager : NSObject

+ (instancetype)sharedManager;
+ (NSString *)stringFormDictionary:(NSDictionary *)dictionary;
+ (NSDictionary *)getMapFromString:(NSString *)string;

- (BOOL)insertDBWithURL:(NSURL *)URL value:(NSString *)value;
- (BOOL)updateDBWithURL:(NSURL *)URL value:(NSString *)value;
- (BOOL)deleteDBWithKey:(NSString *)key;
- (NSDictionary *)selectDBWithURL:(NSURL *)URL;


/**
 最好不用
 */
- (void)closeDB;


@end
