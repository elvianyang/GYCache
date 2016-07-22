# GYCache
iOS cache library (contains memory cache and disk cache)

GYCache 是一个iOS基于内存和文件的二级缓存库，具有简单、自动化、易用等特点。
开发者可使用该库完成网络缓存、数据缓存任务。

## Feature

### 1.GYCache具备二级缓存，包含内存和磁盘缓存，提高了缓存的读取效率。
### 2.GYCache包含缓存清理机制，该机制对开发者并不透明，无需关心。
### 3.GYCache提供了缓存Api统一接口，方便使用。

## Usage

+ (void)setCacheData:(NSData *)cacheData response:(NSURLResponse *)response ForKey:(NSString *)key inDisk:(BOOL)inDisk;创建缓存

+ (NSDictionary *)removeCacheForKey:(NSString *)key;删除缓存

+ (NSDictionary *)cacheDataForKey:(NSString *)key;获取缓存

+ (BOOL)existsCacheForKey:(NSString *)key;判断缓存是否存在

+ (void)cleanCaches;清空缓存

note:如果缓存普通数据不传response参数即可

1.0版本不稳定，欢迎提bug。
