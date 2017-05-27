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
@property(nonatomic) id testInstance;

@end

AVCaptureVideoPreviewLayer* getCaptureVideoPreviewLayer(id self,
                                                        SEL _cmd) {
    Ivar ivar = class_getInstanceVariable([self class], "_captureVideoPreviewLayer");
    
    return object_getIvar(self, ivar);
}

void setCaptureVideoPreviewLayer(id self,
                                 SEL _cmd,
                                 AVCaptureVideoPreviewLayer *captureVideoPreviewLayer) {
    Ivar ivar = class_getInstanceVariable([self class], "_captureVideoPreviewLayer");
    id oldValue = object_getIvar(self, ivar);
    if (oldValue != captureVideoPreviewLayer) {
        object_setIvar(self, ivar, captureVideoPreviewLayer);
    }
}

void didOutputSampleBuffer(id self,
                           SEL _cmd,
                           AVCaptureOutput *captureOutput,
                           CMSampleBufferRef sampleBuffer,
                           AVCaptureConnection *connection) {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                sampleBuffer,
                                                                kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    
    NSCIImageRep *ciImageRep = [NSCIImageRep imageRepWithCIImage:ciImage];
    NSImage *nsImage = [[NSImage alloc] initWithSize:ciImageRep.size];
    [nsImage addRepresentation:ciImageRep];
    
    NSData *imageData = [nsImage TIFFRepresentation];
    NSBitmapImageRep *imageRepr = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProperties = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0f]
                                                                forKey:NSImageCompressionFactor];
    imageData = [imageRepr representationUsingType:NSJPEGFileType properties:imageProperties];
    
    BOOL res = [imageData writeToFile:[NSString stringWithFormat:@"camera_output.png"]
                           atomically:NO];
    if (!res) {
        NSLog(@"Unable to save camera output.");
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
    
    SEL didOutputSampleBufferSelector = @selector(captureOutput:didOutputSampleBuffer:fromConnection:);
    success = class_addMethod(testClass, didOutputSampleBufferSelector, (IMP)didOutputSampleBuffer, "v@:@@");
    NSLog(@"%s method %@", "didOutputSampleBuffer", success ? @"was added to class." : @"was not added to class.");
    
    objc_registerClassPair(testClass);
    
    // add test protocol to class
    Protocol *testProtocol = @protocol(AVCaptureVideoDataOutputSampleBufferDelegate);
    NSLog(@"TestClass conforms to protocol TestProtocol: %d", class_conformsToProtocol(testClass, testProtocol));
    class_addProtocol(testClass, testProtocol);
    NSLog(@"TestClass conforms to protocol TestProtocol: %d", class_conformsToProtocol(testClass, testProtocol));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Class testClass = NSClassFromString(@"TestClass");
    self.testInstance = [testClass new];
    
    AVCaptureSession *captureSession = [AVCaptureSession new];
    captureSession.sessionPreset = AVCaptureSessionPreset320x240;
    
    SEL setCaptureVideoPreviewLayerSelector = NSSelectorFromString(@"setCaptureVideoPreviewLayer");
    
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    [self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [self.testInstance performSelector:setCaptureVideoPreviewLayerSelector
                            withObject:self.captureVideoPreviewLayer];
    
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
    
    AVCaptureVideoDataOutput *captureVideoDataOutput = [AVCaptureVideoDataOutput new];
    
    NSDictionary *videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCMPixelFormat_32BGRA]};
    [captureVideoDataOutput setVideoSettings:videoSettings];
    [captureVideoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    [captureVideoDataOutput setSampleBufferDelegate:self.testInstance
                                              queue:dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)];
    [[captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
    
    if ([self.captureVideoPreviewLayer.session canAddOutput:captureVideoDataOutput]) {
        [self.captureVideoPreviewLayer.session addOutput:captureVideoDataOutput];
    } else {
        NSLog(@"Unable to add video data output.");
    }
    
    getProperties([self.testInstance class]);
    getMethods([self.testInstance class]);
    
    // check selector encoding
    // Method thisMethod = class_getInstanceMethod([self class], @selector(captureOutput:didOutputSampleBuffer:fromConnection:));
    // const char *encoding = method_getTypeEncoding(thisMethod);
}

- (void)showAlertWithTitle:(NSString *)title {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:title];
    [alert runModal];
}

- (IBAction)showAlert:(id)sender {
    [self showAlertWithTitle:@"Original alert"];
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
