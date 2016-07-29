Red/System [
	Title:	"Cocoa imports"
	Author: "Qingtian Xie"
	File: 	%cocoa.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define RTLD_LAZY	1

#define gestaltSystemVersion		1937339254			;-- "sysv"
#define gestaltSystemVersion		1937339185			;-- "sys1"
#define gestaltSystemVersion		1937339186			;-- "sys2"
#define gestaltSystemVersion		1937339187			;-- "sys3"

#define NSAnyEventMask				-1

#define NSUtilityWindowMask         16
#define NSDocModalWindowMask        32
#define NSBorderlessWindowMask      0
#define NSTitledWindowMask          1
#define NSClosableWindowMask        2
#define NSMiniaturizableWindowMask  4
#define NSResizableWindowMask       8
#define NSIconWindowMask            64
#define NSMiniWindowMask            128

#define NSViewNotSizable			0
#define NSViewMinXMargin			1
#define NSViewWidthSizable			2
#define NSViewMaxXMargin			4
#define NSViewMinYMargin			8
#define NSViewHeightSizable			16
#define NSViewMaxYMargin			32

#define NSRoundedBezelStyle			1

#define NSToggleButton				2
#define NSSwitchButton				3
#define NSRadioButton				4
#define NSMomentaryPushInButton		7

#define NSNoBorder					0
#define NSLineBorder				1
#define NSBezelBorder				2
#define NSGrooveBorder				3

#define NSNoTitle					0
#define NSAboveTop					1
#define NSAtTop						2
#define NSBelowTop					3
#define NSAboveBottom				4
#define NSAtBottom					5
#define NSBelowBottom				6

#define NSLeftMouseDown				1
#define NSLeftMouseUp				2
#define NSRightMouseDown			3
#define NSRightMouseUp				4
#define NSMouseMoved				5
#define NSLeftMouseDragged			6
#define NSRightMouseDragged			7
#define NSMouseEntered				8
#define NSMouseExited				9
#define NSKeyDown					10
#define NSKeyUp						11
#define NSFlagsChanged				12
#define NSAppKitDefined				13
#define NSSystemDefined				14
#define NSApplicationDefined		15
#define NSPeriodic					16
#define NSCursorUpdate				17
#define NSScrollWheel				22
#define NSTabletPoint				23
#define NSTabletProximity			24
#define NSOtherMouseDown			25
#define NSOtherMouseUp				26
#define NSOtherMouseDragged			27
#define NSEventTypeGesture			29
#define NSEventTypeMagnify			30
#define NSEventTypeSwipe			31
#define NSEventTypeRotate			18
#define NSEventTypeBeginGesture		19
#define NSEventTypeEndGesture		20
#define NSEventTypeSmartMagnify		32
#define NSEventTypeQuickLook		33
#define NSEventTypePressure			34

#define kCGLineJoinMiter			0
#define kCGLineJoinRound			1
#define kCGLineJoinBevel			2

#define kCGLineCapButt				0
#define kCGLineCapRound				1
#define kCGLineCapSquare			2

#define kCGPathFill					0
#define kCGPathEOFill				1
#define kCGPathStroke				2
#define kCGPathFillStroke			3
#define kCGPathEOFillStroke			4

#define NSASCIIStringEncoding		1
#define NSUTF8StringEncoding		4
#define NSISOLatin1StringEncoding	5
#define NSWindowsCP1251StringEncoding	11
#define NSWindowsCP1252StringEncoding	12
#define NSWindowsCP1250StringEncoding	15
#define NSUTF16LittleEndianStringEncoding	94000100h

#define IVAR_RED_FACE	"red-face"
#define kCFStringEncodingUTF8	08000100h
#define CFString(cStr)	[CFStringCreateWithCString 0 cStr kCFStringEncodingUTF8]

#define handle! [pointer! [integer!]]

objc_super!: alias struct! [
	receiver	[integer!]
	superclass	[integer!]
]

NSRect!: alias struct! [
	x		[float32!]
	y		[float32!]
	w		[float32!]
	h		[float32!]
]

NSSize!: alias struct! [
	width	[float32!]
	height	[float32!]
]

CGPoint!: alias struct! [
	x		[float32!]
	y		[float32!]
]

RECT_STRUCT: alias struct! [
	left		[integer!]
	top			[integer!]
	right		[integer!]
	bottom		[integer!]
]

tagPOINT: alias struct! [
	x		[integer!]
	y		[integer!]	
]

tagSIZE: alias struct! [
	width	[integer!]
	height	[integer!]
]

#import [
	LIBC-file cdecl [
		fabs: "fabs" [
			x			[float!]
			return:		[float!]
		]
		objc_getClass: "objc_getClass" [
			class		[c-string!]
			return:		[integer!]
		]
		objc_allocateClassPair: "objc_allocateClassPair" [
			superclass	[integer!]
			name		[c-string!]
			extraBytes	[integer!]
			return:		[integer!]
		]
		objc_registerClassPair: "objc_registerClassPair" [
			class		[integer!]
			return:		[integer!]
		]
		sel_getUid: "sel_getUid" [
			name		[c-string!]
			return:		[integer!]
		]
		ivar_getOffset: "ivar_getOffset" [
			ivar		[integer!]
			return:		[integer!]
		]
		class_getInstanceVariable: "class_getInstanceVariable" [
			class		[integer!]
			name		[c-string!]
			return:		[integer!]
		]
		class_addIvar: "class_addIvar" [
			class		[integer!]
			name		[c-string!]
			size		[integer!]
			alignment	[integer!]
			types		[c-string!]
			return:		[logic!]
		]
		class_addMethod: "class_addMethod" [
			class		[integer!]
			name		[integer!]
			implement	[integer!]
			types		[c-string!]
			return:		[integer!]
		]
		class_getSuperclass: "class_getSuperclass" [
			cls			[integer!]
			return:		[integer!]
		]
		object_getClass: "object_getClass" [
			id			[integer!]
			return:		[integer!]
		]
		objc_msgSend: "objc_msgSend" [[variadic] return: [integer!]]
		objc_msgSendSuper: "objc_msgSendSuper" [[variadic] return: [integer!]]
		objc_msgSend_fpret: "objc_msgSend_fpret" [[variadic] return: [float!]]
		objc_msgSend_stret: "objc_msgSend_stret" [obj [integer!] sel [integer!]]
	]
	"/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation" cdecl [
		CFStringCreateWithCString: "CFStringCreateWithCString" [
			allocator	[integer!]
			cStr		[c-string!]
			encoding	[integer!]
			return:		[integer!]
		]
		CFRelease: "CFRelease" [
			cf			[integer!]
		]
	]
	"/System/Library/Frameworks/Foundation.framework/Versions/Current/Foundation" cdecl [
		NSStringFromClass: "NSStringFromClass" [
			class		[integer!]
			return:		[integer!]
		]
	]
	"/System/Library/Frameworks/CoreServices.framework/CoreServices" cdecl [
		Gestalt: "Gestalt" [
			selector	[integer!]
			response	[int-ptr!]
			return:		[integer!]
		]
	]
	"/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices" cdecl [
		CGContextSetRGBStrokeColor: "CGContextSetRGBStrokeColor" [
			c			[handle!]
			red			[float32!]
			green		[float32!]
			blue		[float32!]
			alpha		[float32!]
		]
		CGContextSetRGBFillColor: "CGContextSetRGBFillColor" [
			c			[handle!]
			red			[float32!]
			green		[float32!]
			blue		[float32!]
			alpha		[float32!]
		]
		CGContextStrokeRect: "CGContextStrokeRect" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
			width		[float32!]
			height		[float32!]
		]
		CGContextFillRect: "CGContextFillRect" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
			width		[float32!]
			height		[float32!]
		]
		CGContextFillEllipseInRect: "CGContextFillEllipseInRect" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
			width		[float32!]
			height		[float32!]
		]
		CGContextStrokeEllipseInRect: "CGContextStrokeEllipseInRect" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
			width		[float32!]
			height		[float32!]
		]
		CGContextSetLineWidth: "CGContextSetLineWidth" [
			c			[handle!]
			width		[float32!]
		]
		CGContextSetLineJoin: "CGContextSetLineJoin" [
			c			[handle!]
			join		[integer!]
		]
		CGContextSetLineCap: "CGContextSetLineCap" [
			c			[handle!]
			cap			[integer!]
		]
		CGContextSetAllowsAntialiasing: "CGContextSetAllowsAntialiasing" [
			c			[handle!]
			anti-alias? [logic!]
		]
		CGContextSetAllowsFontSmoothing: "CGContextSetAllowsFontSmoothing" [
			c			[handle!]
			smooth?		[logic!]
		]
		CGContextSetMiterLimit: "CGContextSetMiterLimit" [
			c			[handle!]
			limit		[float32!]
		]
		CGContextBeginPath: "CGContextBeginPath" [
			c			[handle!]
		]
		CGContextClosePath: "CGContextClosePath" [
			c			[handle!]
		]
		CGContextMoveToPoint: "CGContextMoveToPoint" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
		]
		CGContextAddLineToPoint: "CGContextAddLineToPoint" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
		]
		CGContextAddCurveToPoint: "CGContextAddCurveToPoint" [
			c			[handle!]
			cp1x		[float32!]
			cp1y		[float32!]
			cp2x		[float32!]
			cp2y		[float32!]
			x			[float32!]
			y			[float32!]
		]
		CGContextAddQuadCurveToPoint: "CGContextAddQuadCurveToPoint" [
			c			[handle!]
			cp1x		[float32!]
			cp1y		[float32!]
			x			[float32!]
			y			[float32!]
		]
		CGContextAddLines: "CGContextAddLines" [
			c			[handle!]
			points		[CGPoint!]
			count		[integer!]
		]
		CGContextAddArc: "CGContextAddArc" [
			c			[handle!]
			x			[float32!]
			y			[float32!]
			radius		[float32!]
			startAngle	[float32!]
			endAngle	[float32!]
			clockwise	[integer!]
		]
		CGContextStrokePath: "CGContextStrokePath" [
			c			[handle!]
		]
		CGContextDrawPath: "CGContextDrawPath" [
			c			[handle!]
			mode		[integer!]
		]
		CGContextRotateCTM: "CGContextRotateCTM" [
			c			[handle!]
			angle		[float32!]
		]
		CGContextScaleCTM: "CGContextScaleCTM" [
			c			[handle!]
			sx			[float32!]
			sy			[float32!]
		]
		CGContextTranslateCTM: "CGContextTranslateCTM" [
			c			[handle!]
			tx			[float32!]
			ty			[float32!]
		]
		CGContextDrawImage: "CGContextDrawImage" [
			ctx			[handle!]
			x			[float32!]
			y			[float32!]
			w			[float32!]
			h			[float32!]
			src			[integer!]
		]
		CGBitmapContextCreateImage: "CGBitmapContextCreateImage" [
			ctx			[integer!]
			return:		[integer!]
		]
		CGImageRelease: "CGImageRelease" [
			image		[integer!]
		]
	]
]

get-super-obj: func [
	id		[integer!]
	return: [objc_super!]
	/local
		super [objc_super!]
][
	super: declare objc_super!
	super/receiver: id
	super/superclass: objc_msgSend [id sel_getUid "superclass"]
	super
]

msg-send-super: func [
	id		[integer!]
	sel		[integer!]
	arg		[integer!]
	/local
		super [objc_super!]
][
	super: declare objc_super!
	super/receiver: id
	super/superclass: objc_msgSend [id sel_getUid "superclass"]
	objc_msgSendSuper [super sel arg]
]