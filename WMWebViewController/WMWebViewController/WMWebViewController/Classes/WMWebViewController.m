//
//  WMWebViewController.m
//  WMWebViewController
//
//  Created by weimin.zheng on 2017/6/14.
//  Copyright © 2017年 wmzheng. All rights reserved.
//

#import "WMWebViewController.h"
#import <WebKit/WebKit.h>

const float YBInitialProgressValue = 0.1f;
const float YBFinalProgressValue = 0.92f;


@interface WMWebViewController ()<WKNavigationDelegate,WKUIDelegate,UIWebViewDelegate,UIScrollViewDelegate>{
    float progressCount; //0...1000
    dispatch_source_t _timer;
}

@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) NSURLRequest *request;

@property (nonatomic) BOOL toolbarWasHidden;

@property (nonatomic, assign) BOOL navigationTranslucent;

@property (nonatomic, readonly) float progress; // 0.0..1.0
@end

@implementation WMWebViewController

- (UIImage *)imageNamed:(NSString *)imageName{
    UIImage *img = [UIImage imageNamed:imageName inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
    return img;
}

- (instancetype)init{
    return [self initWithURL:nil];
}

- (instancetype)initWithAddress:(NSString *)urlString{
    return [self initWithURL:[NSURL URLWithString:urlString]];
}

- (instancetype)initWithURL:(NSURL *)url{
    return [self initWithRequest:[NSURLRequest requestWithURL:url]];
}

- (instancetype)initWithRequest:(NSURLRequest *)request{
    if (self = [super initWithNibName:nil bundle:nil]) {
        NSAssert([NSThread isMainThread], @"WebKit is not threadsafe and this function is not executed on the main thread");
        
        self.showToolbar = YES;
        self.showProgressView = YES;
        self.progressViewTintColor = [UIColor colorWithRed:22.f / 255.f green:126.f / 255.f blue:251.f / 255.f alpha:1.0];
        self.progressViewBackgroundColor = [UIColor clearColor];
        self.request = request;
        
        progressCount = 0;
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    //保存当前的navigationbar translucent
    self.navigationTranslucent = self.navigationController.navigationBar.isTranslucent;
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationController.view.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.webView];
    [self.view addSubview:self.progressView];
    [self fillToolbar];
    if (self.request) {
        [self.webView loadRequest:self.request];
    }
}



- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    [self addObserver:self forKeyPath:@"webView.title" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"webView.loading" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"webView.estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.hidesBarsOnSwipe = self.hidesBarsOnSwipe;
    self.navigationController.toolbarHidden = !self.showToolbar;
    
    [self.view setNeedsUpdateConstraints];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [self removeObserver:self forKeyPath:@"webView.title"];
    [self removeObserver:self forKeyPath:@"webView.loading"];
    [self removeObserver:self forKeyPath:@"webView.estimatedProgress"];
    
    self.navigationController.hidesBarsOnSwipe = NO;
    self.navigationController.navigationBar.translucent = self.navigationTranslucent;
    self.navigationController.toolbarHidden = YES;
}

- (void)viewDidLayoutSubviews{
    self.webView.frame = self.view.bounds;
    self.progressView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 2);
}

- (BOOL)prefersStatusBarHidden{
    return self.navigationController.navigationBarHidden;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation{
    return UIStatusBarAnimationSlide;
}

#pragma mark -
- (void)fillToolbar{
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[self imageNamed:@"back"] style:UIBarButtonItemStylePlain target:self action:@selector(backTapped:)];
    if (self.webView.canGoBack) {
        backItem.tintColor = nil;
    }
    else {
        backItem.tintColor = [UIColor lightGrayColor];
    }
    
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithImage:[self imageNamed:@"forward"] style:UIBarButtonItemStylePlain target:self action:@selector(forwardTapped:)];
    if (self.webView.canGoForward) {
        forwardItem.tintColor = nil;
    }
    else {
        forwardItem.tintColor = [UIColor lightGrayColor];
    }
    
    UIBarButtonItem *reloadItem;
    if (self.webView.isLoading) {
        reloadItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopTapped:)];
    }
    else {
        reloadItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadTapped:)];
    }
    UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareTapped:)];
    UIBarButtonItem *flexibleSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    if (self.showSharingOptions) {
        [self setToolbarItems:@[flexibleSpaceItem, backItem, flexibleSpaceItem, forwardItem, flexibleSpaceItem, reloadItem, flexibleSpaceItem, shareItem, flexibleSpaceItem] animated:NO];
    }
    else {
        [self setToolbarItems:@[flexibleSpaceItem, backItem, flexibleSpaceItem, forwardItem, flexibleSpaceItem, reloadItem, flexibleSpaceItem] animated:NO];
    }
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"webView.title"] && self.autoRefreshTitle) {
        self.navigationItem.title = change[@"new"];
    }
    else if ([keyPath isEqualToString:@"webView.loading"]){
        [self fillToolbar];
    }
    else if ([keyPath isEqualToString:@"webView.estimatedProgress"] && !self.useFakeProgress) {
        CGFloat newprogress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
        [self setRealProgress:newprogress];
    }
}

#pragma mark - RealProgress
- (void)setRealProgress:(float)progress{
    //    NSLog(@"real progress:%f",progress);
    if (progress == 1) {
        [UIView animateWithDuration:0.27f animations:^{
            [self.progressView setProgress:1 animated:YES];
        } completion:^(BOOL finished) {
            self.progressView.hidden = YES;
            [self.progressView setProgress:0 animated:NO];
        }];
    }
    else {
        self.progressView.hidden = NO;
        [self.progressView setProgress:progress < 0.1 ? 0.1 : progress
                              animated:YES];
    }
}

#pragma mark - FakeProgress
- (void)startProgress
{
    if (_progress <= YBInitialProgressValue) {
        progressCount = YBInitialProgressValue * 1000;
        [self setFakeProgress:YBInitialProgressValue];
        
    }
    [self incrementProgress];
}

- (void)completeProgress
{
    [self setFakeProgress:1.0];
    
    if (_timer){
        dispatch_source_cancel(_timer);
    }
}

- (void)reset{
    [self setFakeProgress:0.0];
    
    if (_timer){
        dispatch_source_cancel(_timer);
    }
}

- (void)incrementProgress{
    NSTimeInterval period = 100.0; //设置时间间隔
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), period * NSEC_PER_MSEC, 0);
    
    dispatch_source_set_event_handler(_timer, ^{
        //减速效果
        if (progressCount >= 0 && progressCount < 500) {
            progressCount += 50;
        }
        else {
            if (progressCount >= 500 && progressCount < 700) {
                progressCount += 20;
            }
            else {
                if (progressCount >= 700 && progressCount < 850) {
                    progressCount += 15;
                }
                else {
                    if (progressCount >= 850 && progressCount <= YBFinalProgressValue * 1000) {
                        progressCount += 1;
                    }
                    else{
                        if(_timer) {
                            dispatch_source_cancel(_timer);
                        }
                    }
                }
            }
        }
        
        float progress = progressCount / 1000;
        [self setFakeProgress:progress];
        
    });
    
    dispatch_resume(_timer);
}

- (void)setFakeProgress:(float)progress{
    if (progress > _progress || progress == 0) {
        _progress = progress;
        dispatch_async(dispatch_get_main_queue(), ^{
            //            NSLog(@"fake progress:%f",progress);
            if (progress == 0) {
                self.progressView.progress = 0;
                self.progressView.alpha = 0;
            }
            
            BOOL isGrowing = progress > 0.0 && progress <= 1.0;
            if (isGrowing) {
                [UIView animateWithDuration:0.27f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    [self.progressView setProgress:progress animated:YES];
                    self.progressView.alpha = 1.0;
                } completion:nil];
            }
            
            BOOL isFinished = progress >= 1.0;
            if (isFinished) {
                [UIView animateWithDuration:0.27f delay:0.1f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    self.progressView.alpha = 0.0;
                } completion:^(BOOL completed){
                    self.progressView.progress = 0;
                }];
            }
        });
    }
}

#pragma mark - Event
- (void)backTapped:(UIBarButtonItem *)button{
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
}

- (void)forwardTapped:(UIBarButtonItem *)button{
    if ([self.webView canGoForward]) {
        [self.webView goForward];
    }
}

- (void)reloadTapped:(UIBarButtonItem *)button{
    [self.webView reload];
}

- (void)stopTapped:(UIBarButtonItem *)button{
    [self.webView stopLoading];
}

- (void)shareTapped:(UIBarButtonItem *)button
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    if (self.title) {
        [items addObject:self.title];
    }
    if (self.request.URL) {
        [items addObject:self.request.URL];
    }
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:items
                                                                             applicationActivities:self.sharingActivities];
    controller.popoverPresentationController.barButtonItem = button;
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    UIApplication *app = [UIApplication sharedApplication];
    NSURL         *url = navigationAction.request.URL;
    
    if (self.customSchemes) {
        //处理scheme
        for (NSString *scheme in self.customSchemes) {
            if ([url.scheme isEqualToString:scheme] && [app canOpenURL:url]) {
                [app openURL:url options:@{UIApplicationOpenURLOptionsSourceApplicationKey : @YES} completionHandler:^(BOOL success) {
                    
                }];
                
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
    }
    
    if (!navigationAction.targetFrame.isMainFrame) {
        //处理target=_blank的情况，如果不处理，点击将没反应
        [webView loadRequest:navigationAction.request];
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    //otherwise top of website is sometimes hidden under Navigation Bar
    [self.webView.scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    
    if (self.useFakeProgress) {
        [self completeProgress];
    }
}

// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (self.useFakeProgress) {
        [self reset];
        [self startProgress];
    }
}

//失败
- (void)webView:(WKWebView *)webView didFailNavigation: (null_unspecified WKNavigation *)navigation withError:(NSError *)error {
}

#pragma mark - getter/setter
- (WKWebView *)webView{
    if (!_webView) {
        WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
        configuration.preferences = [WKPreferences new];
        configuration.userContentController = [WKUserContentController new];
        _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
        _webView.backgroundColor = [UIColor clearColor];
        _webView.allowsBackForwardNavigationGestures = YES;
        _webView.opaque = NO;
    }
    return _webView;
}

- (UIProgressView *)progressView{
    if (!_progressView) {
        _progressView = [UIProgressView new];
        _progressView.progressTintColor = self.progressViewTintColor;
        _progressView.trackTintColor = self.progressViewBackgroundColor;
    }
    return _progressView;
}

- (void)setProgressViewTintColor:(UIColor *)progressViewTintColor{
    _progressViewTintColor = progressViewTintColor;
    if (self.progressView) {
        self.progressView.progressTintColor = progressViewTintColor;
    }
}

- (void)setProgressViewBackgroundColor:(UIColor *)progressViewBackgroundColor{
    _progressViewBackgroundColor = progressViewBackgroundColor;
    if (self.progressView) {
        self.progressView.trackTintColor = progressViewBackgroundColor;
    }
}

- (BOOL)isShowProgressView{
    return _showProgressView;
}

- (BOOL)isUseFakeProgress{
    return _useFakeProgress;
}

- (BOOL)isShowToolBar{
    return _showToolbar;
}

@end
