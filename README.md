# ADJV (Adjacent Vehicle)

This is a test app to try to implement the features of Apple's Sidecar for a Linux host and iDevice client. It listens on a port for TCP packets containing H264 video in an elementary stream (Annex B) format, parses them, and feeds them into Apple's AVSampleBufferDisplayLayer for viewing (Unfortunely, no touch or pen input is supported).

## Note on Wired Connectivity

With [usbmuxd](https://github.com/libimobiledevice/usbmuxd), there is a hidden and undocumented feature that allows you to have an iDevice expose an ethernet interface over USB. By setting `USBMUXD_DEFAULT_DEVICE_MODE=3` as an environment variable, you can now easily interact with your iDevice over IP (UDP as well!). More info about this [here](https://github.com/libimobiledevice/usbmuxd/issues/205)

I only managed to figure this out after finishing this test project. Instead, this project uses iproxy (a utility that uses usbmuxd), to forward tcp connections only (slower).

## Client Side

All you have to do on the client side is open the app!

## Server Side

For the server side (the side you want to stream video from), I wrote a bash script that allows you to stream with one command (assuming you use X, and libusbmuxd and ffmpeg are installed):

```bash
#!/bin/bash

FPS=120
# change dest if using new connection method
DEST=tcp://127.0.0.1:8080 
DISPLAY_SZ=2560x1600
DISPLAY=:0.0

# forward localhost 8080 to device 8080
iproxy 8080 8080 &

ffmpeg -video_size $DISPLAY_SZ -framerate $FPS -f x11grab -i $DISPLAY \
	-c:v h264_nvenc -b:v 20M -tune:v ull -zerolatency 1 \
	-f h264 -r $FPS -g 1200 $DEST

# kills iproxy when exiting script
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
```
