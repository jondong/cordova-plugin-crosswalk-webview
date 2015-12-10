// Copyright (c) 2015 Intel Corporation. All rights reserved.
// Use of this source code is governed by a Apache V2.0 license that can be
// found in the LICENSE file.

#import "XWalkWebViewEngine.h"

#import <XWalkView/XWalkView.h>
#import "XWalkNavigationDelegate.h"
#import "XWalkUIDelegate.h"
//#import "NSDictionary+CordovaPreferences.h"

//#import <objc/message.h>

@interface XWalkWebViewEngine ()

@property (nonatomic, strong, readwrite) XWalkView* engineWebView;
@property (nonatomic, strong, readwrite) id <WKUIDelegate> uiDelegate;
@property (nonatomic, strong, readwrite) id <WKNavigationDelegate> navigationDelegate;
//@property (nonatomic, strong, readwrite) id <XWalkUIDelegate> uiDelegate;
//@property (nonatomic, strong, readwrite) id <XWalkNavigationDelegate> navigationDelegate;

@end

@implementation XWalkWebViewEngine

@synthesize engineWebView;

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super init]) {
        self.engineWebView = [[XWalkView alloc] initWithFrame:frame];
        NSLog(@"Using XWalkView");
    }
    return self;
}

- (void)pluginInitialize {
    [self updateSettings:self.commandDelegate.settings];
}

- (void)updateSettings:(NSDictionary*)settings {
    // TODO: Implementation needed.
}

- (id)loadRequest:(NSURLRequest*)request {
    return [self.engineWebView loadRequest:request];
}

- (id)loadHTMLString:(NSString*)string baseURL:(NSURL*)baseURL {
    return [self.engineWebView loadHTMLString:string baseURL:baseURL];
}

- (void)evaluateJavaScript:(NSString*)javaScriptString completionHandler:(void (^)(id, NSError*))completionHandler {
    [self.engineWebView evaluateJavaScript:javaScriptString completionHandler:completionHandler];
}

- (NSURL*)URL {
    return self.engineWebView.URL;
}

- (BOOL)canLoadRequest:(NSURLRequest*)request {
    return request != nil;
}

- (void)updateWithInfo:(NSDictionary*)info {
    id <WKNavigationDelegate> navigationDelegateValue = [info objectForKey:kCDVWebViewEngineWKNavigationDelegate];
    id <WKUIDelegate> uiDelegateValue = [info objectForKey:kCDVWebViewEngineWKUIDelegate];
    NSDictionary* settings = [info objectForKey:kCDVWebViewEngineWebViewPreferences];
    
    /*
    if (uiWebViewDelegate &&
        [uiWebViewDelegate conformsToProtocol:@protocol(UIWebViewDelegate)]) {
        self.uiWebViewDelegate = [[CDVUIWebViewDelegate alloc] initWithDelegate:(id <UIWebViewDelegate>)self.viewController];
        uiWebView.delegate = self.uiWebViewDelegate;
    }
    */
    
    if (settings && [settings isKindOfClass:[NSDictionary class]]) {
        [self updateSettings:settings];
    }
}

@end