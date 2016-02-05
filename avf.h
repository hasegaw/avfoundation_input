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

@interface CaptureDevice : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
{
@private
    NSArray *videoDevices;
}

@property (retain) NSArray *videoDevices;
// @property (retain) NSArray *audioDevices;

@end

#ifndef EXPORT_C
#define EXPORT_C extern
#endif

#ifdef __cplusplus
extern "C" {
#endif

EXPORT_C void selectCaptureDevice(int num);
EXPORT_C void readFrame(void *dest);
EXPORT_C int setupAVCapture();
EXPORT_C void stopAVCapture();
EXPORT_C int enumerate_sources();
EXPORT_C const char *get_source_name(int i);
#ifdef __cplusplus
}
#endif
