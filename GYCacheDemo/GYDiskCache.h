//
//  GYDiskCache.h
//  GYCacheDemo
//
//  Created by guoyang on 16/7/20.
//  Copyright © 2016年 guoyang. All rights reserved.
//
//  This code is licensed under the MIT License:
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import <Foundation/Foundation.h>

/**
 *  该类为磁盘缓存类，可以方便缓存各种请求连接，只需要给定对应的url、data已经response即可。
 *  同时具备自动清策略。开发者无需关注缓存清理问题，只需在创建该类实例时指定最大缓存个数、最大占用磁盘空间以及缓存时间即可。
 *  该类具备插入缓存、删除缓存、读取缓存、判断缓存存在和清除缓存功能。
 *  example:
 *  插入：[[GYDiskCache sharedCache] setCacheData:data response:response forKey:url];
 *  删除：[[GYDiskCache sharedCache] removeCacheForKey:url];
 *  读取：[[GYDiskCache sharedCache] cacheDataForKey:url];
 *  清空：[[GYDiskCache sharedCache] cleanCachesInDefaultPath];
 *  判断是否存在：[[GYDiskCache sharedCache] existsCacheForKey:url];
 */
@interface GYDiskCache : NSObject

/**
 *  返回缓存字典的键，当你得到返回的字典时，使用该键来获取数据.
 */
extern NSString *const GYDiskCacheDataKey;
/**
 *  返回缓存字典的键，当你得到返回的字典时，使用该键来获取response.
 */
extern NSString *const GYDiskCacheResponseKey;

/**
 *  磁盘缓存最大缓存个数，默认为100个
 */
@property (nonatomic, assign)NSUInteger cacheLimitCount;

/**
 *  磁盘缓存最大占用空间（单位字节），默认为10MB 即1000*1000*10
 */
@property (nonatomic, assign)NSUInteger cacheLimitCost;

/**
 *  磁盘缓存最长保存时间（单位秒）默认为1周 即60*60*24*7
 */
@property (nonatomic, assign)NSTimeInterval cacheTimeoutInterval;

/**
 *  返回使用默认配置的全局磁盘缓存
 *
 *  @return 返回使用默认配置的全局磁盘缓存
 */
+ (GYDiskCache *)sharedCache;

/**
 *  返回缓存默认保存目录
 *
 *  @return 返回缓存默认保存目录
 */
+ (NSString *)defaultDiskCachePath;

/**
 *  使用指定目录保存的磁盘缓存对象，使用count、cost和timeout来制定缓存清除策略
 *
 *  @param path    指定缓存保存目录
 *  @param count   缓存最大个数
 *  @param cost    缓存最大磁盘空间
 *  @param timeout 缓存对象超时时间
 *
 *  @return 返回自定义磁盘缓存实例
 */
+ (instancetype)diskCacheWithCachePath:(NSString *)path cacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout;

/**
 *  使用指定目录保存的磁盘缓存对象，使用count、cost和timeout来制定缓存清除策略
 *
 *  @param path    指定缓存保存目录
 *  @param count   缓存最大个数
 *  @param cost    缓存最大磁盘空间
 *  @param timeout 缓存对象超时时间
 *
 *  @return 返回自定义磁盘缓存实例
 */
- (instancetype)initWithCachePath:(NSString *)path cacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout;

/**
 *  add a new cache with data and response in the special path at the given key.
 *
 *  @param cacheData the url response data you want to cache
 *  @param response  the url response
 *  @param key       the key you want to mark the cache uniquely
 *  @param path      the path you only need pass a directory name, your special save directory will append to               
 *                   default base cache directory automatically
 */
- (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key inPath:(NSString *)path;

/**
 *  add a new cache with data and response in the default path at the given key.
 *
 *  @param cacheData the url response data you want to cache
 *  @param response  the url response
 *  @param key       the key you want to mark the cache uniquely
 */
- (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key;

/**
 *  delete cache from disk with the key in your custom path
 *
 *  @param key  the key you want to mark the cache uniquely
 *  @param path the path you only need pass a directory name, your special save directory will append to
 *                   default base cache directory automatically
 *
 *  @return return the cache which you specified.
 */
- (NSDictionary *)removeCacheForKey:(NSString *)key inPath:(NSString *)path;

/**
 *  delete cache from disk with the key in default path
 *
 *  @param key  the key you want to mark the cache uniquely
 *
 *  @return return the cache which you specified.
 */
- (NSDictionary *)removeCacheForKey:(NSString *)key;
- (NSDictionary *)cacheDataForKey:(NSString *)key inPath:(NSString *)path;
- (NSDictionary *)cacheDataForKey:(NSString *)key;

- (BOOL)existsCacheForKey:(NSString *)key inPath:(NSString *)path;
- (BOOL)existsCacheForKey:(NSString *)key;

- (void)cleanCachesInPath:(NSString *)path;
- (void)cleanCachesInDefaultPath;

@end
