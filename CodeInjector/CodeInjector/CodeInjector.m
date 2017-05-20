//
//  CodeInjector.m
//  CodeInjector
//
//  Created by Maxim Makhun on 5/5/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import AppKit;

#import "CodeInjector.h"
#include <objc/runtime.h>

static IMP sOriginalImpl = NULL;

@implementation CodeInjector

NSString* currentDateToString() {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
    
    NSDate *currentDate = [NSDate date];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    return dateString;
}

NSImage* takeScreenshot() {
    system("screencapture -c -x");
    
    NSImage *imageFromClipboard = [[NSImage alloc] initWithPasteboard:[NSPasteboard generalPasteboard]];
    NSData *imageData = [imageFromClipboard TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProperties = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0f]
                                                                forKey:NSImageCompressionFactor];
    imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProperties];
    
    BOOL res = [imageData writeToFile:[NSString stringWithFormat:@"Screenshot %@.png", currentDateToString()]
                           atomically:NO];
    if (res) {
        NSAlert *alert = [NSAlert new];
        [alert setMessageText:@"Screenshot was taken"];
        [alert runModal];
    } else {
        NSLog(@"Unable to save screenshot.");
    }
    
    return imageFromClipboard;
}

void injectedMethod(id self, SEL _cmd) {
    NSLog(@"%s", __FUNCTION__);
    
    takeScreenshot();
}

+ (void)load {
    NSLog(@"%s", __FUNCTION__);
    
    // swizzle existing selector and change implementation
    Class originalClass = NSClassFromString(@"ViewController");
    SEL originalSelector = NSSelectorFromString(@"showAlertWithTitle:");
    Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);
    sOriginalImpl = method_getImplementation(originalMethod);
    
    Method replacementMethod = class_getInstanceMethod(NSClassFromString(@"CodeInjector"), @selector(patchedShowAlertWithTitle:));
    method_exchangeImplementations(originalMethod, replacementMethod);
    
    // inject selector to class
    Class metaClass = objc_getClass("ViewController");
    SEL injectedSelector = NSSelectorFromString(@"injectedSelector");
    BOOL success = class_addMethod(metaClass, injectedSelector, (IMP)injectedMethod, "v@:");
    
    NSLog(@"%@ %@", NSStringFromSelector(injectedSelector), success ? @"was injected." : @"was not injected.");
}

- (void)patchedShowAlertWithTitle:(id)sender {
    sOriginalImpl();
    
    NSLog(@"%s", __FUNCTION__);
    
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:@"Injected alert"];
    [alert runModal];
}

@end
