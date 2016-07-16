Red/System [
	Title:	"Direct X structures and functions imports"
	Author: "Xie Qingtian"
	File: 	%direct-x.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define float32-ptr! [pointer! [float32!]]

IID_IDWriteFactory:					[B859EE5Ah 4B5BD838h DC1AE8A2h 48DB937Dh]

D2D1_RENDER_TARGET_PROPERTIES: alias struct! [
	type		[integer!]
	format		[integer!]
	alphaMode	[integer!]
	dpiX		[float32!]
	dpiY		[float32!]
	usage		[integer!]
	minLevel	[integer!]
]

ID2D1Factory: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	ReloadSystemMetrics				[Release!]
	GetDesktopDpi					[function! [this [this!] dpiX [float32-ptr!] dpiY [float32-ptr!]]]
	CreateRectangleGeometry			[integer!]
	CreateRoundedRectangleGeometry	[integer!]
	CreateEllipseGeometry			[integer!]
	CreateGeometryGroup				[integer!]
	CreateTransformedGeometry		[integer!]
	CreatePathGeometry				[integer!]
	CreateStrokeStyle				[integer!]
	CreateDrawingStateBlock			[integer!]
	CreateWicBitmapRenderTarget		[integer!]
	CreateHwndRenderTarget			[integer!]
	CreateDxgiSurfaceRenderTarget	[integer!]
	CreateDCRenderTarget			[function! [this [this!] properties [integer!] target [interface!] return: [integer!]]]
]

ID2D1DCRenderTarget: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetFactory						[integer!]
	CreateBitmap					[integer!]
	CreateBitmapFromWicBitmap		[integer!]
	CreateSharedBitmap				[integer!]
	CreateBitmapBrush				[integer!]
	CreateSolidColorBrush			[integer!]
	CreateGradientStopCollection	[integer!]
	CreateLinearGradientBrush		[integer!]
	CreateRadialGradientBrush		[integer!]
	CreateCompatibleRenderTarget	[integer!]
	CreateLayer						[integer!]
	CreateMesh						[integer!]
	DrawLine						[integer!]
	DrawRectangle					[integer!]
	FillRectangle					[integer!]
	DrawRoundedRectangle			[integer!]
	FillRoundedRectangle			[integer!]
	DrawEllipse						[integer!]
	FillEllipse						[integer!]
	DrawGeometry					[integer!]
	FillGeometry					[integer!]
	FillMesh						[integer!]
	FillOpacityMask					[integer!]
	DrawBitmap						[integer!]
	DrawText						[integer!]
	DrawTextLayout					[integer!]
	DrawGlyphRun					[integer!]
	SetTransform					[integer!]
	GetTransform					[integer!]
	SetAntialiasMode				[integer!]
	GetAntialiasMode				[integer!]
	SetTextAntialiasMode			[integer!]
	GetTextAntialiasMode			[integer!]
	SetTextRenderingParams			[integer!]
	GetTextRenderingParams			[integer!]
	SetTags							[integer!]
	GetTags							[integer!]
	PushLayer						[integer!]
	PopLayer						[integer!]
	Flush							[integer!]
	RestoreDrawingState				[integer!]
	PushAxisAlignedClip				[integer!]
	SaveDrawingState				[integer!]
	PopAxisAlignedClip				[integer!]
	Clear							[integer!]
	BeginDraw						[integer!]
	EndDraw							[integer!]
	GetPixelFormat					[integer!]
	SetDpi							[integer!]
	GetDpi							[integer!]
	GetSize							[integer!]
	GetPixelSize					[integer!]
	GetMaximumBitmapSize			[integer!]
	IsSupported						[integer!]
	BindDC							[function! [this [this!] hDC [integer!] rect [RECT_STRUCT] return: [integer!]]]
]

"d2d1.dll" stdcall [
	D2D1CreateFactory: "D2D1CreateFactory" [
		type		[integer!]
		factory		[interface!]
		return:		[integer!]
	]
]

"DWrite.dll" stdcall [
	DWriteCreateFactory: "D2D1CreateFactory" [
		type		[integer!]
		iid			[int-ptr!]
		factory		[interface!]
		return:		[integer!]
	]
]