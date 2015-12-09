// Copyright (c) 2015 Intel Corporation. All rights reserved.
// Use of this source code is governed by a Apache V2.0 license that can be
// found in the LICENSE file.

#import "XWalkViewController.h"

#import <Cordova/CDVUserAgentUtil.h>
#import <XWalkView/XWalkView-Swift.h>
#import "XWalkCommandDelegate.h"

@interface XWalkViewController () {
    NSInteger _userAgentLockToken;
}
@end

@implementation XWalkViewController

- (id)init {
    self = [super init];
    _commandDelegate = [[XWalkCommandDelegate alloc] initWithViewController:self];
    return self;
}

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _commandDelegate = [[XWalkCommandDelegate alloc] initWithViewController:self];
    return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder {
    self = [super initWithCoder:aDecoder];
    _commandDelegate = [[XWalkCommandDelegate alloc] initWithViewController:self];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];

    _xwalkWebView = [[XWalkView alloc] initWithFrame:self.view.frame];
    _xwalkWebView.navigationDelegate = self;
    [self.view addSubview:_xwalkWebView];
    
    NSArray* xwalkExtensions = @[@"Extension.load"];
    for (NSString* name in xwalkExtensions) {
        XWalkExtension* extension = [XWalkExtensionFactory createExtension:name];
        if (extension) {
            [_xwalkWebView loadExtension:extension namespace:name];
        }
    }

    // By default, overscroll bouncing is allowed.
    // UIWebViewBounce has been renamed to DisallowOverscroll, but both are checked.
    BOOL bounceAllowed = YES;
    NSNumber* disallowOverscroll = [self settingForKey:@"DisallowOverscroll"];
    if (disallowOverscroll == nil) {
        NSNumber* bouncePreference = [self settingForKey:@"UIWebViewBounce"];
        bounceAllowed = (bouncePreference == nil || [bouncePreference boolValue]);
    } else {
        bounceAllowed = ![disallowOverscroll boolValue];
    }
    
    if (!bounceAllowed) {
        if ([_xwalkWebView respondsToSelector:@selector(scrollView)]) {
            ((UIScrollView*)[_xwalkWebView scrollView]).bounces = NO;
        } else {
            for (id subview in _xwalkWebView.subviews) {
                if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
                    ((UIScrollView*)subview).bounces = NO;
                }
            }
        }
    }
    
    NSString* decelerationSetting = [self settingForKey:@"UIWebViewDecelerationSpeed"];
    if (![@"fast" isEqualToString:decelerationSetting]) {
        [_xwalkWebView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
    }
    
    NSURL* appURL = [self appUrl];
    [CDVUserAgentUtil acquireLock:^(NSInteger lockToken) {
        _userAgentLockToken = lockToken;
        [CDVUserAgentUtil setUserAgent:self.userAgent lockToken:lockToken];
        if (appURL) {
            NSMutableArray* pathCompoments = [NSMutableArray arrayWithArray:appURL.pathComponents];
            [pathCompoments removeLastObject];
            [pathCompoments replaceObjectAtIndex:0 withObject:@"file://"];
            NSURL* baseURL = [NSURL URLWithString:[NSString pathWithComponents:pathCompoments]];
            [_xwalkWebView loadFileURL:appURL allowingReadAccessToURL:baseURL];
            //NSURLRequest* appReq = [NSURLRequest requestWithURL:appURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];
            //[_xwalkWebView loadRequest:appReq];
        } else {
            NSString* loadErr = [NSString stringWithFormat:@"ERROR: Start Page at '%@/%@' was not found.", self.wwwFolderName, self.startPage];
            NSLog(@"%@", loadErr);

            NSURL* errorUrl = [self errorUrl];
            if (errorUrl) {
                errorUrl = [NSURL URLWithString:[NSString stringWithFormat:@"?error=%@", [loadErr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] relativeToURL:errorUrl];
                NSLog(@"%@", [errorUrl absoluteString]);
                [_xwalkWebView loadRequest:[NSURLRequest requestWithURL:errorUrl]];
            } else {
                NSString* html = [NSString stringWithFormat:@"<html><body> %@ </body></html>", loadErr];
                [_xwalkWebView loadHTMLString:html baseURL:nil];
            }
        }
    }];
    
    
}

- (void)processOpenUrl:(NSURL*)url pageLoaded:(BOOL)pageLoaded
{
    if (!pageLoaded) {
        // query the webview for readystate
        __weak __typeof(self) weakSelf = self;
        [_xwalkWebView evaluateJavaScript:@"document.readyState" completionHandler:^(NSString* _Nullable readyState, NSError * _Nullable error) {
            BOOL loaded = [readyState isEqualToString:@"loaded"] || [readyState isEqualToString:@"complete"];
            if (loaded) {
                // calls into javascript global function 'handleOpenURL'
                NSString* jsString = [NSString stringWithFormat:@"if (typeof handleOpenURL === 'function') { handleOpenURL(\"%@\");}", url];
                [weakSelf.xwalkWebView evaluateJavaScript:jsString completionHandler:nil];
            } else {
                // save for when page has loaded
                [self setValue:url forKey:@"openURL"];
            }
        }];
    }
}

- (id)settingForKey:(NSString*)key
{
    return [[self settings] objectForKey:[key lowercaseString]];
}

- (void)setSetting:(id)setting forKey:(NSString*)key
{
    [[self settings] setObject:setting forKey:[key lowercaseString]];
}

- (NSURL*)appUrl
{
    NSURL* appURL = nil;

    if ([self.startPage rangeOfString:@"://"].location != NSNotFound) {
        appURL = [NSURL URLWithString:self.startPage];
    } else if ([self.wwwFolderName rangeOfString:@"://"].location != NSNotFound) {
        appURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.wwwFolderName, self.startPage]];
    } else {
        // CB-3005 strip parameters from start page to check if page exists in resources
        NSURL* startURL = [NSURL URLWithString:self.startPage];
        NSString* startFilePath = [self.commandDelegate pathForResource:[startURL path]];

        if (startFilePath == nil) {
            appURL = nil;
        } else {
            appURL = [NSURL fileURLWithPath:startFilePath];
            // CB-3005 Add on the query params or fragment.
            NSString* startPageNoParentDirs = self.startPage;
            NSRange r = [startPageNoParentDirs rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"?#"] options:0];
            if (r.location != NSNotFound) {
                NSString* queryAndOrFragment = [self.startPage substringFromIndex:r.location];
                appURL = [NSURL URLWithString:queryAndOrFragment relativeToURL:appURL];
            }
        }
    }

    return appURL;
}

- (NSURL*)errorUrl
{
    NSURL* errorURL = nil;

    id setting = [self settingForKey:@"ErrorUrl"];

    if (setting) {
        NSString* errorUrlString = (NSString*)setting;
        if ([errorUrlString rangeOfString:@"://"].location != NSNotFound) {
            errorURL = [NSURL URLWithString:errorUrlString];
        } else {
            NSURL* url = [NSURL URLWithString:(NSString*)setting];
            NSString* errorFilePath = [self.commandDelegate pathForResource:[url path]];
            if (errorFilePath) {
                errorURL = [NSURL fileURLWithPath:errorFilePath];
            }
        }
    }

    return errorURL;
}

- (void)viewDidUnload
{
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

    _xwalkWebView = nil;
    [CDVUserAgentUtil releaseLock:&_userAgentLockToken];

    [super viewDidUnload];
}

- (void)dealloc {
    _xwalkWebView = nil;
    [CDVUserAgentUtil releaseLock:&_userAgentLockToken];
}

# pragma mark - WKNavigationDelegate
-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"Resetting plugins due to page load.");
    [_commandQueue resetRequestId];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginResetNotification object:_xwalkWebView]];
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"Finished load of: %@", webView.URL);
    // It's safe to release the lock even if this is just a sub-frame that's finished loading.
    [CDVUserAgentUtil releaseLock:&_userAgentLockToken];
    
    /*
     * Hide the Top Activity THROBBER in the Battery Bar
     */
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPageDidLoadNotification object:_xwalkWebView]];
}

/**
 Returns an instance of a CordovaCommand object, based on its name.  If one exists already, it is returned.
 */
/*
- (id)getCommandInstance:(NSString*)pluginName
{
    // first, we try to find the pluginName in the pluginsMap
    // (acts as a whitelist as well) if it does not exist, we return nil
    // NOTE: plugin names are matched as lowercase to avoid problems - however, a
    // possible issue is there can be duplicates possible if you had:
    // "org.apache.cordova.Foo" and "org.apache.cordova.foo" - only the lower-cased entry will match
    NSString* className = [self.pluginsMap objectForKey:[pluginName lowercaseString]];

    if (className == nil) {
        return nil;
    }

    id obj = [self.pluginObjects objectForKey:className];
    if (!obj) {
        obj = [[NSClassFromString(className)alloc] initWithWebView:webView];

        if (obj != nil) {
            [self registerPlugin:obj withClassName:className];
        } else {
            NSLog(@"CDVPlugin class %@ (pluginName: %@) does not exist.", className, pluginName);
        }
    }
    return obj;
}
 */

@end