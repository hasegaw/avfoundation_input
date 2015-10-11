#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import ctypes
import cv2
from numpy.ctypeslib import ndpointer

libavf_dll = os.path.join('.', 'libavf_ctypes.so')
ctypes.cdll.LoadLibrary(libavf_dll)

dll = ctypes.CDLL(libavf_dll)
dll.setupAVCapture.argtypes = None
dll.setupAVCapture.restype = None
dll.stopAVCapture.argtypes = None
dll.stopAVCapture.restype = None
dll.readFrame.argtypes = [ ndpointer(ctypes.c_uint8, flags="C_CONTIGUOUS")]
dll.readFrame.restype = None
dll.selectCaptureDevice.argtypes = [ctypes.c_int]
dll.selectCaptureDevice.restype = None

dll.setupAVCapture()
import numpy as np
frame = np.zeros((720, 1280, 4), np.uint8)
print(frame.shape, "%x" % frame.ctypes.data)

# AVCaptureSesstionをstartしたあとに一度imshowしてからじゃないとキャプチャデバイスが見えない
# imshowしてから数秒待つべし
cv2.imshow('input', frame)
cv2.waitKey(3000)

# setup capture device
# TODO: デバイス一覧を表示して入力を受け付ける
dll.selectCaptureDevice(1)

k = 0
while k != 27:

    dll.readFrame(frame)
    image = cv2.resize(frame, (1280, 720))
    cv2.imshow('input', image)
    k = cv2.waitKey(100)

dll.stopAVCapture()
