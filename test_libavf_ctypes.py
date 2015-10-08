import os
import ctypes
import time
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

dll.setupAVCapture()
import numpy as np
frame = np.zeros((720, 1280, 4), np.uint8)
print(frame.shape, "%x" % frame.ctypes.data)
n = 100
while n > 0:
    n = n - 1
    
    dll.readFrame(frame)

    cv2.imshow('input', frame)
    cv2.waitKey(100)

dll.stopAVCapture()

