//
//  ViewController.m
//  CodeInjectorSlave
//
//  Created by Maxim Makhun on 5/13/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (void)showAlertWithTitle:(NSString *)title {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:title];
    [alert runModal];
}

- (IBAction)showAlert:(id)sender {
    [self showAlertWithTitle:@"TEST 1"];
}

@end
