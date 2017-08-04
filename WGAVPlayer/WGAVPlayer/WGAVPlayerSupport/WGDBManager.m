//
//  WGDBManager.m
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/8/4.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

#import "WGDBManager.h"
#import "WGCacheSupportUtils.h"
#import <sqlite3.h>

static NSString *const kDBName = @"vc.sqlite";

NSString *const kKey = @"key";
NSString *const kValue = @"value";

@interface WGDBManager ()
{
    @private
    sqlite3 *_db;
    dispatch_semaphore_t _semaphore;
    NSString *_dbPath;
}

@end

@implementation WGDBManager

#pragma mark - life cycle

+ (instancetype)sharedManager
{
    static WGDBManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[[self class] alloc] init ];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        if (![self initDB_]) {
            @throw [NSException exceptionWithName:@"db 初始化失败" reason:@"哈哈哈 我也不知道该怎么办咯" userInfo:nil];
        };
    }
    return self;
}

#pragma mark - public 
- (NSDictionary *)selectDBWithURL:(NSURL *)URL
{
    sqlite3_stmt *statement;
    NSMutableDictionary *result = [@{} mutableCopy];
    NSString *SQLString = [NSString stringWithFormat:@"SELECT key,value FROM CACHEINDEX WHERE key = '%@'  LIMIT 1",[URL.absoluteString md5]];
    if (sqlite3_prepare_v2(_db, SQLString.UTF8String, -1, &statement, NULL) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            NSString *key = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
            NSString *value = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
            result[kKey] = key;
            result[kValue] = value;
        }
    }
    sqlite3_finalize(statement);
    
    return [result copy];
}

- (BOOL)insertDBWithURL:(NSURL *)URL value:(NSString *)value
{
    dispatch_semaphore_signal(_semaphore);
    NSString *SQLString = [NSString stringWithFormat:@"INSERT INTO CACHEINDEX (key,value) VALUES ('%@','%@')",URL.absoluteString.md5,value];
    char *error;
    BOOL ret = sqlite3_exec(_db, SQLString.UTF8String, NULL, NULL, &error) == SQLITE_OK;
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    return ret;
}

- (BOOL)updateDBWithURL:(NSURL *)URL value:(NSString *)value
{
    dispatch_semaphore_signal(_semaphore);
    NSString *SQLString = [NSString stringWithFormat:@"UPDATE CACHEINDEX SET value = '%@' WHERE key = '%@'",value,URL.absoluteString.md5];
    BOOL ret = sqlite3_exec(_db, SQLString.UTF8String, NULL, NULL, NULL) == SQLITE_OK;
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    return ret;
}

- (BOOL)deleteDBWithKey:(NSString *)key
{
    dispatch_semaphore_signal(_semaphore);
    NSString *SQLString = [NSString stringWithFormat:@"DELETE FROM CACHEINDEX WHERE key = '%@'",key];
    BOOL ret = sqlite3_exec(_db, SQLString.UTF8String, NULL, NULL, NULL) == SQLITE_OK;
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    return  ret;
}

- (void)closeDB
{
    sqlite3_close(_db);
}

- (BOOL)openDB
{
    return sqlite3_open([_dbPath UTF8String], &_db) == SQLITE_OK;
}

+ (NSString *)stringFormDictionary:(NSDictionary *)dictionary
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    return [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

+ (NSDictionary *)getMapFromString:(NSString *)string
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [NSJSONSerialization JSONObjectWithData:data
                                           options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
                                             error:nil];
}


#pragma mark - init data base
- (BOOL)initDB_
{
    _dbPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:kDBName];
    _semaphore = dispatch_semaphore_create(0);
    //打开数据库
    if ([self openDB]) {
        NSString *SQLString = @"CREATE TABLE IF NOT EXISTS CACHEINDEX(key text primary key,value text)";
        return sqlite3_exec(_db, SQLString.UTF8String, NULL, NULL, NULL) == SQLITE_OK;
    }
    return NO;
}



@end
