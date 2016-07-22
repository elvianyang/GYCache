//
//  GYMemoryCache.m
//  GYCacheDemo
//
//  Created by guoyang on 16/7/21.
//  Copyright © 2016年 guoyang. All rights reserved.
//

#import "GYMemoryCache.h"
#import <UIKit/UIKit.h>

NSString *const GYMemoryCacheDataKey = @"GYMemoryCacheDataKey";
NSString *const GYMemoryCacheResponseKey = @"GYMemoryCacheResponseKey";

@interface GYMemoryCacheItem : NSObject

@property (nonatomic, strong)NSString *key;
@property (nonatomic, strong)NSDate *expireDate;
@property (nonatomic, strong)NSData *data;
@property (nonatomic, strong)NSURLResponse *response;
@property (nonatomic, assign)NSUInteger cost;
@property (nonatomic, strong)GYMemoryCacheItem *preCache;
@property (nonatomic, strong)GYMemoryCacheItem *nextCache;

+ (id)cacheItemWithData:(NSData *)data reponse:(NSURLResponse *)response expireDate:(NSDate *)expireDate key:(NSString *)key;

@end

@implementation GYMemoryCacheItem

+ (id)cacheItemWithData:(NSData *)data reponse:(NSURLResponse *)response expireDate:(NSDate *)expireDate key:(NSString *)key{
    GYMemoryCacheItem *cache = [[GYMemoryCacheItem alloc] init];
    cache.expireDate = expireDate;
    cache.data = data;
    cache.response = response;
    cache.cost = [data length];
    cache.key = key;
    return cache;
}

- (void)dealloc {
    self.nextCache = nil;
    self.preCache = nil;
}

@end

@interface GYMemoryCacheLinkList : NSObject

@property (nonatomic, strong) GYMemoryCacheItem *headCache;
@property (nonatomic, strong) GYMemoryCacheItem *tailCache;

+ (id)singleton;
- (void)addMemoryCacheItem:(GYMemoryCacheItem *)item;
- (void)removeCacheItemWithCacheItem:(GYMemoryCacheItem *)item;

- (NSArray *)timeoutCacheItemArray;
- (NSArray *)countNeedDeleteItemArrayWithNeedDeleteCount:(NSUInteger)count;

@end

@implementation GYMemoryCacheLinkList : NSObject

+ (id)singleton {
    static GYMemoryCacheLinkList *linkList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        linkList = [[GYMemoryCacheLinkList alloc] init];
    });
    return linkList;
}

- (id)init {
    self = [super init];
    if(self) {
        _headCache = [[GYMemoryCacheItem alloc] init];
        _tailCache = [[GYMemoryCacheItem alloc] init];
        _headCache.nextCache = _tailCache;
        _tailCache.preCache = _headCache;
    }
    return self;
}

- (void)addMemoryCacheItem:(GYMemoryCacheItem *)item {
    GYMemoryCacheItem *tempItem = _headCache.nextCache;
    _headCache.nextCache = item;
    item.preCache = _headCache;
    item.nextCache = tempItem;
    tempItem.preCache = item;
}

- (void)removeCacheItemWithCacheItem:(GYMemoryCacheItem *)item {
    GYMemoryCacheItem *preItem = item.preCache;
    GYMemoryCacheItem *nextItem = item.nextCache;
    preItem.nextCache = nextItem;
    nextItem.preCache = preItem;
    item.preCache = nil;
    item.nextCache = nil;
}

- (void)dealloc {
    GYMemoryCacheItem *tempCache = _headCache;
    while (tempCache) {
        tempCache.preCache = nil;
        GYMemoryCacheItem *nextItem = tempCache.nextCache;
        tempCache.nextCache = nil;
        tempCache = nextItem;
    }
}

- (NSArray *)timeoutCacheItemArray {
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:0];
    if(_tailCache.preCache != _headCache) {
        GYMemoryCacheItem *tempItem = _tailCache.preCache;
        BOOL finished = NO;
        while (!finished && tempItem != _headCache) {
            NSDate *itemDate = tempItem.expireDate;
            if([itemDate compare:[NSDate date]] == NSOrderedDescending) {
                finished = YES;
                break;
            }
            else {
                [returnArray addObject:tempItem];
                tempItem = tempItem.preCache;
            }
        }
    }
    if(returnArray.count > 0){return returnArray;}
    return nil;
}

- (NSArray *)countNeedDeleteItemArrayWithNeedDeleteCount:(NSUInteger)count {
    if(count <= 0) return nil;
    if(_headCache.nextCache == _tailCache) return nil;
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:0];
    GYMemoryCacheItem *tempItem = _tailCache.preCache;
    while (tempItem!= _headCache && count) {
        [returnArray addObject:tempItem];
        tempItem = tempItem.preCache;
        count--;
    }
    return returnArray;
}

@end

#define DEFAULT_CACHE_COUNT 100
#define DEFAULT_CACHE_COST (1000*1000*5)
#define DEFAULT_CACHE_DATE (60*2)

#define TIMER_CLEAR_REPEAT_TIME 10

@interface GYMemoryCache()
{
    NSUInteger _currentCacheCount;
    NSUInteger _currentCacheCost;
    GYMemoryCacheLinkList *_linkList;
    NSTimer *_clearTimer;
}
@property (nonatomic, strong)NSMutableDictionary *memoryCacheDic;

@end

@implementation GYMemoryCache

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_memoryCacheDic removeAllObjects];
}

#pragma mark - Public methods
+ (GYMemoryCache *)sharedCache {
    static GYMemoryCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GYMemoryCache alloc] initWithCacheLimitCount:DEFAULT_CACHE_COUNT cacheLimitCost:DEFAULT_CACHE_COST timeout:DEFAULT_CACHE_DATE];
    });
    return instance;
}

+ (instancetype)memoryCacheWithCacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout {
    return [[GYMemoryCache alloc] initWithCacheLimitCount:count cacheLimitCost:cost timeout:timeout];
}

- (instancetype)initWithCacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout {
    self = [super init];
    if(self) {
        _cacheLimitCost = cost;
        _cacheLimitCount = count;
        _cacheTimeoutInterval = timeout;
        _currentCacheCost = 0;
        _currentCacheCount = 0;
        _linkList = [GYMemoryCacheLinkList singleton];
        _memoryCacheDic = [[NSMutableDictionary alloc] initWithCapacity:0];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cleanCaches) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        _clearTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:TIMER_CLEAR_REPEAT_TIME target:self selector:@selector(clearMemoryWithCondition) userInfo:nil repeats:YES];
        [NSThread detachNewThreadSelector:@selector(runLoopRun) toTarget:self withObject:nil];
        
    }
    return self;
}

- (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key {
    if(!cacheData && key) {
        [_memoryCacheDic removeObjectForKey:key];
        return;
    }
    else {
        if(!key)return;
        NSDate *expireDate = [NSDate dateWithTimeIntervalSinceNow:DEFAULT_CACHE_DATE];
        GYMemoryCacheItem *item = [GYMemoryCacheItem cacheItemWithData:cacheData reponse:response expireDate:expireDate key:key];
        if([self existsCacheForKey:key]) {
            [self removeCacheForKey:key];
        }
        [_memoryCacheDic setObject:item forKey:key];
        [_linkList addMemoryCacheItem:item];
        _currentCacheCount++;
        _currentCacheCost+=cacheData.length;
    }
}

- (NSDictionary *)removeCacheForKey:(NSString *)key {
    NSDictionary *returnDic = [self cacheDataForKey:key];
    if(returnDic) {
        GYMemoryCacheItem *item = [_memoryCacheDic objectForKey:key];
        [_linkList removeCacheItemWithCacheItem:[_memoryCacheDic objectForKey:key]];
        [_memoryCacheDic removeObjectForKey:key];
        _currentCacheCount--;
        _currentCacheCost -= item.data.length;
    }
    return returnDic;
}

- (NSDictionary *)cacheDataForKey:(NSString *)key {
    if(key) {
        GYMemoryCacheItem *item = [_memoryCacheDic objectForKey:key];
        if(item){
            NSMutableDictionary *returnDic = [[NSMutableDictionary alloc] init];
            returnDic[GYMemoryCacheDataKey] = item.data;
            returnDic[GYMemoryCacheResponseKey] = item.response;
            return returnDic;
        }
        return nil;
    }
    return nil;
}

- (BOOL)existsCacheForKey:(NSString *)key {
    if(!key) {return NO;}
    if([_memoryCacheDic objectForKey:key]) {return YES;}
    return NO;
}

- (void)cleanCaches {
    [_memoryCacheDic removeAllObjects];
}

#pragma mark - Private methods
- (void)clearMemoryWithCondition {
    @synchronized (self) {
        [self checkClearTimeout];
        [self checkClearCount];
        [self checkClearCost];
    }
}

- (void)runLoopRun {
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    [runloop addTimer:_clearTimer forMode:NSRunLoopCommonModes];
    [runloop run];
}

- (void)checkClearTimeout {
    NSArray *deleteArray = [_linkList timeoutCacheItemArray];
    if(deleteArray.count > 0) {
        [deleteArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            GYMemoryCacheItem *item = obj;
            [self removeCacheForKey:item.key];
        }];
    }
}

- (void)checkClearCost {
    if(_currentCacheCost < _cacheLimitCost) {return;}
    NSMutableArray *sortArray = [[NSMutableArray alloc] initWithCapacity:0];
    [_memoryCacheDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [sortArray addObject:obj];
    }];
    [sortArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        GYMemoryCacheItem *item1 = obj1;
        GYMemoryCacheItem *item2 = obj2;
        if(item1.data.length > item2.data.length) {return NSOrderedDescending;}
        else {return NSOrderedAscending;}
    }];
    [sortArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GYMemoryCacheItem *item = obj;
        [self removeCacheForKey:item.key];
        if(_currentCacheCost < _cacheLimitCost) {*stop = YES;}
    }];
}

- (void)checkClearCount {
    NSUInteger needDeleteCount = 0;
    if(_currentCacheCount > _cacheLimitCount) {needDeleteCount = _currentCacheCount - _cacheLimitCount;}
    else {return;}
    NSArray *deleteArray = [_linkList countNeedDeleteItemArrayWithNeedDeleteCount:needDeleteCount];
    if(deleteArray.count > 0) {
        [deleteArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            GYMemoryCacheItem *item = obj;
            [self removeCacheForKey:item.key];
        }];
    }
}

@end
