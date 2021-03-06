//
//  GYMemoryCache.h
//  GYCacheDemo
//
//  Created by guoyang on 16/7/21.
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

@interface GYMemoryCache : NSObject

extern NSString *const GYMemoryCacheDataKey;
extern NSString *const GYMemoryCacheResponseKey;

@property (nonatomic, assign)NSUInteger cacheLimitCount;
@property (nonatomic, assign)NSUInteger cacheLimitCost;
@property (nonatomic, assign)NSTimeInterval cacheTimeoutInterval;

+ (GYMemoryCache *)sharedCache;

+ (instancetype)memoryCacheWithCacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout;

- (instancetype)initWithCacheLimitCount:(NSUInteger)count cacheLimitCost:(NSUInteger)cost timeout:(NSTimeInterval)timeout;

- (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key;

- (NSDictionary *)removeCacheForKey:(NSString *)key;

- (NSDictionary *)cacheDataForKey:(NSString *)key;

- (BOOL)existsCacheForKey:(NSString *)key;

- (void)cleanCaches;

@end
