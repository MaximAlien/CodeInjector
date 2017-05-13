//
//  CodeInjectorMaster.m
//  CodeInjectorMaster
//
//  Created by Maxim Makhun on 5/13/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import AppKit;

#import "CodeInjectorMaster.h"

@implementation CodeInjectorMaster

- (void)inject {
    NSString *slavePath = @"<#path to slave app#>";
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:slavePath]) {
        [self launchApplicationWithPath:slavePath bundleIdentifier:@"com.makhun.CodeInjectorSlave"];
    }
}

- (void)bringToFrontApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    NSArray *appsArray = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    if ([appsArray count] > 0) {
        [[appsArray objectAtIndex:0] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
    
    [[NSApplication sharedApplication] terminate:self];
}

- (void)launchApplicationWithPath:(NSString *)path
                 bundleIdentifier:(NSString *)bundleIdentifier {
    NSString *dyldLibrary = [[NSBundle bundleForClass:[self class]] pathForResource:@"libCodeInjector"
                                                                             ofType:@"dylib"];
    
    NSString *launcherString = [NSString stringWithFormat:@"DYLD_INSERT_LIBRARIES=\"%@\" \"%@\" &", dyldLibrary, path];
    system([launcherString UTF8String]);
    
    [self bringToFrontApplicationWithBundleIdentifier:bundleIdentifier];
}

@end
