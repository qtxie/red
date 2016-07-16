Red/System [
	Title:	"Windows platform COM imports"
	Author: "Qingtian Xie"
	File: 	%COM.red
	Tabs: 	4
	Rights: "Copyright (C) 2015 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define COM_SAFE_RELEASE(interface this) [
	if this <> null [
		interface: as IUnknown this/vtbl
		interface/Release this
		this: null
	]
]

#define COM_THIS(interface)		[interface/ptr]
#define COM_VPTR(this)			[this/vtbl]

#define COM_SUCCEEDED(hr)		[hr >= 0]
#define COM_FAILED(hr)			[hr < 0]

#define COINIT_APARTMENTTHREADED	2

#define CLSCTX_INPROC_SERVER 	1
#define CLSCTX_INPROC_HANDLER	2
#define CLSCTX_INPROC           3						;-- CLSCTX_INPROC_SERVER or CLSCTX_INPROC_HANDLER

CLSID_SystemDeviceEnum:			[62BE5D10h 11D060EBh A0003BBDh 86CE11C9h]
IID_IStream:					[0000000Ch 00000000h 0000000Ch 46000000h]
IID_ICreateDevEnum:				[29840822h 11D05B84h A0003BBDh 86CE11C9h]
IID_IPropertyBag: 				[55272A00h 11CE42CBh AA003581h 51B84B00h]
IID_IWinHttpRequest:			[06F29373h 4B545C5Ah F16E25B0h 0EBF8ABFh]

#define VT_EMPTY		0
#define VT_NULL			1
#define VT_BSTR			8
#define VT_ERROR		10
#define VT_BOOL			11
#define VT_UI1			17
#define VT_ARRAY		2000h

#define STGM_READWRITE			00000002h
#define STGM_SHARE_EXCLUSIVE	00000010h
#define STGM_CREATE				00001000h
#define STGM_DELETEONRELEASE	04000000h

tagVARIANT: alias struct! [
	data1		[integer!]
	data2		[integer!]
	data3		[integer!]
	data4		[integer!]
]

tagGUID: alias struct! [
	data1		[integer!]
	data2		[integer!]
	data3		[integer!]
	data4		[integer!]
]

tagSTATSTG: alias struct! [
	pwcsName		[integer!]
	type			[integer!]
	cbSize_low		[integer!]
	cbSize_high		[integer!]
	mtime_low		[integer!]
	mtime_high		[integer!]
	ctime_low		[integer!]
	ctime_high		[integer!]
	atime_low		[integer!]
	atime_high		[integer!]
	grfMode			[integer!]
	grfLocks		[integer!]
	clsid_1			[integer!]
	clsid_2			[integer!]
	clsid_3			[integer!]
	clsid_4			[integer!]
	grfStateBits	[integer!]
	reserved		[integer!]
]

this!: alias struct! [vtbl [integer!]]

interface!: alias struct! [
	ptr [this!]
]

QueryInterface!: alias function! [
	this		[this!]
	riid		[int-ptr!]
	ppvObject	[interface!]
	return:		[integer!]
]

AddRef!: alias function! [
	this		[this!]
	return:		[integer!]
]

Release!: alias function! [
	this		[this!]
	return:		[integer!]
]

CreateClassEnumerator!: alias function! [
	this		[this!]
	clsid		[int-ptr!]
	ppMoniker	[interface!]
	flags		[integer!]
	return:		[integer!]
]

Next!: alias function! [
	this		[this!]
	celt		[integer!]
	reglt		[interface!]
	celtFetched [int-ptr!]
	return:		[integer!]
]

BindToStorage!: alias function! [
	this		[this!]
	pbc			[integer!]
	pmkToLeft	[integer!]
	riid		[int-ptr!]
	ppvObj		[interface!]
	return:		[integer!]
]

Read!: alias function! [
	this		[this!]
	name		[c-string!]
	pVar		[tagVARIANT]
	errorlog	[integer!]
	return:		[integer!]
]

RenderStream!: alias function! [
	this		[this!]
	pCategory	[int-ptr!]
	pType		[int-ptr!]
	pSource		[this!]
	pfCompressor [this!]
	pfRenderer	[this!]
	return:		[integer!]
]

CreateStream!: alias function! [
	this		[this!]
	pwcsName	[c-string!]
	mode		[integer!]
	reserved1	[integer!]
	reserved2	[integer!]
	ppstm		[interface!]
	return: [integer!]
]

IUnknown: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
]

IStorage: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	CreateStream			[CreateStream!]
	OpenStream				[integer!]
	CreateStorage			[integer!]
	OpenStorage				[integer!]
	CopyTo					[integer!]
	MoveElementTo			[integer!]
	Commit					[integer!]
	Revert					[integer!]
	EnumElements			[integer!]
	DestroyElement			[integer!]
	RenameElement			[integer!]
	SetElementTimes			[integer!]
	SetClass				[integer!]
	SetStateBits			[integer!]
	Stat					[integer!]
]

IStream: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	Read					[function! [this [this!] buf [byte-ptr!] cb [integer!] cbRead [int-ptr!] return: [integer!]]]
	Write					[integer!]
	Seek					[function! [this [this!] move_low [integer!] move_high [integer!] origin [integer!] pos_low [integer!] pos_high [integer!] return: [integer!]]]
	SetSize					[integer!]
	CopyTo					[integer!]
	Commit					[integer!]
	Revert					[integer!]
	LockRegion				[integer!]
	UnlockRegion			[integer!]
	Stat					[function! [this [this!] pstat [tagSTATSTG] flag [integer!] return: [integer!]]]
	Clone					[integer!]
]

ICreateDevEnum: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	CreateClassEnumerator	[CreateClassEnumerator!]
]

IEnumMoniker: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	Next					[Next!]
	Skip					[integer!]
	Reset					[Release!]
	Clone					[integer!]
]

IMoniker: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	GetClassID				[integer!]
	IsDirty					[integer!]
	Load					[integer!]
	Save					[integer!]
	GetSizeMax				[integer!]
	BindToObject			[BindToStorage!]
	BindToStorage			[BindToStorage!]
	;... other funcs we don't use
]

IPropertyBag: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	Read					[Read!]
	Write					[integer!]
]

IWinHttpRequest: alias struct! [
	QueryInterface			[QueryInterface!]
	AddRef					[AddRef!]
	Release					[Release!]
	GetTypeInfoCount		[integer!]
	GetTypeInfo				[integer!]
	GetIDsOfNames			[integer!]
	Invoke					[integer!]
	SetProxy				[integer!]
	SetCredentials			[integer!]
	Open					[function! [this [this!] method [byte-ptr!] url [byte-ptr!] async1 [integer!] async2 [integer!] async3 [integer!] async4 [integer!] return: [integer!]]]
	SetRequestHeader		[function! [this [this!] header [byte-ptr!] value [byte-ptr!] return: [integer!]]]
	GetResponseHeader		[function! [this [this!] header [byte-ptr!] value [int-ptr!] return: [integer!]]]
	GetAllResponseHeaders	[function! [this [this!] header [int-ptr!] return: [integer!]]]
	Send					[function! [this [this!] body1 [integer!] body2 [integer!] body3 [integer!] body4 [integer!] return: [integer!]]]
	Status					[function! [this [this!] status [int-ptr!] return: [integer!]]]
	StatusText				[integer!]
	ResponseText			[function! [this [this!] body [int-ptr!] return: [integer!]]]
	ResponseBody			[function! [this [this!] body [tagVARIANT] return: [integer!]]]
	ResponseStream			[integer!]
	GetOption				[integer!]
	PutOption				[integer!]
	WaitForResponse			[integer!]
	Abort					[integer!]
	SetTimeouts				[integer!]
	SetClientCertificate	[integer!]
	SetAutoLogonPolicy		[integer!]
]

#import [
	"ole32.dll" stdcall [
		CoInitializeEx: "CoInitializeEx" [
			reserved	[integer!]
			dwCoInit	[integer!]
			return:		[integer!]
		]
		CoUninitialize: "CoUninitialize" []
		CoCreateInstance: "CoCreateInstance" [
			rclsid		 [int-ptr!]
			pUnkOuter	 [integer!]
			dwClsContext [integer!]
			riid		 [int-ptr!]
			ppv			 [interface!]
			return:		 [integer!]
		]
		CLSIDFromProgID: "CLSIDFromProgID" [
			lpszProgID	[c-string!]
			lpclsid		[tagGUID]
			return:		[integer!]
		]
		StgCreateDocfile: "StgCreateDocfile" [
			pwcsName	[c-string!]
			grfMode		[integer!]
			reserved	[integer!]
			ppstgOpen	[interface!]
			return:		[integer!]
		]
	]
	"oleaut32.dll" stdcall [
		SysAllocString: "SysAllocString" [
			psz		[c-string!]
			return:	[byte-ptr!]
		]
		SysFreeString: "SysFreeString" [
			bstr	[byte-ptr!]
		]
		VariantInit: "VariantInit" [
			pvarg	[tagVARIANT]
		]
		SafeArrayGetDim: "SafeArrayGetDim" [
			psa		[integer!]
			return: [integer!]
		]
		SafeArrayGetLBound: "SafeArrayGetLBound" [
			psa		[integer!]
			nDim	[integer!]
			bound	[int-ptr!]
			return: [integer!]
		]
		SafeArrayGetUBound: "SafeArrayGetUBound" [
			psa		[integer!]
			nDim	[integer!]
			bound	[int-ptr!]
			return: [integer!]
		]
		SafeArrayAccessData: "SafeArrayAccessData" [
			psa		[integer!]
			ppvData [int-ptr!]
			return: [integer!]
		]
		SafeArrayUnaccessData: "SafeArrayUnaccessData" [
			psa		[integer!]
			return: [integer!]
		]
		SafeArrayDestroy: "SafeArrayDestroy" [
			psa		[integer!]
			return:	[integer!]
		]
	]
]