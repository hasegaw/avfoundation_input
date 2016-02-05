#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import ctypes
import cv2
from numpy.ctypeslib import ndpointer

libavf_dll = os.path.join('.', 'libavf_ctypes.so')
ctypes.cdll.LoadLibrary(libavf_dll)

dll = ctypes.CDLL(libavf_dll)
dll.initialize.argtypes = None
dll.initialize.restype = None
dll.deinitialize.argtypes = None
dll.deinitialize.restype = None
dll.read_frame.argtypes = [ ndpointer(ctypes.c_uint8, flags="C_CONTIGUOUS")]
dll.read_frame.restype = None
dll.select_capture_source.argtypes = [ctypes.c_int]
dll.select_capture_source.restype = None
dll.enumerate_sources.argtypes = None
dll.enumerate_sources.restype = ctypes.c_int
dll.get_source_name.argtypes = [ctypes.c_int]
dll.get_source_name.restype = ctypes.c_char_p

dll.initialize()
import numpy as np
frame = np.zeros((720, 1280, 4), np.uint8)
print(frame.shape, "%x" % frame.ctypes.data)

# AVCaptureSesstionをstartしたあとに一度imshowしてからじゃないとキャプチャデバイスが見えない
# imshowしてから数秒待つべし
cv2.imshow('input', frame)
cv2.waitKey(3000)

# setup capture device
# TODO: デバイス一覧を表示して入力を受け付ける
print('%d devices' % dll.enumerate_sources())
for i in range(dll.enumerate_sources()):
    s = dll.get_source_name(i).decode('utf-8')
    print('%d: %s' % (i, s))

dll.select_capture_source(1)

k = 0
while k != 27:

    dll.read_frame(frame)
    image = cv2.resize(frame, (1280, 720))
    cv2.imshow('input', image)
    k = cv2.waitKey(100)

dll.deinitialize()
