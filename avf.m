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

#include <stdio.h>
#include "avf.h"

@implementation CaptureDevice

@synthesize videoDevices;

static char *latest_frame;
static NSLock* _lock;
static NSArray *observers;

static AVCaptureSession *captureSession;
static CaptureDevice *captureDevice;
static AVCaptureVideoDataOutput *videoDataOutput;
static AVCaptureDeviceInput *videoInput;

- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
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
    // printf("Capture: %d %d %d dest %p src %p size %zu\n", (int)bytesPerRow, (int)width, (int)height, latest_frame, baseAddress, frameBytes);

    // Now we have the baseAddress to the image uncompressed, with format
    // [720, 1280, 4]. We don't need last plane (A) but it's more easier to
    // remove the plane with Python NumPy, so we just pass whole data to
    // Python world.

    // Latest frame data is always in latest_frame buffer.

    if (height == 720)
    {
        [_lock lock];

        memcpy(latest_frame, baseAddress, frameBytes);

        [_lock unlock];
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

- (void)refreshDevices
{
    // NSLog(@"Call refreshDevices");
    [self setVideoDevices:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]];
    // [self setAudioDevices:[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio]];
    [[self videoDevices] enumerateObjectsUsingBlock:^(AVCaptureDevice *Device, NSUInteger idx, BOOL *stop) {
        NSLog(@"Device[%lu]: %@", idx, Device.localizedName);
    }];
}

- (id)init
{
    self = [super init];

    if (self)
        _lock = [[NSLock alloc] init];

        // Create a capture session
        captureSession = [[AVCaptureSession alloc] init];

        // Capture Notification Observers
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        id deviceWasConnectedObserver =
            [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                // NSLog(@"detected capture device");
                [self refreshDevices];
            }];
        observers = [[NSArray alloc] initWithObjects:deviceWasConnectedObserver, nil];

    latest_frame = malloc(1280*720*4);

    return self;
}

@end


#ifdef __cplusplus
extern "C" {
#endif

EXPORT_C int initialize()
{
    // printf("initialize\n");
    NSError *e = nil;

    NSDictionary *newSettings;
    AVCaptureDevice *camera;

    // AVCaptureSessionはCaptureDeviceの中で初期化
    captureDevice = [[CaptureDevice alloc] init];

    // カメラデバイスを取得(FaceTimeカメラしか取れないのでキャプチャデバイスは後で)
    NSArray *cameraDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *Device in cameraDevices)
    {
        // NSLog(@"Found camera device: %@ | uniqueID:%@ | modelID:%@",
                // Device.localizedName, Device.uniqueID, Device.modelID);
        camera = Device;
    }

    // カメラからの入力を作成
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:&e];

    if (videoInput) {
        [captureSession addInput:videoInput];
    } else {
        return 0;
        // Handle the failure.
    }

    // FIXME: Audio

    // FIXME: BlackMagic hardwares need to be configured with proper frame rates.
    //        For WiiU, 720p@59.997 is appropriate.

    // FIXME: Must specify 720p
    // if ([captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
    // {
        // NSLog(@"Set 1280x720");
        // captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    // }
    // else
    // {
        // NSLog(@"Set 640x480");
        // captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    // }
    // captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    captureSession.sessionPreset = AVCaptureSessionPresetHigh;


    // 出力用のいろいろ
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureSession addOutput:videoDataOutput];

    newSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
    };
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

    // セッションをスタートさせる
    [captureSession startRunning];

    return 1;
error:
    printf("error?\n");
    return 0;
}

EXPORT_C void deinitialize() {
    [captureSession stopRunning];
    // NSLog(@"stop running");
}

EXPORT_C void read_frame(void *dest) {
    [_lock lock];

    memcpy(dest, latest_frame, 1280 * 720 * 4);

    [_lock unlock];
}

EXPORT_C int enumerate_sources() {
    [captureDevice setVideoDevices:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]];
    return [[captureDevice videoDevices] count];
}

EXPORT_C const char *get_source_name(int i) {
    if (i >= enumerate_sources())
        return NULL;

    return [[[captureDevice videoDevices][i] localizedName] UTF8String];
}

EXPORT_C void select_capture_source(int num)
{
    AVCaptureDevice *camera;

    if (num >= enumerate_sources()) {
        printf("Device number out of range\n");
        return;
    }

    // NSLog(@"select_capture_source(%d)", num);
    [captureDevice setVideoDevices:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]];
    camera = [captureDevice videoDevices][num];
    NSLog(@"Seleted capture device: %@ | uniqueID:%@ | modelID:%@",
        camera.localizedName, camera.uniqueID, camera.modelID);

    [_lock lock];
    // キャプチャデバイスの再設定
    [captureSession beginConfiguration];

    if (videoInput) {
        // Remove the old device input from the session
        [captureSession removeInput:videoInput];
        setVideoInput:nil;
    }

    if (camera)
    {
        NSError *error = nil;
        // Create a device input for the device and add it to the session
        videoInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
        if (videoInput) {
            if (![camera supportsAVCaptureSessionPreset:[captureSession sessionPreset]])
                captureSession.sessionPreset = AVCaptureSessionPresetHigh;

            [captureSession addInput:videoInput];
        }
    }

    if ([camera hasMediaType:AVMediaTypeMuxed] || [camera hasMediaType:AVMediaTypeAudio])
    {
        NSLog(@"Selected video device has audio device, but not implemented.");
    }

    [captureSession commitConfiguration];
    [_lock unlock];
}

#ifdef __cplusplus
} /* extern "C" */
#endif
