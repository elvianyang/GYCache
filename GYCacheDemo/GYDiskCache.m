//
//  GYDiskCache.m
//  GYCacheDemo
//
//  Created by guoyang on 16/7/20.
//  Copyright © 2016年 guoyang. All rights reserved.
//

#import "GYDiskCache.h"
#include <CommonCrypto/CommonCrypto.h>
#include <UIKit/UIKit.h>

#pragma -mark GYDiskCacheItem
/**
 *  缓存对象，该类对外不可见，用于内部保存使用，主要用于归档。
 *  属性包含超时时间、文件名、文件路径、数据和响应
 */
@interface GYDiskCacheItem : NSObject<NSCoding>

@property (nonatomic, strong)NSDate *expireDate;
@property (nonatomic, strong)NSString *name;
@property (nonatomic, strong)NSString *path;
@property (nonatomic, strong)NSData *data;
@property (nonatomic, strong)NSURLResponse *response;

@end

@implementation GYDiskCacheItem

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSDate *expireDate = [aDecoder decodeObjectForKey:@"expireDate"];
    NSString *name = [aDecoder decodeObjectForKey:@"name"];
    NSString *path = [aDecoder decodeObjectForKey:@"path"];
    NSData *data = [aDecoder decodeObjectForKey:@"data"];
    NSURLResponse *response = [aDecoder decodeObjectForKey:@"response"];
    GYDiskCacheItem *item = [GYDiskCacheItem new];
    item.expireDate = expireDate;
    item.name = name;
    item.data = data;
    item.path = path;
    item.response = response;
    return item;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.expireDate forKey:@"expireDate"];
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.path forKey:@"path"];
    [aCoder encodeObject:self.data forKey:@"data"];
    [aCoder encodeObject:self.response forKey:@"response"];
}
@end

#pragma mark - GYDiskCacheItemMapClass

static const NSString *GYDiskCacheItemMapNameKey = @"GYDiskCacheItemMapNameKey";
static const NSString *GYDiskCacheItemMapPathKey = @"GYDiskCacheItemMapPathKey";
static const NSString *GYDiskCacheItemMapDateKey = @"GYDiskCacheItemMapDateKey";
static const NSString *GYDiskCacheItemMapCostKey = @"GYDiskCacheItemMapCostKey";


#define MAP_SAVE_PATH @"mapPath.plist"
/**
 *  该类为缓存映射器类，保存缓存路径和数据大小等信息，用来帮助执行缓存清除策略。
 *  todo 暂时没有办法解决因crash造成的无法同步问题，所以在每次添加删除映射的时候都进行了文件操作，效率较低。
 */
@interface GYDiskCacheItemMap : NSObject

@property (nonatomic, strong) NSString *savePath;
@property (nonatomic, strong) NSMutableArray *mapArray;

+ (instancetype)singleton;
- (void)addNewCacheInfoWithCacheItem:(GYDiskCacheItem *)item;
- (void)removeCacheByName:(NSString *)name;
- (NSArray *)needRemoveItemWithNowTime;
- (NSArray *)needRemoveItemWithCost:(NSUInteger)cost;
- (NSArray *)needRemoveItemWithCount:(NSUInteger)removeCount;
- (NSUInteger)currentDiskCacheCount;

@end

@implementation GYDiskCacheItemMap

#pragma mark - Override methods
+ (void)initialize {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (id)init {
    self = [super init];
    if(self) {
        _savePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:MAP_SAVE_PATH];
        _mapArray = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self singleton];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [[self class] singleton];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private methods
- (BOOL)isCreateMapFileSuccess {
    NSFileManager *manager = [NSFileManager defaultManager];
    if([manager fileExistsAtPath:_savePath]) return YES;
    [manager createFileAtPath:_savePath contents:nil attributes:nil];
    return YES;
}

- (void)loadCacheInfoFromSavePath {
    NSArray *cacheInfoArray = [[NSArray alloc] initWithContentsOfFile:_savePath];
    if(cacheInfoArray) {
        _mapArray = [cacheInfoArray mutableCopy];
    }
}

#pragma mark - Public methods
+ (instancetype)singleton {
    static GYDiskCacheItemMap *map;
    static dispatch_once_t onceToken;
    __block BOOL createSuccess = YES;
    dispatch_once(&onceToken, ^{
        map = [[super allocWithZone:NULL] init];
        if(![map isCreateMapFileSuccess]) {createSuccess = NO;}
        if(createSuccess) {
            [map loadCacheInfoFromSavePath];
        }
    });
    if(!createSuccess) {return nil;}
    return map;
}

- (void)addNewCacheInfoWithCacheItem:(GYDiskCacheItem *)item {
    NSTimeInterval timeIntervalStr = [item.expireDate timeIntervalSince1970];
    NSString *dataLength = [NSString stringWithFormat:@"%lld",(long long)item.data.length];
    NSDictionary *dic = @{
                          GYDiskCacheItemMapNameKey:item.name,
                          GYDiskCacheItemMapPathKey:item.path,
                          GYDiskCacheItemMapDateKey:@(timeIntervalStr),
                          GYDiskCacheItemMapCostKey:dataLength
            };
    [_mapArray addObject:dic];
    [self synchronize];
}

- (void)removeCacheByName:(NSString *)name {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"GYDiskCacheItemMapNameKey contains[cd] %@",name];
    NSArray *needRemoveCacheArray = [_mapArray filteredArrayUsingPredicate:predicate];
    [_mapArray removeObjectsInArray:needRemoveCacheArray];
    [self synchronize];
}

- (NSUInteger)currentDiskCacheCount {
    return _mapArray.count;
}

- (NSUInteger)currentdDiskCacheCost {
    __block NSUInteger size = 0;
    [_mapArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        size += [[(NSDictionary *)obj objectForKey:GYDiskCacheItemMapCostKey] integerValue];
    }];
    return size;
}

- (void)synchronize {
    if([[NSFileManager defaultManager] fileExistsAtPath:_savePath]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:_savePath error:&error];
        if(error) {return;}
        [_mapArray writeToFile:_savePath atomically:YES];
    }
}

- (NSArray *)needRemoveItemWithNowTime {
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"GYDiskCacheItemMapDateKey < %@",@(nowTime)];
    NSArray *needRemoveCacheArray = [_mapArray filteredArrayUsingPredicate:predicate];
    [_mapArray removeObjectsInArray:needRemoveCacheArray];
    return needRemoveCacheArray;
}

- (NSArray *)needRemoveItemWithCost:(NSUInteger)cost {
    if(!cost) {return nil;}
    [_mapArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSUInteger time1 = [[obj1 objectForKey:GYDiskCacheItemMapCostKey] integerValue];
        NSUInteger time2 = [[obj2 objectForKey:GYDiskCacheItemMapCostKey] integerValue];
        if(time1 < time2) {return NSOrderedAscending;}
        else if(time1 == time2) {return NSOrderedSame;}
        else return NSOrderedDescending;
    }];
    NSUInteger deleteCost = 0;
    NSMutableArray *needRemoveCacheArray = [[NSMutableArray alloc] initWithCapacity:0];
    while (deleteCost < cost && _mapArray.count) {
        NSDictionary *item = [_mapArray lastObject];
        [needRemoveCacheArray addObject:item];
        [_mapArray removeLastObject];
        deleteCost += [item[GYDiskCacheItemMapCostKey] integerValue];
    }
    [self synchronize];
    return needRemoveCacheArray;
}

- (NSArray *)needRemoveItemWithCount:(NSUInteger)removeCount {
    if(!removeCount || removeCount > _mapArray.count) {return nil;}
    [_mapArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSTimeInterval time1 = [[obj1 objectForKey:GYDiskCacheItemMapDateKey] integerValue];
        NSTimeInterval time2 = [[obj2 objectForKey:GYDiskCacheItemMapDateKey] integerValue];
        if(time1 < time2) {return NSOrderedAscending;}
        else if(time1 == time2) {return NSOrderedSame;}
        else return NSOrderedDescending;
    }];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"GYDiskCacheItemMapDateKey <= %@",[_mapArray[removeCount-1] objectForKey:GYDiskCacheItemMapDateKey]];
    NSArray *needRemoveCacheArray = [_mapArray filteredArrayUsingPredicate:predicate];
    [_mapArray removeObjectsInArray:needRemoveCacheArray];
    [self synchronize];
    return needRemoveCacheArray;
}

#pragma mark - Notification
+ (void)applicationDidEnterBackground:(NSNotification *)notfication {
    [[GYDiskCacheItemMap singleton] synchronize];
}

+ (void)applicationWillTerminate:(NSNotification *)notfication {
    [[GYDiskCacheItemMap singleton] synchronize];
}

@end

NSString *const GYDiskCacheDataKey = @"GYDiskCacheDataKey";
NSString *const GYDiskCacheResponseKey = @"GYDiskCacheResponseKey";


#pragma mark - GYDiskCache
#pragma mark - const define

#define DOCUMENT_DIR [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define DEFAULT_CACHE_DIR @"GYDiskCache"
#define DEFAULT_CACHE_PATH @"default"

#define DEFAULT_CACHE_FULL_PATH [[DOCUMENT_DIR stringByAppendingPathComponent:DEFAULT_CACHE_DIR] stringByAppendingPathComponent:DEFAULT_CACHE_PATH]

#define DEFAULT_CACHE_COUNT 1000
#define DEFAULT_CACHE_DATE (60 * 60 * 24 * 7)
#define DEFAULT_CACHE_COST 1000 * 1000 * 50

#define TIMER_CLEAR_REPEAT_TIME 10

@interface GYDiskCache()
{
    NSString *_cachePath;
    NSMutableDictionary *_cacheItemDic;
    
    NSUInteger _currentCost;
    NSUInteger _currentCount;
    NSTimer *_clearTimer;
}
@end

@implementation GYDiskCache
#pragma mark - Public methods
+ (GYDiskCache *)sharedCache {
    static GYDiskCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GYDiskCache alloc] initWithCachePath:DEFAULT_CACHE_PATH cacheLimitCount:DEFAULT_CACHE_COUNT cacheLimitCost:DEFAULT_CACHE_COST timeout:DEFAULT_CACHE_DATE];
    });
    return instance;
}

+ (instancetype)diskCacheWithCachePath:(NSString *)path cacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout {
    return [[self alloc] initWithCachePath:path cacheLimitCount:count cacheLimitCost:cost timeout:timeout];
}

- (instancetype)initWithCachePath:(NSString *)path cacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout {
    self = [super init];
    if(self) {
        _cachePath = [self createCachePath:path];
        if(!_cachePath) {return nil;}
        _cacheLimitCost = cost>0 ?cost:DEFAULT_CACHE_COST;
        _cacheLimitCount = count >0 ?count:DEFAULT_CACHE_COUNT;
        _cacheTimeoutInterval = timeout>0?timeout:DEFAULT_CACHE_DATE;
        _cacheItemDic = [[NSMutableDictionary alloc] initWithCapacity:0];
        GYDiskCacheItemMap *_map = [GYDiskCacheItemMap singleton];
        _currentCount = [_map currentDiskCacheCount];
        _currentCost = [_map currentdDiskCacheCost];
        _clearTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:TIMER_CLEAR_REPEAT_TIME target:self selector:@selector(clearDiskWithCondition) userInfo:nil repeats:YES];
       [NSThread detachNewThreadSelector:@selector(runLoopRun) toTarget:self withObject:nil];
    }
    return self;
}

+ (NSString *)defaultDiskCachePath {
    return DEFAULT_CACHE_FULL_PATH;
}

- (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key inPath:(NSString *)path {
    if(!cacheData) {
        if([self existsCacheForKey:key inPath:path]) {
            [self removeCacheForKey:key inPath:path];
        }
        return;
    }
    if(![self existsCachePath:path]) {
        if(![self createCachePath:path]){return;}
    }
    NSString *cacheName = [self cacheNameFromKey:key];
    NSString *fullPath = [self fullCachePathWithPath:path];
    [self createCacheWithCacheData:cacheData response:response cacheName:cacheName inPath:fullPath];
}

- (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key {
    [self setCacheData:cacheData response:(NSURLResponse *)response ForKey:key inPath:DEFAULT_CACHE_PATH];
}

- (NSDictionary *)removeCacheForKey:(NSString *)key inPath:(NSString *)path {
    NSDictionary *returnDic = [self cacheDataForKey:key inPath:path];
    NSString *name = [self cacheNameFromKey:key];
    NSString *fullPath = [self fullCachePathWithPath:path];
    NSString *savePath = [fullPath stringByAppendingPathComponent:name];
    NSError *error = nil;
    [[GYDiskCacheItemMap singleton] removeCacheByName:name];
    _currentCount--;
    NSData *fileData = [NSData dataWithContentsOfFile:savePath];
    _currentCost -= fileData.length;
    [[NSFileManager defaultManager] removeItemAtPath:savePath error:&error];
    return returnDic;
}

- (NSDictionary *)removeCacheForKey:(NSString *)key {
    return [self removeCacheForKey:key inPath:DEFAULT_CACHE_PATH];
}

- (NSDictionary *)cacheDataForKey:(NSString *)key inPath:(NSString *)path {
    NSString *name = [self cacheNameFromKey:key];
    NSString *fullPath = [self fullCachePathWithPath:path];
    NSString *savePath = [fullPath stringByAppendingPathComponent:name];
    if([[NSFileManager defaultManager] fileExistsAtPath:savePath]){
        GYDiskCacheItem *item = [NSKeyedUnarchiver unarchiveObjectWithFile:savePath];
        return @{GYDiskCacheDataKey:item.data,
             GYDiskCacheResponseKey:item.response};
    }
    return nil;
}

- (NSDictionary *)cacheDataForKey:(NSString *)key {
    return [self cacheDataForKey:key inPath:DEFAULT_CACHE_PATH];
}

- (BOOL)existsCacheForKey:(NSString *)key inPath:(NSString *)path {
    NSString *name = [self cacheNameFromKey:key];
    NSString *fullPath = [self fullCachePathWithPath:path];
    NSString *savePath = [fullPath stringByAppendingPathComponent:name];
    return [[NSFileManager defaultManager] fileExistsAtPath:savePath];
}

- (BOOL)existsCacheForKey:(NSString *)key {
    return [self existsCacheForKey:key inPath:DEFAULT_CACHE_PATH];
}

- (void)cleanCachesInPath:(NSString *)path {
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void)cleanCachesInDefaultPath {
    [self cleanCachesInPath:DEFAULT_CACHE_FULL_PATH];
}

#pragma mark - private methods

//create real cache file on disk in path
- (BOOL)createCacheWithCacheData:(NSData *)cacheData response:(NSURLResponse *)response cacheName:(NSString *)name inPath:(NSString *)path {
    NSString *savePath = [path stringByAppendingPathComponent:name];
    GYDiskCacheItem *item = [GYDiskCacheItem new];
    item.data = cacheData;
    item.name = name;
    item.expireDate = [NSDate dateWithTimeIntervalSinceNow:self.cacheTimeoutInterval];
    item.response = response;
    item.path = savePath;
    BOOL isUpdate = NO;
    if([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
        [[GYDiskCacheItemMap singleton] removeCacheByName:item.name];
        isUpdate = YES;
    }
    if(!isUpdate) {
        _currentCount++;
        _currentCost += item.data.length;
    }
    [[GYDiskCacheItemMap singleton] addNewCacheInfoWithCacheItem:item];
    return [NSKeyedArchiver archiveRootObject:item toFile:savePath];
}

//if cache file is already exists in path.
- (BOOL)existsCachePath:(NSString *)path {
    NSString *cachePath = [[DOCUMENT_DIR stringByAppendingPathComponent:DEFAULT_CACHE_DIR] stringByAppendingPathComponent:path];
    if([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) return YES;
    return NO;
}

//create cache directory in path
- (NSString *)createCachePath:(NSString *)path {
    if(!path) return nil;
    NSString *filePath = [[DOCUMENT_DIR stringByAppendingPathComponent:DEFAULT_CACHE_DIR] stringByAppendingPathComponent:path];
    if([[NSFileManager defaultManager] fileExistsAtPath:path])
        return filePath;
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error];
    if(error) {
        if(![[NSFileManager defaultManager] fileExistsAtPath:DEFAULT_CACHE_FULL_PATH]) {
            error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error];
            if(error) return nil;
            return DEFAULT_CACHE_FULL_PATH;
        }
    }
    return filePath;
}

//use the custom name format like 'md5Str'
- (NSString *)cacheNameFromKey:(NSString *)key {
    const char *keyStr = [key UTF8String];
    unsigned char result[16];
    CC_MD5(keyStr,(CC_LONG)strlen(keyStr),result);
    NSString *md5Key = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",result[0],result[1],result[2],result[3],result[4],result[5],result[6],result[7],result[8],result[9],result[10],result[11],result[12],result[13],result[14],result[15]];
    return md5Key;
}

- (NSString *)fullCachePathWithPath:(NSString *)path {
    return [[DOCUMENT_DIR stringByAppendingPathComponent:DEFAULT_CACHE_DIR] stringByAppendingPathComponent:path];
}

- (void)clearDiskWithCondition {
    @synchronized (self) {
        [self checkClearCost];
        [self checkClearCount];
        [self checkClearTimeout];
    }
}

- (void)checkClearCost {
    NSUInteger removeCost = 0;
    if(_currentCost > _cacheLimitCost) {
        removeCost = _currentCost - _cacheLimitCost;
    }
    GYDiskCacheItemMap *map = [GYDiskCacheItemMap singleton];
    NSArray *needClearArray = [map needRemoveItemWithCost:removeCost];
    [needClearArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dic = obj;
        NSString *savePath = dic[GYDiskCacheItemMapPathKey];
        NSNumber *number = dic[GYDiskCacheItemMapCostKey];
        NSUInteger cost = [number integerValue];
        if([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            _currentCount--;
            _currentCost-=cost;
        }
    }];
}

- (void)checkClearCount {
    NSUInteger removeCount = 0;
    if(_currentCount > _cacheLimitCount) {
        removeCount = _currentCount - _cacheLimitCount;
    }
    GYDiskCacheItemMap *map = [GYDiskCacheItemMap singleton];
    NSArray *needClearArray = [map needRemoveItemWithCount:removeCount];
    [needClearArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dic = obj;
        NSNumber *number = dic[GYDiskCacheItemMapCostKey];
        NSUInteger cost = [number integerValue];
        NSString *savePath = dic[GYDiskCacheItemMapPathKey];
        if([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            _currentCount--;
            _currentCost-=cost;
        }
    }];
}

- (void)checkClearTimeout {
    GYDiskCacheItemMap *map = [GYDiskCacheItemMap singleton];
    NSArray *needClearArray = [map needRemoveItemWithNowTime];
    [needClearArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dic = obj;
        NSNumber *number = dic[GYDiskCacheItemMapCostKey];
        NSUInteger cost = [number integerValue];
        NSString *savePath = dic[GYDiskCacheItemMapPathKey];
        if([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            _currentCount--;
            _currentCost-=cost;
        }
    }];
}

- (void)runLoopRun {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [self clearDiskWithCondition];
    [runLoop addTimer:_clearTimer forMode:NSRunLoopCommonModes];
    [runLoop run];
}

- (void)dealloc {
    [_clearTimer invalidate];
}

@end
