Red/System [
	Title:	"Windows platform GUI imports"
	Author: "Nenad Rakocevic"
	File: 	%win32.red
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#if dev-mode? = yes [
	#include %../../../../../runtime/platform/COM.reds
]

#define GWL_HWNDPARENT		-8
#define GWL_STYLE			-16
#define GWL_EXSTYLE			-20
#define GWLP_USERDATA		-21

#define GW_OWNER			4

#define HORZRES				8
#define VERTRES				10

#define SW_HIDE				0
#define SW_SHOW				5
#define SW_SHOWNA			8
#define SW_SHOWDEFAULT		10

#define MIIM_STATE			0001h
#define MIIM_ID				0002h
#define MIIM_SUBMENU		0004h
#define MIIM_CHECKMARKS		0008h
#define MIIM_TYPE			0010h
#define MIIM_DATA			0020h
#define MIIM_STRING			0040h
#define MIIM_BITMAP			0080h
#define MIIM_FTYPE			0100h

#define MFT_STRING			00000000h
#define MFT_BITMAP			00000004h
#define MFT_MENUBARBREAK	00000020h
#define MFT_MENUBREAK		00000040h
;#define MFT_OWNERDRAW		MF_OWNERDRAW
#define MFT_RADIOCHECK		00000200h
#define MFT_SEPARATOR		00000800h
#define MFT_RIGHTORDER		00002000h
#define MFT_RIGHTJUSTIFY	00004000h

#define MNS_NOCHECK			80000000h
#define MNS_MODELESS		40000000h
#define MNS_DRAGDROP		20000000h
#define MNS_AUTODISMISS		10000000h
#define MNS_NOTIFYBYPOS		08000000h
#define MNS_CHECKORBMP		04000000h

#define IDC_ARROW			7F00h
#define IDC_IBEAM			7F01h

#define CW_USEDEFAULT		80000000h

#define WS_OVERLAPPEDWINDOW	00CF0000h
#define WS_CLIPCHILDREN		02000000h
#define WS_EX_ACCEPTFILES	00000010h
#define WS_CHILD			40000000h
#define WS_VISIBLE			10000000h
#define WS_EX_COMPOSITED	02000000h
#define WS_HSCROLL			00100000h
#define WS_VSCROLL			00200000h
#define WS_EX_LAYERED 		00080000h
#define WS_TABSTOP			00010000h
#define WS_EX_TRANSPARENT	00000020h
#define WS_EX_CLIENTEDGE	00000200h
#define WS_MAXIMIZEBOX		00010000h
#define WS_MINIMIZEBOX		00020000h
#define WS_GROUP			00020000h
#define WS_THICKFRAME		00040000h
#define WS_SYSMENU			00080000h
#define WS_BORDER			00800000h
#define WS_DLGFRAME			00400000h
#define WS_CAPTION			00C00000h
#define WS_MAXIMIZE			01000000h
#define WS_CLIPSIBLINGS 	04000000h
#define WS_MINIMIZE			20000000h
#define WS_POPUP		 	80000000h
#define WS_EX_TOOLWINDOW	00000080h
#define WS_DISABLED         08000000h
#define WS_EX_NOREDIRECTIONBITMAP 00200000h

#define SIZE_MINIMIZED		1
#define SIZE_MAXIMIZED		2

#define WM_CREATE			0001h
#define WM_NCCREATE			0081h
#define WM_NCDESTROY		0082h
#define WM_NCHITTEST		0084h
#define WM_DESTROY			0002h
#define WM_MOVE				0003h
#define WM_SIZE				0005h
#define WM_ACTIVATE			0006h
#define WM_SETFOCUS			0007h
#define WM_KILLFOCUS		0008h
#define WM_CLOSE			0010h
#define WM_SETTEXT			000Ch
#define WM_GETTEXT			000Dh
#define WM_GETTEXTLENGTH	000Eh
#define WM_PAINT			000Fh
#define WM_ERASEBKGND		0014h
#define WM_CTLCOLOR			0019h
#define WM_SETCURSOR		0020h
#define WM_MOUSEACTIVATE	0021h
#define WM_GETMINMAXINFO	0024h
#define WM_SETFONT			0030h
#define WM_GETFONT			0031h
#define WM_GETOBJECT		003Dh
#define WM_WINDOWPOSCHANGED 0047h
#define WM_NOTIFY			004Eh
#define WM_CONTEXTMENU		007Bh
#define WM_NCACTIVATE		0086h
#define WM_DISPLAYCHANGE	007Eh
#define WM_KEYDOWN			0100h
#define WM_KEYUP			0101h
#define WM_CHAR				0102h
#define WM_DEADCHAR 		0103h
#define WM_SYSKEYDOWN		0104h
#define WM_SYSKEYUP			0105h
#define WM_SYSCHAR			0106h
#define WM_UNICHAR			0109h
#define WM_COMMAND 			0111h
#define WM_SYSCOMMAND		0112h
#define WM_TIMER			0113h
#define WM_HSCROLL			0114h
#define WM_VSCROLL			0115h
#define WM_INITMENU			0116h
#define WM_GESTURE			0119h
#define WM_MENUSELECT		011Fh
#define WM_MENUCOMMAND		0126h
#define WM_CTLCOLOREDIT		0133h
#define WM_CTLCOLORLISTBOX	0134h
#define WM_CTLCOLORBTN		0135h
#define WM_CTLCOLORDLG		0136h
#define WM_CTLCOLORSCROLLBAR 0137h
#define WM_CTLCOLORSTATIC	0138h
#define	WM_MOUSEMOVE		0200h
#define WM_LBUTTONDOWN		0201h
#define WM_LBUTTONUP		0202h
#define WM_LBUTTONDBLCLK	0203h
#define WM_RBUTTONDOWN		0204h
#define WM_RBUTTONUP		0205h
#define WM_MBUTTONDOWN		0207h
#define WM_MBUTTONUP		0208h
#define	WM_MOUSEWHELL		020Ah
#define WM_ENTERMENULOOP	0211h
#define WM_SIZING			0214h
#define WM_MOVING			0216h
#define WM_ENTERSIZEMOVE	0231h
#define WM_EXITSIZEMOVE		0232h
#define WM_IME_SETCONTEXT	0281h
#define WM_IME_NOTIFY		0282h
#define WM_MOUSEHOVER		02A1h
#define WM_MOUSELEAVE		02A3h
#define WM_DPICHANGED		02E0h
#define WM_COPY				0301h
#define WM_PASTE			0302h
#define WM_CLEAR			0303h
#define WM_THEMECHANGED		031Ah

#define BM_GETCHECK			F0h
#define BM_SETCHECK			F1h
#define BM_SETSTYLE			F4h
#define BM_SETIMAGE			F7h

#define BN_CLICKED 			0
#define BN_UNPUSHED         3

#define BST_UNCHECKED		0
#define BST_CHECKED			1
#define BST_INDETERMINATE	2

#define VK_SHIFT			10h
#define VK_CONTROL			11h
#define VK_MENU				12h
#define VK_PAUSE			13h
#define VK_CAPITAL			14h

#define VK_ESCAPE			1Bh

#define VK_SPACE			20h
#define VK_PRIOR			21h
#define VK_NEXT				22h
#define VK_END				23h
#define VK_HOME				24h
#define VK_LEFT				25h
#define VK_UP				26h
#define VK_RIGHT			27h
#define VK_DOWN				28h
#define VK_SELECT			29h
#define VK_PRINT			2Ah
#define VK_EXECUTE			2Bh
#define VK_SNAPSHOT			2Ch
#define VK_INSERT			2Dh
#define VK_DELETE			2Eh
#define VK_HELP				2Fh
#define VK_LWIN				5Bh
#define VK_RWIN				5Ch
#define VK_APPS				5Dh
#define VK_F1				70h
#define VK_F2				71h
#define VK_F3				72h
#define VK_F4				73h
#define VK_F5				74h
#define VK_F6				75h
#define VK_F7				76h
#define VK_F8				77h
#define VK_F9				78h
#define VK_F10				79h
#define VK_F11				7Ah
#define VK_F12				7Bh
#define VK_F13				7Ch
#define VK_F14				7Dh
#define VK_F15				7Eh
#define VK_F16				7Fh
#define VK_F17				80h
#define VK_F18				81h
#define VK_F19				82h
#define VK_F20				83h
#define VK_F21				84h
#define VK_F22				85h
#define VK_F23				86h
#define VK_F24				87h

#define VK_NUMLOCK			90h
#define VK_SCROLL			91h

#define VK_LSHIFT			A0h
#define VK_RSHIFT			A1h
#define VK_LCONTROL			A2h
#define VK_RCONTROL			A3h
#define VK_LMENU			A4h
#define VK_RMENU			A5h
#define VK_PROCESSKEY		E5h

#define DEFAULT_GUI_FONT 	17

#define VER_NT_WORKSTATION			1
#define VER_NT_DOMAIN_CONTROLLER	2
#define VER_NT_SERVER				3

#define SWP_NOSIZE			0001h
#define SWP_NOMOVE			0002h
#define SWP_NOZORDER		0004h
#define SWP_NOACTIVATE		0010h
#define SWP_SHOWWINDOW		0040h
#define SWP_HIDEWINDOW		0080h

#define BS_SOLID			0
#define BS_BITMAP			80h

#define AC_SRC_OVER			0
#define AC_SRC_ALPHA		0			;-- there are some troubles on Win64 with value 1

#define SRCCOPY				00CC0020h

#define WIN32_LOWORD(param) (param and FFFFh << 16 >> 16)	;-- trick to force sign extension
#define WIN32_HIWORD(param) (param >> 16)

#define WIN32_MAKE_LPARAM(low high) [high << 16 or (low and FFFFh)]

#define IS_EXTENDED_KEY		01000000h

tagCREATESTRUCT: alias struct! [
	lpCreateParams	[int-ptr!]
	hInstance		[int-ptr!]
	hMenu			[int-ptr!]
	hwndParent		[int-ptr!]
	cy				[integer!]
	cx				[integer!]
	y				[integer!]
	x				[integer!]
	style			[integer!]
	lpszName		[c-string!]
	lpszClass		[c-string!]
	dwExStyle		[c-string!]
]

tagWINDOWPOS: alias struct! [
	hWnd			[handle!]
	hwndInsertAfter	[handle!]
	x				[integer!]
	y				[integer!]
	cx				[integer!]
	cy				[integer!]
	flags			[integer!]
]

tagSIZE: alias struct! [
	width	[integer!]
	height	[integer!]
]

tagMSG: alias struct! [
	hWnd	[handle!]
	msg		[integer!]
	wParam	[integer!]
	lParam	[integer!]
	time	[integer!]
	x		[integer!]									;@@ POINT struct
	y		[integer!]	
]

tagTRACKMOUSEEVENT: alias struct! [
	cbSize		[integer!]
	dwFlags		[integer!]
	hwndTrack	[handle!]
	dwHoverTime	[integer!]
]

wndproc-cb!: alias function! [
	[stdcall]
	hWnd	[handle!]
	msg		[integer!]
	wParam	[integer!]
	lParam	[integer!]
	return: [integer!]
]

timer-cb!: alias function! [
	[stdcall]
	hWnd	[handle!]
	msg		[integer!]
	idEvent	[int-ptr!]
	dwTime	[integer!]
]

WNDCLASSEX: alias struct! [
	cbSize		  [integer!]
	style		  [integer!]
	lpfnWndProc	  [wndproc-cb!]
	cbClsExtra    [integer!]
	cbWndExtra    [integer!]
	hInstance	  [handle!]
	hIcon	  	  [handle!]
	hCursor		  [handle!]
	hbrBackground [integer!]
	lpszMenuName  [c-string!]
	lpszClassName [c-string!]
	hIconSm	  	  [integer!]
]

GESTUREINFO: alias struct! [
	cbSize		 [integer!]
	dwFlags		 [integer!]
	dwID		 [integer!]
	hwndTarget	 [handle!]
	ptsLocation	 [integer!]
	dwInstanceID [integer!]
	dwSequenceID [integer!]
	pad1		 [integer!]
	ullArgumentH [integer!]
	ullArgumentL [integer!]
	cbExtraArgs	 [integer!]
	pad2		 [integer!]
]

GESTURECONFIG: alias struct! [
	dwID		[integer!]
	dwWant		[integer!]
	dwBlock		[integer!]
]

DISPLAY_DEVICE: alias struct! [
	cbSize		[integer!]
	DevName		[byte!]
]

tagINITCOMMONCONTROLSEX: alias struct! [
	dwSize		[integer!]
	dwICC		[integer!]
]

MENUITEMINFO: alias struct! [
	cbSize		[integer!]
	fMask		[integer!]
	fType		[integer!]
	fState		[integer!]
	wID			[integer!]
	hSubMenu	[handle!]
	hbmpChecked	[handle!]
	hbmpUnchecked [handle!]
	dwItemData	[integer!]
	dwTypeData	[c-string!]
	cch			[integer!]
	hbmpItem	[handle!]
]

RECT_STRUCT: alias struct! [
	left		[integer!]
	top			[integer!]
	right		[integer!]
	bottom		[integer!]
]

RECT_STRUCT_FLOAT32: alias struct! [
	x			[float32!]
	y			[float32!]
	width		[float32!]
	height		[float32!]
]

tagCOMPOSITIONFORM: alias struct! [
	dwStyle		[integer!]
	x			[integer!]
	y			[integer!]
	left		[integer!]
	top			[integer!]
	right		[integer!]
	bottom		[integer!]
]

tagLOGFONT: alias struct! [								;-- 92 bytes
	lfHeight		[integer!]
	lfWidth			[integer!]
	lfEscapement	[integer!]
	lfOrientation	[integer!]
	lfWeight		[integer!]
	lfItalic		[byte!]
	lfUnderline		[byte!]
	lfStrikeOut		[byte!]
	lfCharSet		[byte!]
	lfOutPrecision	[byte!]
	lfClipPrecision	[byte!]
	lfQuality		[byte!]
	lfPitchAndFamily[byte!]
	lfFaceName		[float!]							;@@ 64 bytes offset: 28
	lfFaceName2		[float!]
	lfFaceName3		[float!]
	lfFaceName4		[float!]
	lfFaceName5		[float!]
	lfFaceName6		[float!]
	lfFaceName7		[float!]
	lfFaceName8		[float!]
]

tagNONCLIENTMETRICS: alias struct! [
	cbSize				[integer!]
	iBorderWidth		[integer!]
	iScrollWidth		[integer!]
	iScrollHeight		[integer!]
	iCaptionWidth		[integer!]
	iCaptionHeight		[integer!]
	lfCaptionFont		[tagLOGFONT value]
	iSmCaptionWidth		[integer!]
	iSmCaptionHeight	[integer!]
	lfSmCaptionFont		[tagLOGFONT value]
	iMenuWidth			[integer!]
	iMenuHeight			[integer!]
	lfMenuFont			[tagLOGFONT value]
	lfStatusFont		[tagLOGFONT value]
	lfMessageFont		[tagLOGFONT value]
	iPaddedBorderWidth	[integer!]
]

tagCHOOSEFONT: alias struct! [
	lStructSize		[integer!]
	hwndOwner		[int-ptr!]
	hDC				[integer!]
	lpLogFont		[tagLOGFONT]
	iPointSize		[integer!]
	Flags			[integer!]
	rgbColors		[integer!]
	lCustData		[integer!]
	lpfnHook		[integer!]
	lpTemplateName	[c-string!]
	hInstance		[integer!]
	lpszStyle		[c-string!]
	nFontType		[integer!]							;-- WORD
	nSizeMin		[integer!]
	nSizeMax		[integer!]
]

tagOFNW: alias struct! [
	lStructSize			[integer!]
	hwndOwner			[handle!]
	hInstance			[integer!]
	lpstrFilter			[c-string!]
	lpstrCustomFilter	[c-string!]
	nMaxCustFilter		[integer!]
	nFilterIndex		[integer!]
	lpstrFile			[byte-ptr!]
	nMaxFile			[integer!]
	lpstrFileTitle		[c-string!]
	nMaxFileTitle		[integer!]
	lpstrInitialDir		[c-string!]
	lpstrTitle			[c-string!]
	Flags				[integer!]
	nFileOffset			[integer!]
	;nFileExtension		[integer!]
	lpstrDefExt			[c-string!]
	lCustData			[integer!]
	lpfnHook			[integer!]
	lpTemplateName		[integer!]
	;-- if (_WIN32_WINNT >= 0x0500)
	pvReserved			[integer!]
	dwReserved			[integer!]
	FlagsEx				[integer!]
]

tagBROWSEINFO: alias struct! [
	hwndOwner		[handle!]
	pidlRoot		[int-ptr!]
	pszDisplayName	[c-string!]
	lpszTitle		[c-string!]
	ulFlags			[integer!]
	lpfn			[integer!]
	lParam			[integer!]
	iImage			[integer!]
]

DwmIsCompositionEnabled!: alias function! [
	pfEnabled	[int-ptr!]
	return:		[integer!]
]

GetDpiForMonitor!: alias function! [
	hmonitor	[handle!]
	dpiType		[integer!]
	dpiX		[int-ptr!]
	dpiY		[int-ptr!]
	return:		[integer!]
]

#import [
	"kernel32.dll" stdcall [
		GlobalAlloc: "GlobalAlloc" [
			flags		[integer!]
			size		[integer!]
			return:		[handle!]
		]
		GlobalFree: "GlobalFree" [
			hMem		[handle!]
			return:		[integer!]
		]
		GlobalLock: "GlobalLock" [
			hMem		[handle!]
			return:		[byte-ptr!]
		]
		GlobalUnlock: "GlobalUnlock" [
			hMem		[handle!]
			return:		[integer!]
		]
		GetCurrentProcessId: "GetCurrentProcessId" [
			return:		[integer!]
		]
		GetModuleHandle: "GetModuleHandleW" [
			lpModuleName [integer!]
			return:		 [handle!]
		]
		GetSystemDirectory: "GetSystemDirectoryW" [
			lpBuffer	[c-string!]
			uSize		[integer!]
			return:		[integer!]
		]
		LocalLock: "LocalLock" [
			hMem		[handle!]
			return:		[byte-ptr!]
		]
		LocalUnlock: "LocalUnlock" [
			hMem		[handle!]
			return:		[byte-ptr!]
		]
		LoadLibraryA: "LoadLibraryA" [
			lpFileName	[c-string!]
			return:		[handle!]
		]
		FreeLibrary: "FreeLibrary" [
			hModule		[handle!]
			return:		[logic!]
		]
		GetProcAddress: "GetProcAddress" [
			hModule		[handle!]
			lpProcName	[c-string!]
			return:		[int-ptr!]
		]
		GetConsoleWindow: "GetConsoleWindow" [
			return:			[int-ptr!]
		]
	]
	"User32.dll" stdcall [
		GetDC: "GetDC" [
			hWnd		[handle!]
			return:		[handle!]
		]
		GetCursorPos: "GetCursorPos" [
			pt			[tagPOINT]
			return:		[logic!]
		]
		TrackMouseEvent: "TrackMouseEvent" [
			EventTrack	[tagTRACKMOUSEEVENT]
			return:		[logic!]
		]
		RedrawWindow: "RedrawWindow" [
			hWnd		[handle!]
			lprcUpdate	[RECT_STRUCT]
			hrgnUpdate	[handle!]
			flags		[integer!]
			return:		[logic!]
		]
		MonitorFromPoint: "MonitorFromPoint" [
			pt			[tagPOINT value]
			flags		[integer!]
			return:		[handle!]
		]
		GetKeyboardLayout: "GetKeyboardLayout" [
			idThread	[integer!]
			return:		[integer!]
		]
		GetSystemMetrics: "GetSystemMetrics" [
			index		[integer!]
			return:		[integer!]
		]
		GetSysColor: "GetSysColor" [
			nIndex		[integer!]
			return:		[integer!]
		]
		SystemParametersInfo: "SystemParametersInfoW" [
			action		[integer!]
			iParam		[integer!]
			vParam		[int-ptr!]
			winini		[integer!]
			return:		[logic!]
		]
		GetForegroundWindow: "GetForegroundWindow" [
			return:		[handle!]
		]
		IsWindowVisible: "IsWindowVisible" [
			hWnd		[handle!]
			return:		[logic!]
		]
		SetTimer: "SetTimer" [
			hWnd		[handle!]
			nIDEvent	[integer!]
			uElapse		[integer!]
			lpTimerFunc [timer-cb!]
			return:		[int-ptr!]
		]
		KillTimer: "KillTimer" [
			hWnd		[handle!]
			uIDEvent	[integer!]
			return:		[logic!]
		]
		OpenClipboard: "OpenClipboard" [
			hWnd		[handle!]
			return:		[logic!]
		]
		SetClipboardData: "SetClipboardData" [
			uFormat		[integer!]
			hMem		[handle!]
			return:		[handle!]
		]
		GetClipboardData: "GetClipboardData" [
			uFormat		[integer!]
			return:		[handle!]
		]
		EmptyClipboard: "EmptyClipboard" [
			return:		[integer!]
		]
		CloseClipboard: "CloseClipboard" [
			return:		[integer!]
		]
		IsClipboardFormatAvailable: "IsClipboardFormatAvailable" [
			format		[integer!]
			return:		[logic!]
		]
		GetKeyState: "GetKeyState" [
			nVirtKey	[integer!]
			return:		[integer!]
		]
		SetActiveWindow: "SetActiveWindow" [
			hWnd		[handle!]
			return:		[handle!]
		]
		SetForegroundWindow: "SetForegroundWindow" [
			hWnd		[handle!]
			return:		[logic!]
		]
		SetFocus: "SetFocus" [
			hWnd		[handle!]
			return:		[handle!]
		]
		SetCapture: "SetCapture" [
			hWnd		[handle!]
			return:		[handle!]
		]
		ReleaseCapture: "ReleaseCapture" [
			return:		[logic!]
		]
		GetWindowThreadProcessId: "GetWindowThreadProcessId" [
			hWnd		[handle!]
			process-id	[int-ptr!]
			return:		[integer!]
		]
		BeginPaint: "BeginPaint" [
			hWnd		[handle!]
			ps			[tagPAINTSTRUCT]
			return:		[handle!]
		]
		EndPaint: "EndPaint" [
			hWnd		[handle!]
			ps			[tagPAINTSTRUCT]
			return:		[integer!]
		]
		MapWindowPoints: "MapWindowPoints" [
			hWndFrom	[handle!]
			hWndTo		[handle!]
			lpPoints	[tagPOINT]
			cPoint		[integer!]
			return:		[integer!]
		]
		MapVirtualKey: "MapVirtualKeyW" [
			uCode		[integer!]
			uMapType	[integer!]
			return:		[integer!]
		]
		ToUnicode: "ToUnicode" [
			wVirtKey	[integer!]
			wScanCode	[integer!]
			lpKeyState	[byte-ptr!]
			pwszBuff	[c-string!]
			cchBuff		[integer!]
			wFlags		[integer!]
			return:		[integer!]
		]
		GetKeyboardState: "GetKeyboardState" [
			lpKeyState	[byte-ptr!]
			return:		[logic!]
		]
		GetSysColorBrush: "GetSysColorBrush" [
			index		[integer!]
			return:		[handle!]
		]
		EnumDisplayDevices: "EnumDisplayDevicesW" [
			lpDevice 	[c-string!]
			iDevNum		[integer!]
			lpDispDev	[DISPLAY_DEVICE]
			dwFlags		[integer!]
			return:		[integer!]
		]
		RegisterClassEx: "RegisterClassExW" [
			lpwcx		[WNDCLASSEX]
			return: 	[integer!]
		]
		UnregisterClass: "UnregisterClassW" [
			lpClassName	[c-string!]
			hInstance	[handle!]
			return:		[integer!]
		]
		LoadCursor: "LoadCursorW" [
			hInstance	 [handle!]
			lpCursorName [integer!]
			return: 	 [handle!]
		]
		SetCursor: "SetCursor" [
			hCursor		[handle!]
			return:		[handle!]			;-- return previous cursor, if there was one
		]
		CreateWindowEx: "CreateWindowExW" [
			dwExStyle	 [integer!]
			lpClassName	 [c-string!]
			lpWindowName [c-string!]
			dwStyle		 [integer!]
			x			 [integer!]
			y			 [integer!]
			nWidth		 [integer!]
			nHeight		 [integer!]
			hWndParent	 [handle!]
			hMenu	 	 [handle!]
			hInstance	 [handle!]
			lpParam		 [int-ptr!]
			return:		 [handle!]
		]
		ShowWindow: "ShowWindow" [
			hWnd		[handle!]
			nCmdShow	[integer!]
			return:		[logic!]
		]
		UpdateWindow: "UpdateWindow" [
			hWnd		[handle!]
			return:		[logic!]
		]
		EnableWindow: "EnableWindow" [
			hWnd		[handle!]
			bEnable		[logic!]
			return:		[logic!]
		]
		IsWindowEnabled: "IsWindowEnabled" [
			hWnd		[handle!]
			return:		[logic!]
		]
		InvalidateRect: "InvalidateRect" [
			hWnd		[handle!]
			lpRect		[RECT_STRUCT]
			bErase		[integer!]
			return:		[integer!]
		]
		ValidateRect: "ValidateRect" [
			hWnd		[handle!]
			lpRect		[RECT_STRUCT]
			return:		[logic!]
		]
		GetParent: "GetParent" [
			hWnd 		[handle!]
			return:		[handle!]
		]
		GetAncestor: "GetAncestor" [
			hWnd 		[handle!]
			gaFlags		[integer!]
			return:		[handle!]
		]
		GetWindow: "GetWindow" [
			hWnd 		[handle!]
			uCmd		[integer!]
			return:		[handle!]
		]
		WindowFromPoint: "WindowFromPoint" [
			x			[integer!]
			y			[integer!]
			return:		[handle!]
		]
		ChildWindowFromPointEx: "ChildWindowFromPointEx" [
			hwndParent	[handle!]
			x			[integer!]
			y			[integer!]
			flags		[integer!]
			return:		[handle!]
		]
		DefWindowProc: "DefWindowProcW" [
			hWnd		[handle!]
			msg			[integer!]
			wParam		[integer!]
			lParam		[integer!]
			return: 	[integer!]
		]
		CallWindowProc: "CallWindowProcW" [
			lpfnWndProc	[wndproc-cb!]
			hWnd		[handle!]
			msg			[integer!]
			wParam		[integer!]
			lParam		[integer!]
			return: 	[integer!]
		]
		GetMessage: "GetMessageW" [
			msg			[tagMSG]
			hWnd		[handle!]
			wParam		[integer!]
			lParam		[integer!]
			return: 	[integer!]
		]
		PeekMessage: "PeekMessageW" [
			msg			[tagMSG]
			hWnd		[handle!]
			msgMin		[integer!]
			msgMax		[integer!]
			removeMsg	[integer!]
			return: 	[integer!]
		]
		TranslateMessage: "TranslateMessage" [
			msg			[tagMSG]
			return: 	[logic!]
		]
		DispatchMessage: "DispatchMessageW" [
			msg			[tagMSG]
			return: 	[integer!]
		]
		PostQuitMessage: "PostQuitMessage" [
			nExitCode	[integer!]
		]
		SendMessage: "SendMessageW" [
			hWnd		[handle!]
			msg			[integer!]
			wParam		[integer!]
			lParam		[integer!]
			return: 	[handle!]
		]
		PostMessage: "PostMessageW" [
			hWnd		[handle!]
			msg			[integer!]
			wParam		[integer!]
			lParam		[integer!]
			return: 	[handle!]
		]
		GetMessagePos: "GetMessagePos" [
			return:		[integer!]
		]
		GetWindowLongPtr: "GetWindowLongW" [
			hWnd		[handle!]
			nIndex		[integer!]
			return:		[int-ptr!]
		]
		SetWindowLongPtr: "SetWindowLongW" [
			hWnd		[handle!]
			nIndex		[integer!]
			dwNewLong	[int-ptr!]
			return: 	[int-ptr!]
		]
		GetClassInfoEx: "GetClassInfoExW" [
			hInst		[handle!]
			lpszClass	[c-string!]
			lpwcx		[WNDCLASSEX]					;-- pass a WNDCLASSEX pointer's pointer
			return: 	[integer!]
		]
		GetWindowRect: "GetWindowRect" [
			hWnd		[handle!]
			lpRect		[RECT_STRUCT]
			return:		[integer!]
		]
		GetClientRect: "GetClientRect" [
			hWnd		[handle!]
			lpRect		[RECT_STRUCT]
			return:		[integer!]
		]
		GetDesktopWindow: "GetDesktopWindow" [
			return:		[handle!]
		]
		AdjustWindowRectEx: "AdjustWindowRectEx" [
			lpRect		[RECT_STRUCT]
			dwStyle		[integer!]
			bMenu		[logic!]
			dwExStyle	[integer!]
			return:		[logic!]
		]
		BringWindowToTop: "BringWindowToTop" [
			hWnd		[handle!]
			return:		[logic!]
		]
		BeginDeferWindowPos: "BeginDeferWindowPos" [
			nNumWindows [integer!]
			return:		[handle!]
		]
		EndDeferWindowPos: "EndDeferWindowPos" [
			hWinPosInfo [handle!]
			return:		[logic!]
		]
		DeferWindowPos: "DeferWindowPos" [
			hWinPosInfo [handle!]
			hWnd		[handle!]
			hWndAfter	[handle!]
			x			[integer!]
			y			[integer!]
			cx			[integer!]
			cy			[integer!]
			uFlags		[integer!]
			return:		[handle!]
		]
		SetWindowPos: "SetWindowPos" [
			hWnd		[handle!]
			hWndAfter	[handle!]
			x			[integer!]
			y			[integer!]
			cx			[integer!]
			cy			[integer!]
			uFlags		[integer!]
			return:		[integer!]
		]
		SetWindowText: "SetWindowTextW" [
			hWnd		[handle!]
			lpString	[c-string!]
		]
		GetWindowText: "GetWindowTextW" [
			hWnd		[handle!]
			lpString	[c-string!]
			nMaxCount	[integer!]
			return:		[integer!]
		]
		GetWindowTextLength: "GetWindowTextLengthW" [
			hWnd		[handle!]
			return:		[integer!]
		]
		CreateMenu: "CreateMenu" [
			return:		[handle!]
		]
		CreatePopupMenu: "CreatePopupMenu" [
			return:		[handle!]
		]
		AppendMenu: "AppendMenuW" [
			hMenu		[handle!]
			uFlags		[integer!]
			uIDNewItem	[integer!]
			lpNewItem	[c-string!]
			return:		[logic!]
		]
		InsertMenuItem: "InsertMenuItemW" [
			hMenu		[handle!]
			uItem		[integer!]
			byPosition	[logic!]
			lpmii		[MENUITEMINFO]
			return:		[logic!]
		]
		GetMenuItemInfo: "GetMenuItemInfoW" [
			hMenu		[handle!]
			uItem		[integer!]
			byPosition	[logic!]
			lpmii		[MENUITEMINFO]
			return:		[logic!]
		]
		TrackPopupMenuEx: "TrackPopupMenuEx" [
			hMenu		[handle!]
			fuFlags		[integer!]
			x			[integer!]
			y			[integer!]
			hWnd		[handle!]
			lptpm		[byte-ptr!]						;-- null (LPTPMPARAMS)
			return:		[integer!]
		]
		ClientToScreen: "ClientToScreen" [
			hWnd		[handle!]
			lpPoint		[tagPOINT]
			return:		[logic!]
		]
		ScreenToClient: "ScreenToClient" [
			hWnd		[handle!]
			lpPoint		[tagPOINT]
			return:		[logic!]
		]
		SetParent: "SetParent" [
			hChild		[handle!]
			hNewParent	[handle!]
			return:		[handle!]						;-- old parent
		]
		DestroyMenu: "DestroyMenu" [
			hMenu		[handle!]
			return:		[logic!]
		]
		SetMenu: "SetMenu" [
			hWnd		[handle!]
			hMenu		[handle!]
			return:		[logic!]
		]
		GetMenu: "GetMenu" [
			hWnd		[handle!]
			return:		[handle!]
		]
		DestroyWindow: "DestroyWindow" [
			hWnd		[handle!]
			return:		[logic!]
		]
		LoadIcon: "LoadIconW" [
			hInstance	[handle!]
			lpIconName	[c-string!]
			return:		[handle!]
		]
		GetAsyncKeyState: "GetAsyncKeyState" [
			nVirtKey	[integer!]
			return:		[integer!]						;-- returns a 16-bit value
		]
		GetCapture: "GetCapture" [
			return:		[handle!]
		]
		CreateCaret: "CreateCaret" [
			hWnd		[handle!]
			bitmap		[handle!]
			width		[integer!]
			height		[integer!]
			return:		[integer!]
		]
		DestroyCaret: "DestroyCaret" [
			return:		[integer!]
		]
		HideCaret: "HideCaret" [
			hWnd		[handle!]
			return:		[integer!]
		]
		ShowCaret: "ShowCaret" [
			hWnd		[handle!]
			return:		[integer!]
		]
		SetCaretPos: "SetCaretPos" [
			x			[integer!]
			y			[integer!]
			return:		[integer!]
		]
	]
	"gdi32.dll" stdcall [
		GetObject: "GetObjectW" [
			hObj		[handle!]
			cbBuffer	[integer!]
			lpObject	[byte-ptr!]
			return:		[integer!]
		]
		GetDeviceCaps: "GetDeviceCaps" [
			hDC			[handle!]
			nIndex		[integer!]
			return:		[integer!]
		]
		GetStockObject: "GetStockObject" [
			fnObject	[integer!]
			return:		[handle!]
		]
		DeleteObject: "DeleteObject" [
			hObject		[handle!]
			return:		[integer!]
		]
		CreateFontIndirect: "CreateFontIndirectW" [
			lplf		[tagLOGFONT]
			return:		[handle!]
		]
		CreateFont: "CreateFontW" [
			nHeight				[integer!]
			nWidth				[integer!]
			nEscapement			[integer!]
			nOrientation		[integer!]
			fnWeight			[integer!]
			fdwItalic			[integer!]
			fdwUnderline		[integer!]
			fdwStrikeOut		[integer!]
			fdwCharSet			[integer!]
			fdwOutputPrecision	[integer!]
			fdwClipPrecision	[integer!]
			fdwQuality			[integer!]
			fdwPitchAndFamily	[integer!]
			lpszFace			[c-string!]
			return: 			[handle!]
		]
	]
	"comdlg32.dll" stdcall [
			GetOpenFileName: "GetOpenFileNameW" [
				lpofn		[tagOFNW]
				return:		[integer!]
			]
			GetSaveFileName: "GetSaveFileNameW" [
				lpofn		[tagOFNW]
				return:		[integer!]
			]
		ChooseFont: "ChooseFontW" [
			lpcf		[tagCHOOSEFONT]
			return:		[logic!]
		]
	]
	"shell32.dll" stdcall [
		SHBrowseForFolder: "SHBrowseForFolderW" [
			lpbi		[tagBROWSEINFO]
			return: 	[integer!]
		]
		SHGetPathFromIDList: "SHGetPathFromIDListW" [
			pidl		[integer!]
			pszPath		[byte-ptr!]
			return:		[logic!]
		]
	]
	"d3d11.dll" stdcall [
		D3D11CreateDevice: "D3D11CreateDevice" [
			adapter		[int-ptr!]
			DriverType	[integer!]
			Software	[int-ptr!]
			Flags		[integer!]
			pFeatures	[int-ptr!]
			Features	[integer!]
			SDKVersion	[integer!]
			ppDevice	[com-ptr!]
			pFeatLevel	[int-ptr!]
			ppContext	[com-ptr!]
			return:		[integer!]
		]
	]
	"ole32.dll" stdcall [
		CoTaskMemFree: "CoTaskMemFree" [
			pv		[integer!]
		]
	]
	"imm32.dll" stdcall [
		ImmGetContext: "ImmGetContext" [
			hWnd	[handle!]
			return:	[handle!]
		]
		ImmReleaseContext: "ImmReleaseContext" [
			hWnd	[handle!]
			hIMC	[handle!]
			return:	[logic!]
		]
		ImmGetOpenStatus: "ImmGetOpenStatus" [
			hIMC	[handle!]
			return:	[logic!]
		]
		ImmSetCompositionWindow: "ImmSetCompositionWindow" [
			hIMC	[handle!]
			lpComp	[tagCOMPOSITIONFORM]
			return: [logic!]
		]
		ImmSetCompositionFontW: "ImmSetCompositionFontW" [
			hIMC	[handle!]
			lfont	[tagLOGFONT]
			return: [logic!]
		]
	]
	"UxTheme.dll" stdcall [
		OpenThemeData: "OpenThemeData" [
			hWnd		 [handle!]
			pszClassList [c-string!]
			return:		 [handle!]
		]
		CloseThemeData: "CloseThemeData" [
			hTheme		[handle!]
			return:		[integer!]
		]
		IsThemeActive:	"IsThemeActive" [				;WARN: do not call from DllMain!!
			return:		[logic!]
		]
		GetThemeSysFont: "GetThemeSysFont" [
			hTheme		[handle!]
			iFontID		[integer!]
			plf			[tagLOGFONT]
			return:		[integer!]
		]
	]
	LIBC-file cdecl [
		realloc: "realloc" [						"Resize and return allocated memory."
			memory			[byte-ptr!]
			size			[integer!]
			return:			[byte-ptr!]
		]
	]
]

#case [
	any [not legacy not find legacy 'no-touch] [
		#import [
			"User32.dll" stdcall [
				SetGestureConfig: "SetGestureConfig" [
					hWnd		[handle!]
					dwReserved	[integer!]						;-- set it to 0
					cIDs		[integer!]
					pConfig		[GESTURECONFIG]
					cbSize		[integer!]
					return:		[logic!]
				]
				GetGestureInfo: "GetGestureInfo" [
					hIn			[GESTUREINFO]
					hOut		[GESTUREINFO]
					return:		[logic!]
				]
			]
		]
	]
]

#define ConvertPointSizeToDIP(size)		(as float32! 96 * size / 72)

#define D2D_MAX_BRUSHES 64

#define DXGI_DEBUG_RLO_ALL	 7
#define DXGI_FORMAT_A8_UNORM 65
#define D2DERR_RECREATE_TARGET 8899000Ch
#define DXGI_ERROR_DEVICE_REMOVED 887A0005h
#define DXGI_ERROR_DEVICE_RESET	887A0007h
#define FLT_MAX	[as float32! 3.402823466e38]

IID_IDXGIDebug:			 [119E7452h 40FEDE9Eh F9880688h 41B4120Ch]
IID_IDXGISurface:		 [CAFCB56Ch 48896AC3h 239E47BFh EC60D2BBh]
IID_IDXGIDevice1:		 [77DB970Fh 48BA6276h 010728BAh 2C39B443h]
;IID_ID2D1Factory:		 [06152247h 465A6F50h 8B114592h 07603BFDh]
IID_ID2D1Factory1:		 [BB12D362h 4B9ADAEEh BA141DAAh 1FFA1C40h]
IID_IDWriteFactory:		 [B859EE5Ah 4B5BD838h DC1AE8A2h 48DB937Dh]
IID_IDXGIFactory2:		 [50C83A1Ch 4C48E072h 3036B087h D0A636FAh]
IID_IDCompositionDevice: [C37EA93Ah 450DE7AAh 46976FB1h F30704CBh]
IID_IDGdiInterop: 		 [E0DB51C3h 4BAE6F77h 75E4D5B3h 3858B309h]
IID_ID2D1DeviceContext:	 [E8F7FE7Ah 466D191Ch 569795ADh 98A9BD78h]
CLSID_D2D1UnPremultiply: [FB9AC489h 41EDAD8Dh 63BB9999h F710D147h]
CLSID_D2D1Scale:		 [9DAF9369h 4D0E3846h 600C4EA4h D7A53479h]
CLSID_D2D1Shadow:		 [C67EA361h 4E691863h 5D69DB89h 6B5B9A3Eh]
DXGI_DEBUG_ALL:			 [E48AE283h 490BDA80h E943E687h 08DACFA9h]

D2D1_FACTORY_OPTIONS: alias struct! [
	debugLevel	[integer!]
]

D3DCOLORVALUE: alias struct! [
	r			[float32!]
	g			[float32!]
	b			[float32!]
	a			[float32!]
]

ROUNDED_RECT_F!: alias struct! [
	left		[float32!]
	top			[float32!]
	right		[float32!]
	bottom		[float32!]
	radiusX		[float32!]
	radiusY		[float32!]
]

SIZE_U!: alias struct! [
	width		[uint32!]
	height		[uint32!]
]

SIZE_F!: alias struct! [
	width		[float32!]
	height		[float32!]
]

D2D1_BEZIER_SEGMENT: alias struct! [
	point1		[POINT_2F value]
	point2		[POINT_2F value]
	point3		[POINT_2F value]
]

D2D1_QUADRATIC_BEZIER_SEGMENT: alias struct! [
	point1		[POINT_2F value]
	point2		[POINT_2F value]
]

D2D1_ARC_SEGMENT: alias struct! [
	point		[POINT_2F value]
	size		[SIZE_F! value]
	angle		[float32!]
	direction	[integer!]
	arcSize		[integer!]
]

D2D_MATRIX_3X2_F: alias struct! [
	_11			[float32!]
	_12			[float32!]
	_21			[float32!]
	_22			[float32!]
	_31			[float32!]
	_32			[float32!]
]

D2D1_ELLIPSE: alias struct! [
	x			[float32!]
	y			[float32!]
	radiusX		[float32!]
	radiusY		[float32!]
]

D2D1_GRADIENT_STOP: alias struct! [
	position	[float32!]
	r			[float32!]
	g			[float32!]
	b			[float32!]
	a			[float32!]
]

#enum D2D1_CAP_STYLE [
	D2D1_CAP_STYLE_FLAT
	D2D1_CAP_STYLE_SQUARE
	D2D1_CAP_STYLE_ROUND
	D2D1_CAP_STYLE_TRIANGLE
	D2D1_CAP_STYLE_FORCE_DWORD: -1
]

#enum D2D1_LINE_JOIN [
	D2D1_LINE_JOIN_MITER
	D2D1_LINE_JOIN_BEVEL
	D2D1_LINE_JOIN_ROUND
	D2D1_LINE_JOIN_MITER_OR_BEVEL
	D2D1_LINE_JOIN_FORCE_DWORD: -1
]

D2D1_STROKE_STYLE_PROPERTIES: alias struct! [
	startCap	[integer!]
	endCap		[integer!]
	dashCap		[integer!]
	lineJoin	[integer!]
	miterLimit	[float32!]
	dashStyle	[integer!]
	dashOffset	[float32!]
]

D2D1_RENDER_TARGET_PROPERTIES: alias struct! [
	type		[integer!]
	format		[integer!]
	alphaMode	[integer!]
	dpiX		[float32!]
	dpiY		[float32!]
	usage		[integer!]
	minLevel	[integer!]
]

D2D1_HWND_RENDER_TARGET_PROPERTIES: alias struct! [
	hwnd				[handle!]
	pixelSize.width		[integer!]
	pixelSize.height	[integer!]
	presentOptions		[integer!]
]

D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES: alias struct! [
	startPoint.x		[float32!]
	startPoint.y		[float32!]
	endPoint.x			[float32!]
	endPoint.y			[float32!]
]

D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES: alias struct! [
	center.x			[float32!]
	center.y			[float32!]
	offset.x			[float32!]
	offset.y			[float32!]
	radius.x			[float32!]
	radius.y			[float32!]
]

DXGI_SWAP_CHAIN_DESC1: alias struct! [
    Width			[integer!]
    Height			[integer!]
    Format			[integer!]
    Stereo			[integer!]
    SampleCount		[integer!]
    SampleQuality	[integer!]
    BufferUsage		[integer!]
    BufferCount		[integer!]
    Scaling			[integer!]
    SwapEffect		[integer!]
    AlphaMode		[integer!]
    Flags			[integer!]
]

#enum D2D1_EXTEND_MODE [
	D2D1_EXTEND_MODE_CLAMP
	D2D1_EXTEND_MODE_WRAP
	D2D1_EXTEND_MODE_MIRROR
	D2D1_EXTEND_MODE_FORCE_DWORD: -1
]

D2D1_BITMAP_BRUSH_PROPERTIES1: alias struct! [
	extendModeX		[D2D1_EXTEND_MODE]
	extendModeY		[D2D1_EXTEND_MODE]
	interpolationMode [integer!]
]

D2D1_IMAGE_BRUSH_PROPERTIES: alias struct! [
	;sourceRectangle	[RECT_F! value]
	left			[float32!]
	top				[float32!]
	right			[float32!]
	bottom			[float32!]
	extendModeX		[D2D1_EXTEND_MODE]
	extendModeY		[D2D1_EXTEND_MODE]
	interpolationMode [integer!]
]

D2D1_BRUSH_PROPERTIES: alias struct! [
	opacity			[float32!]
	transform		[D2D_MATRIX_3X2_F value]
]

D2D1_BITMAP_PROPERTIES1: alias struct! [
	format			[integer!]
	alphaMode		[integer!]
	dpiX			[float32!]
	dpiY			[float32!]
	options			[integer!]
	colorContext	[int-ptr!]
]

DXGI_PRESENT_PARAMETERS: alias struct! [
	DirtyRectsCount	[integer!]
	pDirtyRects		[RECT_STRUCT]
	pScrollRect		[RECT_STRUCT]
	pScrollOffset	[tagPOINT]
]

CreateSolidColorBrush*: alias function! [
	this		[this!]
	color		[D3DCOLORVALUE]
	properties	[D2D1_BRUSH_PROPERTIES]
	brush		[com-ptr!]
	return:		[integer!]
]

CreateLinearGradientBrush*: alias function! [
	this		[this!]
	gprops		[D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES]
	props		[D2D1_BRUSH_PROPERTIES]
	stops		[this!]
	brush		[com-ptr!]
	return:		[integer!]
]

CreateRadialGradientBrush*: alias function! [
	this		[this!]
	gprops		[D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES]
	props		[D2D1_BRUSH_PROPERTIES]
	stops		[this!]
	brush		[com-ptr!]
	return:		[integer!]
]

CreateGradientStopCollection*: alias function! [
	this		[this!]
	stops		[D2D1_GRADIENT_STOP]
	stopsCount	[integer!]
	gamma		[integer!]
	extendMode	[integer!]
	stops-ptr	[com-ptr!]
	return:		[integer!]
]

DrawLine*: alias function! [
	this		[this!]
	pt0.x		[float32!]
	pt0.y		[float32!]
	pt1.x		[float32!]
	pt1.y		[float32!]
	brush		[this!]
	width		[float32!]
	style		[this!]
]

DrawRectangle*: alias function! [
	this		[this!]
	rect		[RECT_F!]
	brush		[this!]
	strokeWidth [float32!]
	strokeStyle [this!]
]

FillRectangle*: alias function! [
	this		[this!]
	rect		[RECT_F!]
	brush		[this!]
]

DrawRoundedRectangle*: alias function! [
	this		[this!]
	rect		[ROUNDED_RECT_F!]
	brush		[this!]
	strokeWidth [float32!]
	strokeStyle [this!]
]

FillRoundedRectangle*: alias function! [
	this		[this!]
	rect		[ROUNDED_RECT_F!]
	brush		[this!]
]

DrawEllipse*: alias function! [
	this		[this!]
	ellipse		[D2D1_ELLIPSE]
	brush		[this!]
	width		[float32!]
	style		[this!]
]

FillEllipse*: alias function! [
	this		[this!]
	ellipse		[D2D1_ELLIPSE]
	brush		[this!]
]

DrawTextLayout*: alias function! [
	this		[this!]
	x			[float32!]
	y			[float32!]
	layout		[this!]
	brush		[this!]
	options		[integer!]
]

SetTransform*: alias function! [
	this		[this!]
	transform	[D2D_MATRIX_3X2_F]
]

GetTransform*: alias function! [
	this		[this!]
	transform	[D2D_MATRIX_3X2_F]
]

SetCenter*: alias function! [
	this		[this!]
	center		[POINT_2F value]
]

GetCenter*: alias function! [
	this		[this!]
	center		[POINT_2F]
]

SetGradientOriginOffset*: alias function! [
	this		[this!]
	Offset		[POINT_2F value]
]

GetGradientOriginOffset*: alias function! [
	this		[this!]
	Offset		[POINT_2F]
]

SetRadiusX*: alias function! [
	this		[this!]
	x			[float32!]
]

GetRadiusX*: alias function! [
	this		[this!]
	return:		[float32!]
]

SetRadiusY*: alias function! [
	this		[this!]
	y			[float32!]
]

GetRadiusY*: alias function! [
	this		[this!]
	return:		[float32!]
]

Resize*: alias function! [
	this		[this!]
	pixelSize	[tagSIZE]
	return:		[integer!]
]

CreateSwapChainForHwnd*: alias function! [
	this				[this!]
	pDevice				[this!]
	hwnd				[handle!]
	desc				[DXGI_SWAP_CHAIN_DESC1]
	pFullscreenDesc		[int-ptr!]
	pRestrictToOutput	[int-ptr!]
	ppSwapChain			[int-ptr!]
	return:				[integer!]
]

CreateSwapChainForComposition*: alias function! [
	this				[this!]
	pDevice				[this!]
	desc				[DXGI_SWAP_CHAIN_DESC1]
	pRestrictToOutput	[int-ptr!]
	ppSwapChain			[int-ptr!]
	return:				[integer!]
]

#define ID2D1Resource [
	QueryInterface		[QueryInterface!]
	AddRef				[AddRef!]
	Release				[Release!]
	GetFactory			[integer!]
]

#define ID2D1Brush* [
	QueryInterface		[QueryInterface!]
	AddRef				[AddRef!]
	Release				[Release!]
	GetFactory			[integer!]
	SetOpacity			[integer!]
	SetTransform		[SetTransform*]
	GetOpacity			[integer!]
	GetTransform		[GetTransform*]
]

IDXGIDebug: alias struct! [
	QueryInterface		[QueryInterface!]
	AddRef				[AddRef!]
	Release				[Release!]
	ReportLiveObjects	[function! [this [this!] apiid [int-ptr!] flags [integer!] return: [integer!]]]
]

ID2D1Brush: alias struct! [
	ID2D1Brush*
]

ID2D1LinearGradientBrush: alias struct! [
	ID2D1Brush*
	SetStartPoint		[function! [this [this!] startPoint [POINT_2F value]]]
	SetEndPoint			[function! [this [this!] endPoint [POINT_2F value]]]
	GetStartPoint		[function! [this [this!] startPoint [POINT_2F]]]
	GetEndPoint			[function! [this [this!] startPoint [POINT_2F]]]
	GetGradientStopCollection	[function! [this [this!] stop [ptr-ptr!]]]
]

ID2D1SolidColorBrush: alias struct! [
	ID2D1Brush*
	SetColor			[function! [this [this!] color [D3DCOLORVALUE]]]
	GetColor			[integer!]
]

ID2D1RadialGradientBrush: alias struct! [
	ID2D1Brush*
	SetCenter					[SetCenter*]
	SetGradientOriginOffset		[SetGradientOriginOffset*]
	SetRadiusX					[SetRadiusX*]
	SetRadiusY					[SetRadiusY*]
	GetCenter					[GetCenter*]
	GetGradientOriginOffset		[GetGradientOriginOffset*]
	GetRadiusX					[GetRadiusX*]
	GetRadiusY					[GetRadiusY*]
	GetGradientStopCollection	[integer!]
]

ID2D1GradientStopCollection: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetFactory						[integer!]
	GetGradientStopCount			[integer!]
	GetGradientStops				[integer!]
	GetColorInterpolationGamma		[integer!]
	GetExtendMode					[integer!]
]

ID2D1Properties: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetPropertyCount				[int-ptr!]
	GetPropertyName					[int-ptr!]
	GetPropertyNameLength			[int-ptr!]
	GetType							[int-ptr!]
	GetPropertyIndex				[int-ptr!]
	SetValueByName					[int-ptr!]
	SetValue						[function! [this [this!] idx [uint32!] type [integer!] data [byte-ptr!] datasize [uint32!] return: [integer!]]]
	GetValueByName					[int-ptr!]
	GetValue						[int-ptr!]
	GetValueSize					[int-ptr!]
	GetSubProperties				[int-ptr!]
]

ID2D1Effect: alias struct! [
	Base							[ID2D1Properties value]
	SetInput						[function! [this [this!] idx [uint32!] input [this!] invalidate [logic!]]]
	SetInputCount					[function! [this [this!] count [uint32!] return: [integer!]]]
	GetInput						[function! [this [this!] idx [uint32!] input [com-ptr!]]]
	GetInputCount					[function! [this [this!] return: [integer!]]]
	GetOutput						[function! [this [this!] output [com-ptr!]]]
]

ID2D1CommandList: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetFactory						[integer!]
	Stream							[int-ptr!]
	Close							[function! [this [this!] return: [integer!]]]
]

IDXGIDevice1: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetPrivateData					[integer!]
	SetPrivateDataInterface			[integer!]
	GetPrivateData					[integer!]
	GetParent						[function! [this [this!] riid [int-ptr!] parent [int-ptr!] return: [integer!]]]
	GetAdapter						[function! [this [this!] adapter [com-ptr!] return: [integer!]]]
	CreateSurface					[integer!]
	QueryResourceResidency			[integer!]
	SetGPUThreadPriority			[integer!]
	GetGPUThreadPriority			[integer!]
	SetMaximumFrameLatency			[integer!]
	GetMaximumFrameLatency			[integer!]
]

IDXGIAdapter: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetPrivateData					[integer!]
	SetPrivateDataInterface			[integer!]
	GetPrivateData					[integer!]
	GetParent						[function! [this [this!] riid [int-ptr!] parent [com-ptr!] return: [integer!]]]
	EnumOutputs						[integer!]
	GetDesc							[integer!]
	CheckInterfaceSupport			[integer!]
]

IDXGISwapChain1: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetPrivateData					[int-ptr!]
	SetPrivateDataInterface			[int-ptr!]
	GetPrivateData					[int-ptr!]
	GetParent						[function! [this [this!] riid [int-ptr!] parent [int-ptr!] return: [integer!]]]
	GetDevice						[function! [this [this!] riid [int-ptr!] device [int-ptr!] return: [integer!]]]
	Present							[function! [this [this!] SyncInterval [integer!] PresentFlags [integer!] return: [integer!]]]
	GetBuffer						[function! [this [this!] idx [integer!] riid [int-ptr!] buffer [int-ptr!] return: [integer!]]]
	SetFullscreenState				[int-ptr!]
	GetFullscreenState				[int-ptr!]
	GetDesc							[int-ptr!]
	ResizeBuffers					[function! [this [this!] count [uint!] width [uint!] height [uint!] format [integer!] flags [uint!] return: [integer!]]]
	ResizeTarget					[int-ptr!]
	GetContainingOutput				[int-ptr!]
	GetFrameStatistics				[int-ptr!]
	GetLastPresentCount				[int-ptr!]
	GetDesc1						[int-ptr!]
	GetFullscreenDesc				[int-ptr!]
	GetHwnd							[int-ptr!]
	GetCoreWindow					[int-ptr!]
	Present1						[function! [this [this!] SyncInterval [integer!] PresentFlags [integer!] pPresentParameters [DXGI_PRESENT_PARAMETERS] return: [integer!]]]
	IsTemporaryMonoSupported		[int-ptr!]
	GetRestrictToOutput				[int-ptr!]
	SetBackgroundColor				[int-ptr!]
	GetBackgroundColor				[int-ptr!]
	SetRotation						[int-ptr!]
	GetRotation						[int-ptr!]
]

IDCompositionDevice: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	Commit							[function! [this [this!] return: [integer!]]]
	WaitForCommitCompletion			[integer!]
	GetFrameStatistics				[integer!]
	CreateTargetForHwnd				[function! [this [this!] hwnd [handle!] topmost [logic!] target [int-ptr!] return: [integer!]]]
	CreateVisual					[function! [this [this!] visual [int-ptr!] return: [integer!]]]
	CreateSurface					[integer!]
	CreateVirtualSurface			[integer!]
	CreateSurfaceFromHandle			[integer!]
	CreateSurfaceFromHwnd			[integer!]
	CreateTranslateTransform		[integer!]
	CreateScaleTransform			[integer!]
	CreateRotateTransform			[integer!]
	CreateSkewTransform				[integer!]
	CreateMatrixTransform			[integer!]
	CreateTransformGroup			[integer!]
	CreateTranslateTransform3D		[integer!]
	CreateScaleTransform3D			[integer!]
	CreateRotateTransform3D			[integer!]
	CreateMatrixTransform3D			[integer!]
	CreateTransform3DGroup			[integer!]
	CreateEffectGroup				[integer!]
	CreateRectangleClip				[integer!]
	CreateAnimation					[integer!]
	CreateTransformGroup			[integer!]
	CheckDeviceState				[integer!]
]

IDCompositionVisual: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetOffsetX						[function! [this [this!] x [float32!] return: [integer!]]]
	SetOffsetX1						[integer!]
	SetOffsetY						[function! [this [this!] y [float32!] return: [integer!]]]
	SetOffsetY1						[integer!]
	SetTransform					[integer!]
	SetTransform1					[integer!]
	SetTransformParent				[integer!]
	SetEffect						[integer!]
	SetBitmapInterpolationMode		[integer!]
	SetBorderMode					[integer!]
	SetClip							[integer!]
	SetClip1						[integer!]
	SetContent						[function! [this [this!] p [this!] return: [integer!]]]
	AddVisual						[function! [this [this!] v [this!] above [logic!] vv [this!] return: [integer!]]]
	RemoveVisual					[integer!]
	RemoveAllVisuals				[integer!]
	SetCompositeMode				[integer!]

]

IDCompositionTarget: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetRoot							[function! [this [this!] visual [this!] return: [integer!]]]
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
	CreatePathGeometry				[function! [this [this!] pathGeometry [ptr-ptr!] return: [integer!]]]
	CreateStrokeStyle				[function! [this [this!] props [D2D1_STROKE_STYLE_PROPERTIES] dashes [float32-ptr!] count [integer!] style [ptr-ptr!] return: [integer!]]]
	CreateDrawingStateBlock			[function! [this [this!] desc [this!] param [this!] block [ptr-ptr!] return: [integer!]]]
	CreateWicBitmapRenderTarget		[function! [this [this!] target [this!] properties [D2D1_RENDER_TARGET_PROPERTIES] bmp [com-ptr!] return: [integer!]]]
	CreateHwndRenderTarget			[function! [this [this!] properties [D2D1_RENDER_TARGET_PROPERTIES] hwndProperties [D2D1_HWND_RENDER_TARGET_PROPERTIES] target [ptr-ptr!] return: [integer!]]]
	CreateDxgiSurfaceRenderTarget	[integer!]
	CreateDCRenderTarget			[function! [this [this!] properties [D2D1_RENDER_TARGET_PROPERTIES] target [int-ptr!] return: [integer!]]]
	CreateDevice					[function! [this [this!] dxgiDevice [this!] d2dDevice [com-ptr!] return: [integer!]]]
]

IDXGIFactory2: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetPrivateData					[integer!]
	SetPrivateDataInterface			[integer!]
	GetPrivateData					[integer!]
	GetParent						[function! [this [this!] riid [int-ptr!] parent [com-ptr!] return: [integer!]]]
	EnumAdapters					[function! [this [this!] n [integer!] adapter [com-ptr!] return: [integer!]]]
	MakeWindowAssociation			[integer!]
	GetWindowAssociation			[integer!]
	CreateSwapChain					[integer!]
	CreateSoftwareAdapter			[integer!]
	EnumAdapters1					[integer!]
	IsCurrent						[integer!]
	IsWindowedStereoEnabled			[integer!]
	CreateSwapChainForHwnd			[CreateSwapChainForHwnd*]
	CreateSwapChainForCoreWindow	[integer!]
	GetSharedResourceAdapterLuid	[integer!]
	RegisterStereoStatusWindow		[integer!]
	RegisterStereoStatusEvent		[integer!]
	UnregisterStereoStatus			[integer!]
	RegisterOcclusionStatusWindow	[integer!]
	RegisterOcclusionStatusEvent	[integer!]
	UnregisterOcclusionStatus		[integer!]
	CreateSwapChainForComposition	[CreateSwapChainForComposition*]
]

ID2D1Device: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetFactory						[integer!]
	CreateDeviceContext				[function! [this [this!] options [integer!] ctx [com-ptr!] return: [integer!]]]
	CreatePrintControl				[integer!]
	SetMaximumTextureMemory			[integer!]
	GetMaximumTextureMemory			[integer!]
	ClearResources					[integer!]
	CreatePrintControl2				[integer!]
]

ID3D11Device: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	CreateBuffer					[integer!]
	CreateTexture1D					[integer!]
	CreateTexture2D					[integer!]
	CreateTexture3D					[integer!]
	CreateShaderResourceView		[integer!]
	CreateUnorderedAccessView		[integer!]
	CreateRenderTargetView			[integer!]
	CreateDepthStencilView			[integer!]
	CreateInputLayout				[integer!]
	CreateVertexShader				[integer!]
	CreateGeometryShader			[integer!]
	CreateGeometryShaderWithStreamOutput [integer!]
	CreatePixelShader				[integer!]
	CreateHullShader				[integer!]
	CreateDomainShader				[integer!]
	CreateComputeShader				[integer!]
	CreateClassLinkage				[integer!]
	CreateBlendState				[integer!]
	CreateDepthStencilState			[integer!]
	CreateRasterizerState			[integer!]
	CreateSamplerState				[integer!]
	CreateQuery						[integer!]
	CreatePredicate					[integer!]
	CreateCounter					[integer!]
	CreateDeferredContext			[integer!]
	OpenSharedResource				[integer!]
	CheckFormatSupport				[integer!]
	CheckMultisampleQualityLevels	[integer!]
	CheckCounterInfo				[integer!]
	CheckCounter					[integer!]
	CheckFeatureSupport				[integer!]
	GetPrivateData					[integer!]
	SetPrivateData					[integer!]
	SetPrivateDataInterface			[integer!]
	GetFeatureLevel					[integer!]
	GetCreationFlags				[integer!]
	GetDeviceRemovedReason			[integer!]
	GetImmediateContext				[integer!]
	SetExceptionMode				[integer!]
	GetExceptionMode				[integer!]
]

CreateSharedBitmap*: alias function! [
	this		[this!]
	riid		[tagGUID]
	data		[byte-ptr!]
	properties	[D2D1_BITMAP_PROPERTIES1]
	bitmap		[ptr-ptr!]
	return:		[integer!]
]

CreateImageBrush*: alias function! [
	this		[this!]
	bitmap		[this!]
	properties	[D2D1_IMAGE_BRUSH_PROPERTIES]
	brushProp	[D2D1_BRUSH_PROPERTIES]
	brush		[ptr-ptr!]
	return:		[integer!]
]

CreateBitmapBrush*: alias function! [
	this		[this!]
	bitmap		[this!]
	properties	[D2D1_BITMAP_BRUSH_PROPERTIES1]
	brushProp	[D2D1_BRUSH_PROPERTIES]
	brush		[ptr-ptr!]
	return:		[integer!]
]

CreateBitmap*: alias function! [
	this		[this!]
	size		[SIZE_U! value]
	sourceData	[int-ptr!]
	pitch		[uint32!]
	properties	[D2D1_BITMAP_PROPERTIES1]
	bitmap		[ptr-ptr!]
	return:		[integer!]
]

CreateBitmapFromWicBitmap*: alias function! [
	this		[this!]
	source		[this!]
	properties	[D2D1_BITMAP_PROPERTIES1]
	bitmap		[ptr-ptr!]
	return:		[integer!]
]

CreateEffect*: alias function! [
	this		[this!]
	effectID	[int-ptr!]
	effect		[com-ptr!]
	return:		[integer!]
]

DrawImage*: alias function! [
	this		[this!]
	image		[this!]
	offset		[POINT_2F]
	rect		[RECT_F!]
	interpola	[integer!]
	composite	[integer!]
]

DrawBitmap*: alias function! [
	this		[this!]
	bmp			[int-ptr!]
	dst			[RECT_F!]
	opacity		[float32!]
	mode		[integer!]
	src			[RECT_F!]
	trans		[int-ptr!]
]

D2D1_LAYER_PARAMETERS1: alias struct! [
	bounds		[RECT_F! value]
	mask		[int-ptr!]
	mode		[integer!]
	trans		[D2D_MATRIX_3X2_F value]
	opacity		[float32!]
	brush		[int-ptr!]
	opts		[integer!]
]

PushLayer*: alias function! [
	this		[this!]
	param		[D2D1_LAYER_PARAMETERS1]
	layer		[int-ptr!]
]

CombineWithGeometry*: alias function! [
	this		[this!]
	input		[int-ptr!]
	mode		[integer!]
	trans		[D2D_MATRIX_3X2_F]
	flat		[float32!]
	sink		[int-ptr!]
	return:		[integer!]
]

#define ID2D1RenderTarget [
	QueryInterface					[function! [this [this!] riid [int-ptr!] ppvObject [com-ptr!] return: [integer!]]]
	AddRef							[AddRef!]
	Release							[Release!]
	GetFactory						[integer!]
	CreateBitmap					[integer!]
	CreateBitmapFromWicBitmap		[integer!]
	CreateSharedBitmap				[CreateSharedBitmap*]
	CreateBitmapBrush				[CreateBitmapBrush*]
	CreateSolidColorBrush			[CreateSolidColorBrush*]
	CreateGradientStopCollection	[CreateGradientStopCollection*]
	CreateLinearGradientBrush		[CreateLinearGradientBrush*]
	CreateRadialGradientBrush		[CreateRadialGradientBrush*]
	CreateCompatibleRenderTarget	[function! [this [this!] size [SIZE_F! value] target [ptr-ptr!] return: [integer!]]]
	CreateLayer						[function! [this [this!] size [SIZE_F!] layer [ptr-ptr!] return: [integer!]]]
	CreateMesh						[integer!]
	DrawLine						[DrawLine*]
	DrawRectangle					[DrawRectangle*]
	FillRectangle					[FillRectangle*]
	DrawRoundedRectangle			[DrawRoundedRectangle*]
	FillRoundedRectangle			[FillRoundedRectangle*]
	DrawEllipse						[DrawEllipse*]
	FillEllipse						[FillEllipse*]
	DrawGeometry					[function! [this [this!] geometry [this!] brush [this!] strokeWidth [float32!] style [this!] return: [integer!]]]
	FillGeometry					[function! [this [this!] geometry [this!] brush [this!] opacityBrush [this!] return: [integer!]]]
	FillMesh						[integer!]
	FillOpacityMask					[integer!]
	DrawBitmap						[integer!]
	DrawText						[integer!]
	DrawTextLayout					[DrawTextLayout*]
	DrawGlyphRun					[integer!]
	SetTransform					[SetTransform*]
	GetTransform					[GetTransform*]
	SetAntialiasMode				[function! [this [this!] mode [integer!]]]
	GetAntialiasMode				[integer!]
	SetTextAntialiasMode			[function! [this [this!] mode [integer!]]]
	GetTextAntialiasMode			[integer!]
	SetTextRenderingParams			[integer!]
	GetTextRenderingParams			[integer!]
	SetTags							[integer!]
	GetTags							[integer!]
	PushLayer						[integer!]
	PopLayer						[function! [this [this!]]]
	Flush							[function! [this [this!] tag1 [int-ptr!] tag2 [int-ptr!]]]
	SaveDrawingState				[function! [this [this!] block [this!]]]
	RestoreDrawingState				[function! [this [this!] block [this!]]]
	PushAxisAlignedClip				[function! [this [this!] rc [RECT_F!] mode [integer!]]]
	PopAxisAlignedClip				[function! [this [this!]]]
	Clear							[function! [this [this!] color [D3DCOLORVALUE]]]
	BeginDraw						[function! [this [this!]]]
	EndDraw							[function! [this [this!] tag1 [int-ptr!] tag2 [int-ptr!] return: [integer!]]]
	GetPixelFormat					[integer!]
	SetDpi							[function! [this [this!] x [float32!] y [float32!]]]
	GetDpi							[integer!]
	GetSize							[integer!]
	GetPixelSize					[integer!]
	GetMaximumBitmapSize			[integer!]
	IsSupported						[integer!]
]

ID2D1DeviceContext: alias struct! [
	ID2D1RenderTarget
    CreateBitmap2					[CreateBitmap*]
    CreateBitmapFromWicBitmap2		[CreateBitmapFromWicBitmap*]
    CreateColorContext						[integer!]
    CreateColorContextFromFilename			[integer!]
    CreateColorContextFromWicColorContext	[integer!]
    CreateBitmapFromDxgiSurface		[function! [this [this!] surface [int-ptr!] props [D2D1_BITMAP_PROPERTIES1] bitmap [int-ptr!] return: [integer!]]]
    CreateEffect					[CreateEffect*]
    CreateGradientStopCollection2	[integer!]
    CreateImageBrush				[CreateImageBrush*]
    CreateBitmapBrush2				[CreateBitmapBrush*]
    CreateCommandList				[function! [this [this!] cmd [com-ptr!] return: [integer!]]]
    IsDxgiFormatSupported			[integer!]
    IsBufferPrecisionSupported		[integer!]
    GetImageLocalBounds				[integer!]
    GetImageWorldBounds				[integer!]
    GetGlyphRunWorldBounds			[integer!]
    GetDevice						[function! [this [this!] dev [int-ptr!]]]
    SetTarget						[function! [this [this!] bmp [this!]]]
    GetTarget						[function! [this [this!] bmp [com-ptr!]]]
    SetRenderingControls			[integer!]
    GetRenderingControls			[integer!]
    SetPrimitiveBlend				[integer!]
    GetPrimitiveBlend				[integer!]
    SetUnitMode						[integer!]
    GetUnitMode						[integer!]
    DrawGlyphRun2					[integer!]
    DrawImage						[DrawImage*]
    DrawGdiMetafile					[integer!]
    DrawBitmap2						[DrawBitmap*]
    PushLayer2						[PushLayer*]
    InvalidateEffectInputRectangle	[integer!]
    GetEffectInvalidRectangleCount	[integer!]
    GetEffectInvalidRectangles		[integer!]
    GetEffectRequiredInputRectangles [integer!]
    FillOpacityMask2				[integer!]
]

ID2D1GdiInteropRenderTarget: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetDC							[function! [this [this!] mode [integer!] hDC [ptr-ptr!] return: [integer!]]]
	ReleaseDC						[function! [this [this!] update [RECT_STRUCT] return: [integer!]]]
]

ID2D1HwndRenderTarget: alias struct! [
	ID2D1RenderTarget
	CheckWindowState				[function! [this [this!] return: [integer!]]]
	Resize							[Resize*]
	GetHwnd							[integer!]
]

ID2D1DCRenderTarget: alias struct! [
	ID2D1RenderTarget
	BindDC							[function! [this [this!] hDC [handle!] rect [RECT_STRUCT] return: [integer!]]]
]

ID2D1PathGeometry: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetFactory						[integer!]
	GetBounds						[function! [this [this!] trans [D2D_MATRIX_3X2_F] bounds [RECT_F!] return: [integer!]]]
	GetWidenedBounds				[integer!]
	StrokeContainsPoint				[integer!]
	FillContainsPoint				[integer!]
	CompareWithGeometry				[integer!]
	Simplify						[integer!]
	Tessellate						[integer!]
	CombineWithGeometry				[CombineWithGeometry*]
	Outline							[integer!]
	ComputeArea						[integer!]
	ComputeLength					[integer!]
	ComputePointAtLength			[integer!]
	Widen							[integer!]
	Open							[function! [this [this!] sink [ptr-ptr!] return: [integer!]]]
	Stream							[function! [this [this!] sink [ptr-ptr!] return: [integer!]]]
	GetSegmentCount					[function! [this [this!] count [int-ptr!] return: [integer!]]]
	GetFigureCount					[function! [this [this!] count [int-ptr!] return: [integer!]]]
]

ID2D1GeometrySink: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetFillMode						[function! [this [this!] fill_mode [integer!] return: [integer!]]]
	SetSegmentFlags					[function! [this [this!] vertexFlags [integer!] return: [integer!]]]
	BeginFigure						[function! [this [this!] startPoint [POINT_2F value] figureBegin [integer!] return: [integer!]]]
	AddLines						[function! [this [this!] points [POINT_2F] pointsCount [integer!] return: [integer!]]]
	AddBeziers						[function! [this [this!] beziers [D2D1_BEZIER_SEGMENT] beziersCount [integer!] return: [integer!]]]
	EndFigure						[function! [this [this!] figureEnd [integer!] return: [integer!]]]
	Close							[function! [this [this!] return: [integer!]]]
	AddLine							[function! [this [this!] point [POINT_2F value] return: [integer!]]]
	AddBezier						[function! [this [this!] beziers [D2D1_BEZIER_SEGMENT] return: [integer!]]]
	AddQuadraticBezier				[function! [this [this!] bezier [D2D1_QUADRATIC_BEZIER_SEGMENT] return: [integer!]]]
	AddQuadraticBeziers				[function! [this [this!] beziers [D2D1_QUADRATIC_BEZIER_SEGMENT] beziersCount [integer!] return: [integer!]]]
	AddArc							[function! [this [this!] arc [D2D1_ARC_SEGMENT] return: [integer!]]]
]

ID2D1StrokeStyle: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
]

;-- Direct Write

DWRITE_LINE_METRICS: alias struct! [
	length					 [integer!]
	trailingWhitespaceLength [integer!]
	newlineLength			 [integer!]
	height					 [float32!]
	baseline				 [float32!]
	isTrimmed				 [logic!]
]

DWRITE_TEXT_METRICS: alias struct! [
	left			[float32!]
	top				[float32!]
	width			[float32!]
	widthTrailing	[float32!]
	height			[float32!]
	layoutWidth		[float32!]
	layoutHeight	[float32!]
	maxBidiDepth	[integer!]
	lineCount		[integer!]
]

DWRITE_HIT_TEST_METRICS: alias struct! [
	textPosition	[integer!]
	length			[integer!]
	left			[float32!]
	top				[float32!]
	width			[float32!]
	height			[float32!]
	bidiLevel		[integer!]
	isText			[logic!]
	isTrimmed		[logic!]
]

CreateTextFormat*: alias function! [
	this		[this!]
	fontName	[c-string!]
	fontCollect [integer!]
	fontWeight	[integer!]
	fontStyle	[integer!]
	fontStretch	[integer!]
	fontSize	[float32!]
	localeName	[c-string!]
	textFormat	[com-ptr!]
	return:		[integer!]
]

CreateTextLayout*: alias function! [
	this		[this!]
	string		[c-string!]
	length		[integer!]
	format		[this!]
	maxWidth	[float32!]
	maxHeight	[float32!]
	layout		[com-ptr!]
	return:		[integer!]
]

HitTestPoint*: alias function! [
	this		[this!]
	x			[float32!]
	y			[float32!]
	isTrailing	[int-ptr!]
	isInside	[int-ptr!]
	metrics		[DWRITE_HIT_TEST_METRICS]
	return:		[integer!]
]

HitTestTextPosition*: alias function! [
	this		[this!]
	pos			[integer!]
	trailing?	[logic!]
	x			[float32-ptr!]
	y			[float32-ptr!]
	metrics		[DWRITE_HIT_TEST_METRICS]
	return:		[integer!]
]

HitTestTextRange*: alias function! [
	this		[this!]
	pos			[integer!]
	len			[integer!]
	x			[float32!]
	y			[float32!]
	metrics		[DWRITE_HIT_TEST_METRICS]
	max-cnt		[integer!]
	cnt			[int-ptr!]
	return:		[integer!]
]

SetIncrementalTabStop*: alias function! [
	this		[this!]
	size		[float32!]
	return:		[integer!]
]

SetLineSpacing*: alias function! [
	this		[this!]
	method		[integer!]
	lineSpacing [float32!]
	baseline	[float32!]
	return:		[integer!]
]

GetLineSpacing*: alias function! [
	this		[this!]
	method		[int-ptr!]
	lineSpacing [float32-ptr!]
	baseline	[float32-ptr!]
	return:		[integer!]
]

IDWriteFactory: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetSystemFontCollection			[integer!]
	CreateCustomFontCollection		[integer!]
	RegisterFontCollectionLoader	[integer!]
	UnregisterFontCollectionLoader	[integer!]
	CreateFontFileReference			[integer!]
	CreateCustomFontFileReference	[integer!]
	CreateFontFace					[integer!]
	CreateRenderingParams			[integer!]
	CreateMonitorRenderingParams	[integer!]
	CreateCustomRenderingParams		[integer!]
	RegisterFontFileLoader			[integer!]
	UnregisterFontFileLoader		[integer!]
	CreateTextFormat				[CreateTextFormat*]
	CreateTypography				[integer!]
	GetGdiInterop					[integer!]
	CreateTextLayout				[CreateTextLayout*]
	CreateGdiCompatibleTextLayout	[integer!]
	CreateEllipsisTrimmingSign		[integer!]
	CreateTextAnalyzer				[integer!]
	CreateNumberSubstitution		[integer!]
	CreateGlyphRunAnalysis			[integer!]
]

IDWriteRenderingParams: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetGamma						[integer!]
	GetEnhancedContrast				[integer!]
	GetClearTypeLevel				[integer!]
	GetPixelGeometry				[integer!]
	GetRenderingMode				[integer!]
]

IDWriteTextFormat: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetTextAlignment				[function! [this [this!] align [integer!] return: [integer!]]]
	SetParagraphAlignment			[function! [this [this!] align [integer!] return: [integer!]]]
	SetWordWrapping					[function! [this [this!] mode [integer!] return: [integer!]]]
	SetReadingDirection				[integer!]
	SetFlowDirection				[integer!]
	SetIncrementalTabStop			[SetIncrementalTabStop*]
	SetTrimming						[integer!]
	SetLineSpacing					[SetLineSpacing*]
	GetTextAlignment				[integer!]
	GetParagraphAlignment			[integer!]
	GetWordWrapping					[integer!]
	GetReadingDirection				[integer!]
	GetFlowDirection				[integer!]
	GetIncrementalTabStop			[integer!]
	GetTrimming						[integer!]
	GetLineSpacing					[GetLineSpacing*]
	GetFontCollection				[integer!]
	GetFontFamilyNameLength			[integer!]
	GetFontFamilyName				[integer!]
	GetFontWeight					[integer!]
	GetFontStyle					[integer!]
	GetFontStretch					[integer!]
	GetFontSize						[integer!]
	GetLocaleNameLength				[integer!]
	GetLocaleName					[integer!]
]

IDWriteTextLayout: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	SetTextAlignment				[function! [this [this!] align [integer!] return: [integer!]]]
	SetParagraphAlignment			[function! [this [this!] align [integer!] return: [integer!]]]
	SetWordWrapping					[function! [this [this!] mode [integer!] return: [integer!]]]
	SetReadingDirection				[integer!]
	SetFlowDirection				[integer!]
	SetIncrementalTabStop			[SetIncrementalTabStop*]
	SetTrimming						[integer!]
	SetLineSpacing					[SetLineSpacing*]
	GetTextAlignment				[integer!]
	GetParagraphAlignment			[integer!]
	GetWordWrapping					[integer!]
	GetReadingDirection				[integer!]
	GetFlowDirection				[integer!]
	GetIncrementalTabStop			[integer!]
	GetTrimming						[integer!]
	GetLineSpacing					[GetLineSpacing*]
	GetFontCollection				[integer!]
	GetFontFamilyNameLength			[integer!]
	GetFontFamilyName				[integer!]
	GetFontWeight					[integer!]
	GetFontStyle					[integer!]
	GetFontStretch					[integer!]
	GetFontSize						[integer!]
	GetLocaleNameLength				[integer!]
	GetLocaleName					[integer!]
	SetMaxWidth						[integer!]
	SetMaxHeight					[integer!]
	SetFontCollection				[integer!]
	SetFontFamilyName				[function! [this [this!] name [c-string!] pos [integer!] len [integer!] return: [integer!]]]
	SetFontWeight					[function! [this [this!] weight [integer!] pos [integer!] len [integer!] return: [integer!]]]
	SetFontStyle					[function! [this [this!] style [integer!] pos [integer!] len [integer!] return: [integer!]]]
	SetFontStretch					[integer!]
	SetFontSize						[function! [this [this!] size [float32!] pos [integer!] len [integer!] return: [integer!]]]
	SetUnderline					[function! [this [this!] underline? [logic!] pos [integer!] len [integer!] return: [integer!]]]
	SetStrikethrough				[function! [this [this!] strike? [logic!] pos [integer!] len [integer!] return: [integer!]]]
	SetDrawingEffect				[function! [this [this!] effect [this!] pos [integer!] len [integer!] return: [integer!]]]
	SetInlineObject					[function! [this [this!] obj [this!] pos [integer!] len [integer!] return: [integer!]]]
	SetTypography					[integer!]
	SetLocaleName					[integer!]
	GetMaxWidth						[integer!]
	GetMaxHeight					[integer!]
	GetFontCollection				[integer!]
	GetFontFamilyNameLength			[integer!]
	GetFontFamilyName				[integer!]
	GetFontWeight					[integer!]
	GetFontStyle					[integer!]
	GetFontStretch					[integer!]
	GetFontSize						[integer!]
	GetUnderline					[integer!]
	GetStrikethrough				[integer!]
	GetDrawingEffect				[integer!]
	GetInlineObject					[integer!]
	GetTypography					[integer!]
	GetLocaleNameLength				[integer!]
	GetLocaleName					[integer!]
	Draw							[integer!]
	GetLineMetrics					[function! [this [this!] metrics [DWRITE_LINE_METRICS] count [integer!] actual-count [int-ptr!] return: [integer!]]]
	GetMetrics						[function! [this [this!] metrics [DWRITE_TEXT_METRICS] return: [integer!]]]
	GetOverhangMetrics				[integer!]
	GetClusterMetrics				[integer!]
	DetermineMinWidth				[integer!]
	HitTestPoint					[HitTestPoint*]
	HitTestTextPosition				[HitTestTextPosition*]
	HitTestTextRange				[HitTestTextRange*]
]

IDWriteFontFace: alias struct! [
	QueryInterface					[QueryInterface!]
	AddRef							[AddRef!]
	Release							[Release!]
	GetType							[integer!]
	GetFiles						[integer!]
	GetIndex						[integer!]
	GetSimulations					[integer!]
	IsSymbolFont					[integer!]
	GetMetrics						[integer!]
	GetGlyphCount					[integer!]
	GetDesignGlyphMetrics			[integer!]
	GetGlyphIndices					[integer!]
	TryGetFontTable					[integer!]
	ReleaseFontTable				[integer!]
	GetGlyphRunOutline				[integer!]
	GetRecommendedRenderingMode		[integer!]
	GetGdiCompatibleMetrics			[integer!]
	GetGdiCompatibleGlyphMetrics	[integer!]
]

DCompositionCreateDevice2!: alias function! [
  	render-dev	[this!]
  	iid			[int-ptr!]
	device		[int-ptr!]
	return:		[integer!]
]

DXGIGetDebugInterface!: alias function! [
	iid			[int-ptr!]
	result		[com-ptr!]
	return:		[integer!]
]

D2D1CreateFactory!: alias function! [
	type		[integer!]
	riid		[int-ptr!]
	options		[int-ptr!]		;-- opt
	factory		[com-ptr!]
	return:		[integer!]
]

DWriteCreateFactory!: alias function! [
	type		[integer!]
	iid			[int-ptr!]
	factory		[com-ptr!]
	return:		[integer!]
]

GetUserDefaultLocaleName!: alias function! [
	lpLocaleName	[c-string!]
	cchLocaleName	[integer!]
	return:			[integer!]
]

#import [
	"d2d1.dll" stdcall [
		D2D1CreateFactory: "D2D1CreateFactory" [
			type		[integer!]
			riid		[int-ptr!]
			options		[int-ptr!]		;-- opt
			factory		[com-ptr!]
			return:		[integer!]
		]
		D2D1MakeRotateMatrix: "D2D1MakeRotateMatrix" [
			angle		[float32!]		;-- in degrees
			cx			[float32!]		;-- center x
			cy			[float32!]		;-- center y
			matrix		[D2D_MATRIX_3X2_F]
		]
		D2D1MakeSkewMatrix: "D2D1MakeSkewMatrix" [
			angleX		[float32!]		;-- in degrees
			angleY		[float32!]		;-- in degrees
			cx			[float32!]		;-- center x
			cy			[float32!]		;-- center y
			matrix		[D2D_MATRIX_3X2_F]
		]
		D2D1InvertMatrix: "D2D1InvertMatrix" [
			matrix		[D2D_MATRIX_3X2_F]
			return:		[logic!]
		]
	]
]