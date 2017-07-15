//
//  ViewController.m
//  CodeInjectorSlave
//
//  Created by Maxim Makhun on 5/13/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import AVFoundation;

#import "ViewController.h"
#import "GCDAsyncSocket.h"
#import <objc/runtime.h>

#import <ifaddrs.h>
#import <arpa/inet.h>

static AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = NULL;
static id testInstance = NULL;
static NSMutableArray *connectedClients;

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

void writeDataToClients(NSData *data) {
    if (connectedClients) {
        for (GCDAsyncSocket *socket in connectedClients) {
            if ([socket isConnected]) {
                [socket writeData:data withTimeout:-1 tag:0];
            } else {
                if ([connectedClients containsObject:socket]) {
                    [connectedClients removeObject:socket];
                }
            }
        }
    }
}

void didOutputSampleBuffer(id self,
                           SEL _cmd,
                           AVCaptureOutput *captureOutput,
                           CMSampleBufferRef sampleBuffer,
                           AVCaptureConnection *connection) {
    NSLog(@"%s", __FUNCTION__);
    
    @autoreleasepool {
        CFRetain(sampleBuffer);
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
        CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
        
        CGImageRef imageRef = CGImageCreate(width,
                                            height,
                                            8,
                                            32,
                                            bytesPerRow,
                                            colorSpace,
                                            kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                                            dataProvider,
                                            NULL,
                                            true,
                                            kCGRenderingIntentDefault);
        
        CGDataProviderRelease(dataProvider);
        
        NSData *data = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
        writeDataToClients(data);
        
        NSImage *nsImage = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(width, height)];
        NSData *imageData = [nsImage TIFFRepresentation];
        
        BOOL res = [imageData writeToFile:[NSString stringWithFormat:@"camera_output.png"]
                               atomically:NO];
        if (!res) {
            NSLog(@"Unable to save camera output.");
        }
        
        CGImageRelease(imageRef);
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        CFRelease(sampleBuffer);
    }
}

@interface ViewController () <GCDAsyncSocketDelegate>

@property(nonatomic) IBOutlet NSView *previewView;
@property(nonatomic) GCDAsyncSocket *serverSocket;

@end

@implementation ViewController

+ (void)load {
    NSLog(@"%s", __FUNCTION__);
    
    connectedClients = [NSMutableArray new];
    
    [ViewController createBridgeClass];
    [ViewController preparePeeker];
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
    captureSession.sessionPreset = AVCaptureSessionPresetLow;
    
    SEL setCaptureVideoPreviewLayerSelector = NSSelectorFromString(@"setCaptureVideoPreviewLayer");
    
    captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    [captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [testInstance performSelector:setCaptureVideoPreviewLayerSelector
                       withObject:captureVideoPreviewLayer];
#pragma clang diagnostic pop
    
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                   delegateQueue:dispatch_queue_create("AsyncSocketQueue", DISPATCH_QUEUE_SERIAL)];
    NSError *error = nil;
    if (self.serverSocket) {
        [self.serverSocket acceptOnPort:9001 error:&error];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket
                  withError:(NSError *)error {
    if (connectedClients) {
        [connectedClients removeObject:socket];
    }
}

- (void)socket:(GCDAsyncSocket *)socket
didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"Accepted new socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]);
    
    @synchronized(connectedClients) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (connectedClients) {
                [connectedClients addObject:newSocket];
            }
        });
    }
    
    NSError *error = nil;
    if (self.serverSocket) {
        [self.serverSocket acceptOnPort:9001
                                  error:&error];
    }
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

- (NSString *)ipAddress {
    NSString *address = @"invalid";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    success = getifaddrs(&interfaces);
    
    if (success == 0) {
        temp_addr = interfaces;
        
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return address;
}

@end
