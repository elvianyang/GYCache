//
//  ViewController.m
//  GYCacheDemo
//
//  Created by guoyang on 16/7/18.
//  Copyright © 2016年 guoyang. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<UIWebViewDelegate>
{
    UIWebView *_webView;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_webView];
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    [button setTitle:@"刷新" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(refreshWebView) forControlEvents:UIControlEventTouchUpInside];
    button.center = CGPointMake(self.view.center.x, 100);
    [self.view addSubview:_webView];
    [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.nshipster.cn"]] returningResponse:nil error:nil];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.nshipster.cn"]]];
    //
    [self.view addSubview:button];
    
//     Do any a;dditional setup after loading the view, typically from a nib.
}

- (void)refreshWebView {
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.nshipster.cn"]]];
    //
//    [[GYDownloader sharedDownloader] downloadOperationWithURL:[NSURL URLWithString:@"http://www.nshipster.cn"] progressBlock:^(CGFloat currentSize, CGFloat expectedSize) {
//        
//    } completionBlock:^(NSData *data, NSError *error, BOOL finished) {
//        [_webView loadData:data MIMEType:@"text/html" textEncodingName:@"UTF-8" baseURL:nil];
//    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(nonnull NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
//    NSLog(@"%@",request.URL);
//    return YES;
//    
//}

@end
