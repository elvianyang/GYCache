//
//  GYCache.m
//  GYCache
//
//  Created by guoyang on 16/7/21.
//  Copyright © 2016年 guoyang. All rights reserved.
//

#import "GYCache.h"
#import "GYMemoryCache.h"
#import "GYDiskCache.h"

NSString *const GYCacheDataKey = @"GYCacheDataKey";
NSString *const GYCacheResponseKey = @"GYCacheResponseKey";

@implementation GYCache

static GYMemoryCache *memoryCache;
static GYDiskCache *diskCache;

+ (void)initialize {
    memoryCache = [GYMemoryCache sharedCache];
    diskCache = [GYDiskCache sharedCache];
}

+ (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key inDisk:(BOOL)inDisk;
{
    [memoryCache setCacheData:cacheData response:response ForKey:key];
    if(inDisk) {[diskCache setCacheData:cacheData response:response ForKey:key];}
}

+ (NSDictionary *)removeCacheForKey:(NSString *)key {
    NSDictionary *dic = [memoryCache removeCacheForKey:key];
    NSMutableDictionary *returnDic = [[NSMutableDictionary alloc] initWithCapacity:2];
    if(!dic) {
        dic = [diskCache removeCacheForKey:key];
        if(!dic) {return nil;}
        else {
            returnDic[GYCacheDataKey] = dic[GYDiskCacheDataKey];
            returnDic[GYCacheResponseKey] = dic[GYDiskCacheResponseKey];
        }
    }
    else {
        returnDic[GYCacheDataKey] = dic[GYMemoryCacheDataKey];
        returnDic[GYCacheResponseKey] = dic[GYMemoryCacheResponseKey];
    }
    return returnDic.copy;
}

+ (NSDictionary *)cacheDataForKey:(NSString *)key {
    NSDictionary *dic = [memoryCache cacheDataForKey:key];
    NSMutableDictionary *returnDic = [[NSMutableDictionary alloc] initWithCapacity:2];
    if(!dic) {
        dic = [diskCache cacheDataForKey:key];
        if(dic) {
            returnDic[GYCacheDataKey] = dic[GYDiskCacheDataKey];
            returnDic[GYCacheResponseKey] = dic[GYDiskCacheResponseKey];
            [memoryCache setCacheData:dic[GYDiskCacheDataKey] response:dic[GYDiskCacheResponseKey] ForKey:key];
            return dic;
        }
        return nil;
    }
    returnDic[GYCacheDataKey] = dic[GYMemoryCacheDataKey];
    returnDic[GYCacheResponseKey] = dic[GYMemoryCacheResponseKey];
    return returnDic.copy;
}

+ (BOOL)existsCacheForKey:(NSString *)key {
    BOOL exist = [memoryCache existsCacheForKey:key];
    if(!exist) {
        NSDictionary *dic = [diskCache cacheDataForKey:key];
        if(dic) {
            [memoryCache setCacheData:dic[GYDiskCacheDataKey] response:dic[GYDiskCacheResponseKey] ForKey:key];
            return YES;
        }
        return NO;
    }
    return YES;
}

+ (void)cleanCaches {
    [memoryCache cleanCaches];
    [diskCache cleanCachesInDefaultPath];
}

@end
