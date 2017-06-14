//
//  ViewController.m
//  WMWebViewController
//
//  Created by weimin.zheng on 2017/6/14.
//  Copyright © 2017年 wmzheng. All rights reserved.
//

#import "ViewController.h"
#import "WMWebViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)showWebViewController:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://www.pgyer.com/"];
    WMWebViewController *webViewController = [[WMWebViewController alloc] initWithURL:url];
    webViewController.progressViewBackgroundColor = [UIColor whiteColor];
    webViewController.useFakeProgress = YES;
    webViewController.hidesBarsOnSwipe = YES;
    webViewController.autoRefreshTitle = YES;
    webViewController.showToolbar = YES;
    [self.navigationController pushViewController:webViewController animated:YES];

}

@end
