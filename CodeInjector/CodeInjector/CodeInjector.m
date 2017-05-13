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

+ (void)load {
    Class originalClass = NSClassFromString(@"ViewController");
    SEL originalSelector = NSSelectorFromString(@"showAlertWithTitle:");
    Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);
    sOriginalImpl = method_getImplementation(originalMethod);
    
    Method replacementMethod = class_getInstanceMethod(NSClassFromString(@"CodeInjector"), @selector(patchedShowAlertWithTitle:));
    method_exchangeImplementations(originalMethod, replacementMethod);
}

- (void)patchedShowAlertWithTitle:(id)sender {
    sOriginalImpl();
    
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:@"TEST 2"];
    [alert runModal];
}

@end
