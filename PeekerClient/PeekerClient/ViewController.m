//
//  ViewController.m
//  PeekerClient
//
//  Created by Maxim Makhun on 5/28/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"


static const int dataLength = 3686432;

@interface ViewController () <GCDAsyncSocketDelegate>

@property (nonatomic) GCDAsyncSocket *socket;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic) NSMutableData *fullData;
@property (nonatomic) UIImage *image;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.fullData = [[NSMutableData alloc] init];
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                             delegateQueue:dispatch_queue_create("AsyncSocketQueue", DISPATCH_QUEUE_SERIAL)];
    
    NSError *error;
    
    if (![self.socket connectToHost:@"127.0.0.1"
                             onPort:9001
                              error:&error]) {
        NSLog(@"Wasn't able to connect to host. %s", __func__);
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(NSError *)error {
    [self.socket connectToHost:@"127.0.0.1"
                        onPort:9001
                         error:&error];
}

- (void)socket:(GCDAsyncSocket *)socket
   didReadData:(NSData *)data
       withTag:(long)tag {
    if (self.fullData.length <= dataLength) {
        [self.fullData appendData:data];
    } else {
        CFDataRef dataRef = (__bridge CFDataRef)self.fullData;
        CGDataProviderRef dataProviderRef = CGDataProviderCreateWithCFData(dataRef);
        
        int width = 1280;
        int height = 720;
        int bitsPerComponent = 8;
        int bitsPerPixel = 32;
        int bytesPerRow = 5120;
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little;
        CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
        
        CGImageRef imageRef = CGImageCreate(width,
                                            height,
                                            bitsPerComponent,
                                            bitsPerPixel,
                                            bytesPerRow,
                                            colorSpaceRef,
                                            bitmapInfo,
                                            dataProviderRef,
                                            NULL,
                                            NO,
                                            renderingIntent);
        
        self.image = [[UIImage alloc] initWithCGImage:imageRef];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.imageView setImage:self.image];
        });
        
        CGImageRelease(imageRef);
        CGColorSpaceRelease(colorSpaceRef);
        CGDataProviderRelease(dataProviderRef);
        
        [self.fullData setLength:0];
    }
    
    [socket readDataToLength:data.length
                 withTimeout:-1
                         tag:0];
}

- (void)socket:(GCDAsyncSocket *)socket
didConnectToHost:(NSString *)host
          port:(uint16_t)port {
    [self.socket readDataWithTimeout:-1 tag:0];
}

@end
