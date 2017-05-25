//
//  ViewController.m
//  CodeInjectorSlave
//
//  Created by Maxim Makhun on 5/13/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import AVFoundation;

#import "ViewController.h"
#include <objc/runtime.h>

@interface ViewController ()

@property(nonatomic) IBOutlet NSView *previewView;

@property(nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@end

AVCaptureVideoPreviewLayer* getCaptureVideoPreviewLayer(id self, SEL _cmd) {
    Ivar ivar = class_getInstanceVariable([self class], "_captureVideoPreviewLayer");
    
    return object_getIvar(self, ivar);
}

void setCaptureVideoPreviewLayer(id self, SEL _cmd, AVCaptureVideoPreviewLayer *captureVideoPreviewLayer) {
    Ivar ivar = class_getInstanceVariable([self class], "_captureVideoPreviewLayer");
    id oldValue = object_getIvar(self, ivar);
    if (oldValue != captureVideoPreviewLayer) {
        object_setIvar(self, ivar, captureVideoPreviewLayer);
    }
}

@implementation ViewController

+ (void)load {
    NSLog(@"%s", __FUNCTION__);
    
    // create new class
    Class testClass = NSClassFromString(@"TestClass");
    if (testClass == nil) {
        testClass = objc_allocateClassPair([NSObject class], [@"TestClass" UTF8String], 0);
    }
    
    // inject property to class
    objc_property_attribute_t type = {"T", "@\"AVCaptureVideoPreviewLayer\""};
    objc_property_attribute_t nonatomic = {"N", ""};
    objc_property_attribute_t ivar  = {"V", "_captureVideoPreviewLayer"};
    objc_property_attribute_t attributes[] = {type, nonatomic, ivar};
    SEL captureVideoPreviewLayerSelector = NSSelectorFromString(@"captureVideoPreviewLayer");
    BOOL success = class_addMethod(testClass, captureVideoPreviewLayerSelector, (IMP)getCaptureVideoPreviewLayer, "@@:");
    NSLog(@"%s method %@", "getCaptureVideoPreviewLayer", success ? @"was added to class." : @"was not added to class.");
    
    SEL setCaptureVideoPreviewLayerSelector = NSSelectorFromString(@"setCaptureVideoPreviewLayer");
    success = class_addMethod(testClass, setCaptureVideoPreviewLayerSelector, (IMP)setCaptureVideoPreviewLayer, "v@:@");
    NSLog(@"%s method %@", "setCaptureVideoPreviewLayer", success ? @"was added to class." : @"was not added to class.");
    
    success = class_addProperty(testClass, "captureVideoPreviewLayer", attributes, 3);
    NSLog(@"%s %@", "captureVideoPreviewLayer", success ? @"was injected." : @"was not injected.");
    
    // add ivar to class
    char *classEncoding = @encode(NSObject);
    NSUInteger classSize, classAlignment;
    NSGetSizeAndAlignment(classEncoding, &classSize, &classAlignment);
    success = class_addIvar(testClass, "_captureVideoPreviewLayer", classSize, classAlignment, classEncoding);
    
    NSLog(@"%s ivar %@", "_captureVideoPreviewLayer", success ? @"was injected." : @"was not injected.");
    
    objc_registerClassPair(testClass);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Class testClass = NSClassFromString(@"TestClass");
    id testInstance = [testClass new];
    
    AVCaptureSession *captureSession = [AVCaptureSession new];
    captureSession.sessionPreset = AVCaptureSessionPreset320x240;
    
    SEL setCaptureVideoPreviewLayerSelector = NSSelectorFromString(@"setCaptureVideoPreviewLayer");
    
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    [self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [testInstance performSelector:setCaptureVideoPreviewLayerSelector
                       withObject:self.captureVideoPreviewLayer];
    
    // SEL captureVideoPreviewLayerSelector = NSSelectorFromString(@"captureVideoPreviewLayer");
    // AVCaptureVideoPreviewLayer *captureVideoPreviewLayer1 = [self.testInstance performSelector:captureVideoPreviewLayerSelector];
    
    [captureSession startRunning];
    
    NSArray *captureDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevices[0]
                                                                                     error:&error];
    
    if (error) {
        NSLog(@"Unable to create capture device input. Error: %@", error);
    }
    
    [captureSession beginConfiguration];
    
    if ([captureSession canAddInput:captureDeviceInput]) {
        [captureSession addInput:captureDeviceInput];
    } else {
        NSLog(@"Unable to add new input.");
    }
    
    [captureSession commitConfiguration];
    
    getProperties([testInstance class]);
}

- (void)showAlertWithTitle:(NSString *)title {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:title];
    [alert runModal];
}

- (IBAction)showAlert:(id)sender {
    [self showAlertWithTitle:@"Original alert"];

    // check whether newly injected selector works as expected
    SEL injectedSelector = NSSelectorFromString(@"injectedSelector");
    [self performSelectorOnMainThread:injectedSelector withObject:nil waitUntilDone:YES];
}

#pragma mark - Helper methods

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
