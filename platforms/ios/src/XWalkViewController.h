// Copyright (c) 2015 Intel Corporation. All rights reserved.
// Use of this source code is governed by a Apache V2.0 license that can be
// found in the LICENSE file.

#import <Cordova/CDVViewController.h>
#import <XWalkView/XWalkView.h>
#import <WebKit/WebKit.h>

@interface XWalkViewController : CDVViewController<WKNavigationDelegate>

@property(nonatomic, strong) XWalkView* xwalkWebView;

- (void)processOpenUrl:(NSURL*)url pageLoaded:(BOOL)pageLoaded;

@end