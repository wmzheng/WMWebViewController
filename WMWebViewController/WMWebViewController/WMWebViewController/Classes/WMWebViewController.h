//
//  WMWebViewController.h
//  WMWebViewController
//
//  Created by weimin.zheng on 2017/6/14.
//  Copyright © 2017年 wmzheng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WMWebViewController : UIViewController

- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithAddress:(NSString *)urlString;
- (instancetype)initWithRequest:(NSURLRequest *)request;

@property (nonatomic, assign) BOOL hidesBarsOnSwipe;
@property (nonatomic, assign, getter=isShowToolBar) BOOL showToolbar; //default is YES

@property (nonatomic, assign) BOOL autoRefreshTitle;

@property (nonatomic, assign, getter=isShowProgressView) BOOL showProgressView; //default is YES
@property (nonatomic, assign, getter=isUseFakeProgress) BOOL useFakeProgress; //default is NO

/**
 ProgressView前景色，默认是Safari bar color
 */
@property (nonatomic, strong) UIColor *progressViewTintColor;
/**
 ProgressView背景色，默认是clearColor
 */
@property (nonatomic, strong) UIColor *progressViewBackgroundColor;

/*** use this to specify schemes that should be handled directly by the app ***/
@property (nonatomic, strong) NSArray *customSchemes;

@property (nonatomic, assign) BOOL showSharingOptions;
/** use this to customize the UIActivityViewController (aka Sharing-Dialog) */
@property (nonatomic) NSArray *sharingActivities;
@end
