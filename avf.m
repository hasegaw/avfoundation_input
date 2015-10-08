/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*  AVFoundation Binding
 *  ====================
 *  Copyright (C) 2015 Takeshi HASEGAWA
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

#include <stdio.h>
#include "avf.h"

@interface CaptureDevice : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation CaptureDevice

static char *latest_frame;
static NSLock* _lock;

static AVCaptureSession *captureSession;
static CaptureDevice *captureDevice;
static AVCaptureVideoDataOutput *videoDataOutput;
static AVCaptureDevice *camera;
static AVCaptureDeviceInput *videoInput;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    void *baseAddress;
    CVImageBufferRef imageBuffer;
    size_t bytesPerRow, width, height, frameBytes;
    
    imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    width = CVPixelBufferGetWidth(imageBuffer);
    height = CVPixelBufferGetHeight(imageBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    if (pixelFormat != kCVPixelFormatType_32BGRA) {
        // FIXME: It's not 32bit BGRA... We will need to convert the format?
        printf("unknown format!\n");
        return;
    }

    baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    frameBytes = bytesPerRow * height;
    // printf("Capture: %d %d %d dest %p src %p size %d\n", (int)bytesPerRow, (int)width, (int)height, latest_frame, baseAddress, frameBytes);
    
    // Now we have the baseAddress to the image uncompressed, with format
    // [720, 1280, 4]. We don't need last plane (A) but it's more easier to
    // remove the plane with Python NumPy, so we just pass whole data to
    // Python world.

    // Latest frame data is always in latest_frame buffer.

    [_lock lock];
    
    memcpy(latest_frame, baseAddress, frameBytes);

    [_lock unlock];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}


- (id)init
{
    self = [super init];
    
    if (self)
        _lock = [[NSLock alloc] init];
    
    latest_frame = malloc(1280*720*4);
    
    return self;
}

@end


#ifdef __cplusplus
extern "C" {
#endif

EXPORT_C int setupAVCapture()
{
    // printf("setupAVCapture\n");
    NSError *e = nil;
    
    NSDictionary *newSettings;
    
    captureDevice = [[CaptureDevice alloc] init];
    captureSession = [[AVCaptureSession alloc] init];

    // FIXME: Must specify 720p
    
    captureSession.sessionPreset = AVCaptureSessionPresetMedium;

    // FIXME: Must find and initialize the proper device.
    
    camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:&e];

    // FIXME: BlackMagic hardwares need to be configured with proper frame rates.
    //        For WiiU, 720p@59.997 is appropriate.
    
    if (videoInput) {
        [captureSession addInput:videoInput];
    }
    else {
        return 0;
        // Handle the failure.
    }

    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureSession addOutput:videoDataOutput];

    newSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey :
                          @(kCVPixelFormatType_32BGRA) };
    videoDataOutput.videoSettings = newSettings;

    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:TRUE];
    [videoDataOutput setSampleBufferDelegate:captureDevice queue:queue];
    
    // Output Format = BGRA
    videoDataOutput.videoSettings = @{
                                           (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                           };
    // ビデオ入力のAVCaptureConnectionを取得
    AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    // 1秒あたり4回画像をキャプチャ
    videoConnection.videoMinFrameDuration = CMTimeMake(1, 4);
    
    [captureSession  startRunning];
    return 1;
error:
    printf("error?\n");
    return 0;
}

EXPORT_C void stopAVCapture() {
    [captureSession stopRunning];
    NSLog(@"stop running");

}

EXPORT_C void readFrame(void *dest) {
    [_lock lock];
   
    memcpy(dest, latest_frame, 1280 * 720 * 4);
    
    [_lock unlock];
}

#ifdef __cplusplus
} /* extern "C" */
#endif
