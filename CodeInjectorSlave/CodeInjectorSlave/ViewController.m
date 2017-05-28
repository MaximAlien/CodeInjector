//
//  ViewController.m
//  CodeInjectorSlave
//
//  Created by Maxim Makhun on 5/13/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController ()

@property(nonatomic) IBOutlet NSView *previewView;

@end

@implementation ViewController

+ (void)load {
    NSLog(@"%s", __FUNCTION__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)showAlertWithTitle:(NSString *)title {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:title];
    [alert runModal];
}

- (IBAction)showAlert:(id)sender {
    [self showAlertWithTitle:@"Original alert"];
    
    getClasses();
    getProperties([self class]);
    getMethods([self class]);
}

#pragma mark - Helper methods

void getClasses() {
    int classCount = objc_getClassList(NULL, 0);
    Class *classes = NULL;

    NSLog(@"Number of classes: %d", classCount);
    
    if (classCount > 0) {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * classCount);
        classCount = objc_getClassList(classes, classCount);
        for (int i = 0; i < classCount; i++) {
            NSLog(@"Class name: %s", class_getName(classes[i]));
        }
        
        free(classes);
    }
}

void getMethods(Class class) {
    uint methodsCount;
    
    Method *methods = class_copyMethodList(class, &methodsCount);
    for (uint i = 0; i < methodsCount; ++i) {
        SEL selector = method_getName(methods[i]);
        const char *methodName = sel_getName(selector);
        
        NSLog(@"Method name: %@", [NSString stringWithCString:methodName encoding:NSUTF8StringEncoding]);
        // method_copyReturnType(<#Method m#>)
        // method_copyArgumentType(<#Method m#>, <#unsigned int index#>)
    }
    
    free(methods);
    NSLog(@"\n");
}

void getProperties(Class class) {
    uint propertiesCount;
    
    objc_property_t *properties = class_copyPropertyList(class, &propertiesCount);
    for (uint i = 0; i < propertiesCount; ++i) {
        NSLog(@"Property name: %@", [NSString stringWithUTF8String:property_getName(properties[i])]);
        
        uint attributesCount;
        objc_property_attribute_t *propertyAttributes = property_copyAttributeList(properties[i], &attributesCount);
        
        for (uint t = 0; t < attributesCount; ++t) {
            NSString *attribute;
            switch (propertyAttributes[t].name[0]) {
                case 'R': // readonly
                    attribute = @"readonly";
                    break;
                case 'C': // copy
                    attribute = @"copy";
                    break;
                case '&': // retain
                    attribute = @"retain";
                    break;
                case 'N': // nonatomic
                    attribute = @"nonatomic";
                    break;
                case 'G': // custom getter
                    attribute = @"custom getter";
                    break;
                case 'S': // custom setter
                    attribute = @"custom setter";
                    break;
                case 'D': // dynamic
                    attribute = @"dynamic";
                    break;
                case 'W': // weak
                    attribute = @"weak";
                    break;
                case 'T': // type
                    attribute = @"type";
                    break;
                case 'P': // eligible for garbage collection
                    attribute = @"eligible for garbage collection";
                    break;
                case 'V': // value
                    attribute = @"value";
                    break;
                default:
                    break;
            }
            
            NSLog(@"Attribute: %@ (%@).%@",
                  attribute,
                  [NSString stringWithUTF8String:&propertyAttributes[t].name[0]],
                  propertyAttributes[t].name[0] == 'V'
                  ? [NSString stringWithFormat:@" Value: %@.", [NSString stringWithUTF8String:propertyAttributes->value]]
                  : @"");
        }
        
        free(propertyAttributes);
    }
    
    free(properties);
    NSLog(@"\n");
}

@end
