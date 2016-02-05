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
#include "avf.h"

int main(int argc, const char * argv[]) {
    int i;
    char filename[255];
    
    initialize();

    i = get_source_count();
    printf("%d devices detected\n", i);
    for (i = 0; i < get_source_count(); i++) {
        const char *dev_name = get_source_name(i);
        printf("%d: %s\n", i, dev_name);
    }

    char *latest_frame = malloc(1280 * 720 * 4);
    
    for ( i = 0; i < 10; i++) {
        sleep(1);
        
        if (1) { // For testing.
            read_frame(latest_frame);

            snprintf((char*) &filename, sizeof(filename), "/tmp/camera.%d.raw", i);
            int fd = open((char*) &filename, O_RDWR|O_CREAT|O_APPEND, 0666);
            int r= write(fd, (const void*) latest_frame, 1280 * 720 * 4);
            close(fd);
        }
    }
    
    deinitialize();
    return 0;
}
