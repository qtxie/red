Red/System [
	Title:	"macOS Camera widget"
	Author: "Xie Qingtian"
	File: 	%camera.reds
	Tabs: 	4
	Notes:  {
		For 10.9+, use AVFoundation, iOS would also use it.
		For 10.0 ~ 10.8, use QTKit.
	}
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

RedCameraSessionKey:	4000FFF0h
RedCameraDevicesKey:	4000FFF1h
RedCameraDevInputKey:	4000FFF2h

AVMediaTypeVideo:		0

init-camera: func [
	camera	[integer!]
	rc		[NSRect!]
	data	[red-block!]
	/local
		devices	[integer!]
		session	[integer!]
		preview	[integer!]
		layer	[integer!]
		av-lib	[integer!]
		p-int	[int-ptr!]
		n		[integer!]
		cnt		[integer!]
		dev		[integer!]
		name	[integer!]
		size	[integer!]
		str		[red-string!]
		cstr	[c-string!]
][
	rc/x: as float32! 0.0
	rc/y: as float32! 0.0
	if zero? AVMediaTypeVideo [
		av-lib: red/platform/dlopen "/System/Library/Frameworks/AVFoundation.framework/Versions/Current/AVFoundation" RTLD_LAZY
		p-int: red/platform/dlsym av-lib "AVMediaTypeVideo"
		AVMediaTypeVideo: p-int/value
	]

	;-- get all devices name
	devices: objc_msgSend [objc_getClass "AVCaptureDevice" sel_getUid "devicesWithMediaType:" AVMediaTypeVideo]
	cnt: objc_msgSend [devices sel_getUid "count"]
	if TYPE_OF(data) <> TYPE_BLOCK [
		block/make-at data cnt
	]
	n: 0
	while [n < cnt] [
		dev: objc_msgSend [devices sel_getUid "objectAtIndex:" n]
		name: objc_msgSend [dev sel_getUid "localizedName"]
		size: objc_msgSend [name sel_getUid "lengthOfBytesUsingEncoding:" NSUTF8StringEncoding]
		cstr: as c-string! objc_msgSend [name sel_getUid "UTF8String"]
		str: string/make-at ALLOC_TAIL(data) size Latin1
		unicode/load-utf8-stream cstr size str null
		n: n + 1
	]

	session: objc_msgSend [objc_getClass "AVCaptureSession" sel_getUid "alloc"]
	session: objc_msgSend [session sel_getUid "init"]

	objc_setAssociatedObject camera RedCameraSessionKey session OBJC_ASSOCIATION_ASSIGN
	objc_setAssociatedObject camera RedCameraDevicesKey devices OBJC_ASSOCIATION_RETAIN

	preview: objc_msgSend [objc_getClass "AVCaptureVideoPreviewLayer" sel_getUid "layerWithSession:" session]
	objc_msgSend [preview sel_getUid "setFrame:" rc/x rc/y rc/w rc/h]
	layer: objc_msgSend [camera sel_getUid "setWantsLayer:" yes]
	layer: objc_msgSend [camera sel_getUid "layer"]
	objc_msgSend [layer sel_getUid "addSublayer:" preview]
]

select-camera: func [
	camera		[integer!]
	idx			[integer!]
	/local
		session [integer!]
		devices [integer!]
		dev		[integer!]
		dev-in	[integer!]
		cur-dev	[integer!]
][
	session: objc_getAssociatedObject camera RedCameraSessionKey
	devices: objc_getAssociatedObject camera RedCameraDevicesKey
	cur-dev: objc_getAssociatedObject camera RedCameraDevInputKey		;-- current device input

	dev: objc_msgSend [devices sel_getUid "objectAtIndex:" idx]
	dev-in: objc_msgSend [objc_getClass "AVCaptureDeviceInput" sel_getUid "deviceInputWithDevice:error:" dev 0]
	if zero? dev-in [exit]

	objc_msgSend [session sel_getUid "beginConfiguration"]
	if cur-dev <> 0 [
		objc_msgSend [session sel_getUid "removeInput:" cur-dev]
		objc_setAssociatedObject camera RedCameraDevInputKey 0 OBJC_ASSOCIATION_ASSIGN
	]
	objc_msgSend [session sel_getUid "addInput:" dev-in]
	objc_setAssociatedObject camera RedCameraDevInputKey dev-in OBJC_ASSOCIATION_ASSIGN
	objc_msgSend [session sel_getUid "commitConfiguration"]
]

toggle-preview: func [
	camera		[integer!]
	enable?		[logic!]
	/local
		session [integer!]
][
	session: objc_getAssociatedObject camera RedCameraSessionKey
	either enable? [
		objc_msgSend [session sel_getUid "startRunning"]
	][
		objc_msgSend [session sel_getUid "stopRunning"]
	]
]