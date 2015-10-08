CFLAGS= -fobjc-arc -framework Foundation -framework AVFoundation -framework CoreVideo -framework CoreMedia

all:
	make clean
	clang ${CFLAGS} avf.m write_frames_to_tempdir.m -o write_frames_to_tempdir
	clang ${CFLAGS} -DAVFLIB_CTYPES -shared avf.m -o libavf_ctypes.so

clean:
	rm -f wrtite_frames_to_tempdir libavf_ctypes.so

test:
	@echo "Test 1: write_frames_to_tempdir (Write snapsots to /tmp/camera.[0-9].raw)"
	@echo
	rm -f /tmp/camera.?.raw
	@echo
	./write_frames_to_tempdir
	ls -l /tmp/camera.?.raw
	@echo
	@echo "Test 2: python3 test_libavf_ctypes.py (Preview for 10 seconds)"
	@echo
	python3 test_libavf_ctypes.py
