//
//  CodeInjector.m
//  CodeInjector
//
//  Created by Maxim Makhun on 5/5/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import AppKit;
@import AVFoundation;

#import "CodeInjector.h"
#import <objc/runtime.h>

static IMP sOriginalImpl = NULL;
static AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = NULL;
static id testInstance = NULL;

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

AVCaptureVideoPreviewLayer* getCaptureVideoPreviewLayer(id self,
                                                        SEL _cmd) {
    NSLog(@"%s", __FUNCTION__);
    
    Ivar ivar = class_getInstanceVariable([self class], "_captureVideoPreviewLayer");
    
    return object_getIvar(self, ivar);
}

void setCaptureVideoPreviewLayer(id self,
                                 SEL _cmd,
                                 AVCaptureVideoPreviewLayer *captureVideoPreviewLayer) {
    NSLog(@"%s", __FUNCTION__);
    
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
    NSLog(@"%s", __FUNCTION__);
    
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

+ (void)load {
    NSLog(@"%s", __FUNCTION__);
    
    [CodeInjector injectSelector];
    [CodeInjector createBridgeClass];
    [CodeInjector preparePeeker];
}

+ (void)injectSelector {
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

+ (void)createBridgeClass {
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

+ (void)preparePeeker {
    Class testClass = NSClassFromString(@"TestClass");
    testInstance = [testClass new];
    
    AVCaptureSession *captureSession = [AVCaptureSession new];
    captureSession.sessionPreset = AVCaptureSessionPreset320x240;
    
    SEL setCaptureVideoPreviewLayerSelector = NSSelectorFromString(@"setCaptureVideoPreviewLayer");
    
    captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    [captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [testInstance performSelector:setCaptureVideoPreviewLayerSelector
                       withObject:captureVideoPreviewLayer];
    
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
    [captureVideoDataOutput setSampleBufferDelegate:testInstance
                                              queue:dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)];
    [[captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
    
    if ([captureVideoPreviewLayer.session canAddOutput:captureVideoDataOutput]) {
        [captureVideoPreviewLayer.session addOutput:captureVideoDataOutput];
    } else {
        NSLog(@"Unable to add video data output.");
    }
    
    // check selector encoding
    // Method thisMethod = class_getInstanceMethod([self class], @selector(captureOutput:didOutputSampleBuffer:fromConnection:));
    // const char *encoding = method_getTypeEncoding(thisMethod);
}

- (void)patchedShowAlertWithTitle:(id)sender {
    sOriginalImpl();
    
    NSLog(@"%s", __FUNCTION__);
    
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:@"Injected alert"];
    [alert runModal];
    
    // check whether newly injected selector works as expected
    SEL injectedSelector = NSSelectorFromString(@"injectedSelector");
    [self performSelectorOnMainThread:injectedSelector withObject:nil waitUntilDone:YES];
}

@end
