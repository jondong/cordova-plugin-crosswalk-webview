//
//  XWalkCommandDelegate.m
//  HelloWorld
//
//  Created by DongYan on 15/11/28.
//
//

#import "XWalkCommandDelegate.h"

#import "XWalkViewController.h"

@interface XWalkCommandDelegate() {
    __weak XWalkViewController* _xwalkViewController;
}
@end

@implementation XWalkCommandDelegate

- (id)initWithViewController:(XWalkViewController*)viewController {
    if (self = [super initWithViewController:viewController]) {
        _xwalkViewController = viewController;
    }
    return self;
}

- (void)evalJsHelper2:(NSString*)js
{
    [_xwalkViewController.xwalkWebView evaluateJavaScript:js completionHandler:^(id result, NSError* error) {
        if (![result isKindOfClass:[NSString class]]) {
            return;
        }
        NSString* commandJSON = (NSString*)result;
        if (commandJSON.length > 0) {
            NSLog(@"Exec: Retrieved new exec messages by chaining.");
        }
        [_commandQueue enqueueCommandBatch:commandJSON];
        [_commandQueue executePending];
    }];
}

@end
