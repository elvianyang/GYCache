//
//  GYURLProtocol.m
//  GYCacheDemo
//
//  Created by guoyang on 16/7/19.
//  Copyright © 2016年 guoyang. All rights reserved.
//

#import "GYURLProtocol.h"
#import "GYCache.h"

static NSString * const URLProtocolHandledKey = @"URLProtocolHandledKey";

@interface GYURLProtocol()<NSURLConnectionDelegate,NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSURLResponse *response;

@end

@implementation GYURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if(![self propertyForKey:URLProtocolHandledKey inRequest:request]) {
        NSURL *requestURL = request.URL;
        NSString *scheme = [requestURL scheme];
        if([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]){
            return YES;
        }
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    if([[[request URL] absoluteString] containsString:@"google"])
        return nil;
    return request;
}


+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    NSMutableURLRequest *request = [[self request] mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:URLProtocolHandledKey inRequest:request];
    NSString *key = [[request URL] absoluteString];
    if([GYCache existsCacheForKey:key]) {
        NSDictionary *dic = [GYCache cacheDataForKey:key];
        if(!dic){return;}
        NSURLResponse *response = dic[GYCacheResponseKey];
        NSData *data = dic[GYCacheDataKey];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)stopLoading {
    [self.connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _data = [[NSMutableData alloc] initWithCapacity:0];
    _response = response;
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [GYCache setCacheData:_data response:_response ForKey:connection.currentRequest.URL.absoluteString inDisk:YES];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    [self.client URLProtocol:self cachedResponseIsValid:cachedResponse];
    return nil;
}
//
//- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
//    [self.client URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
//    return nil;
//}

@end
