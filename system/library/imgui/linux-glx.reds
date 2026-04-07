Red/System [
	Title:   "Red/System imgui GLX/OpenGL renderer"
	Author:  "OpenAI"
	File: 	 %linux-glx.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %pixel-renderer.reds

#switch OS [
	#default [
		#define IMGUI-X11-file "libX11.so.6"
		#define IMGUI-GL-file  "libGL.so.1"
	]
]

#define ExposureMask         32768
#define KeyPressMask         1
#define ButtonPressMask      4
#define ButtonReleaseMask    8
#define PointerMotionMask    64
#define StructureNotifyMask  131072

#define KeyPress-type        2
#define ButtonPress-type     4
#define ButtonRelease-type   5
#define MotionNotify-type    6
#define Expose-type          12
#define DestroyNotify-type   17

#define Button1Mask          256

#define XK-Left              65361
#define XK-Right             65363
#define XK-Escape            65307

#define GLX_RGBA             4
#define GLX_DOUBLEBUFFER     5
#define GLX_RED_SIZE         8
#define GLX_GREEN_SIZE       9
#define GLX_BLUE_SIZE        10
#define GLX_DEPTH_SIZE       12

#define InputOutput          1
#define AllocNone            0
#define CWEventMask          2048
#define CWColormap           8192

#define GL_COLOR_BUFFER_BIT  16384h
#define GL_SCISSOR_TEST      0C11h
#define GL_PROJECTION        1701h
#define GL_MODELVIEW         1700h
#define GL_VERTEX_ARRAY      8074h
#define GL_COLOR_ARRAY       8076h
#define GL_TEXTURE_COORD_ARRAY 8078h
#define GL_TEXTURE_2D        0DE1h
#define GL_TEXTURE_MIN_FILTER 2801h
#define GL_TEXTURE_MAG_FILTER 2800h
#define GL_TEXTURE_WRAP_S    2802h
#define GL_TEXTURE_WRAP_T    2803h
#define GL_TEXTURE0          84C0h
#define GL_NEAREST           2600h
#define GL_LINEAR            2601h
#define GL_CLAMP_TO_EDGE     812Fh
#define GL_BLEND             0BE2h
#define GL_SRC_ALPHA         0302h
#define GL_ONE_MINUS_SRC_ALPHA 0303h
#define GL_RGBA              1908h
#define GL_BGRA              80E1h
#define GL_UNSIGNED_BYTE     1401h
#define GL_UNSIGNED_INT      1405h
#define GL_FLOAT             1406h
#define GL_QUADS             7
#define GL_TRIANGLES         4
#define GL_ARRAY_BUFFER      8892h
#define GL_ELEMENT_ARRAY_BUFFER 8893h
#define GL_DYNAMIC_DRAW      88E8h
#define GL_VERTEX_SHADER     8B31h
#define GL_FRAGMENT_SHADER   8B30h
#define GL_COMPILE_STATUS    8B81h
#define GL_LINK_STATUS       8B82h
#define GL_INFO_LOG_LENGTH   8B84h
#define GL_CURRENT_PROGRAM   8B8Dh
#define GL_TEXTURE_BINDING_2D 8069h
#define GL_ARRAY_BUFFER_BINDING 8894h
#define GL_ELEMENT_ARRAY_BUFFER_BINDING 8895h

#define x-display!           [pointer! [integer!]]
#define x-visual!            [pointer! [integer!]]
#define glx-context!         [pointer! [integer!]]

#define IMGUI-GL-MAX-VERTICES 65536
#define IMGUI-GL-MAX-INDICES  98304
#define IMGUI-GL-MAX-BATCHES  2048
#define IMGUI-GL-ATLAS-W      128
#define IMGUI-GL-ATLAS-H      128

gl-vertex!: alias struct! [
	x [float!]
	y [float!]
	u [float!]
	v [float!]
	r [byte!]
	g [byte!]
	b [byte!]
	a [byte!]
]


x-visual-info!: alias struct! [
	visual        [x-visual!]
	visualid      [integer!]
	screen        [integer!]
	depth         [integer!]
	class         [integer!]
	red-mask      [integer!]
	green-mask    [integer!]
	blue-mask     [integer!]
	colormap-size [integer!]
	bits-per-rgb  [integer!]
]

x-set-window-attributes!: alias struct! [
	background-pixmap      [integer!]
	background-pixel       [integer!]
	border-pixmap          [integer!]
	border-pixel           [integer!]
	bit-gravity            [integer!]
	win-gravity            [integer!]
	backing-store          [integer!]
	backing-planes         [integer!]
	backing-pixel          [integer!]
	save-under             [integer!]
	event-mask             [integer!]
	do-not-propagate-mask  [integer!]
	override-redirect      [integer!]
	colormap               [integer!]
	cursor                 [integer!]
]

#import [
	IMGUI-X11-file cdecl [
		XOpenDisplay: "XOpenDisplay" [name [c-string!] return: [x-display!]]
		XDefaultScreen: "XDefaultScreen" [display [x-display!] return: [integer!]]
		XRootWindow: "XRootWindow" [display [x-display!] screen [integer!] return: [integer!]]
		XCreateColormap: "XCreateColormap" [
			display  [x-display!]
			window   [integer!]
			visual   [x-visual!]
			alloc    [integer!]
			return:  [integer!]
		]
		XCreateWindow: "XCreateWindow" [
			display       [x-display!]
			parent        [integer!]
			x             [integer!]
			y             [integer!]
			width         [integer!]
			height        [integer!]
			border-width  [integer!]
			depth         [integer!]
			class         [integer!]
			visual        [x-visual!]
			valuemask     [integer!]
			attributes    [x-set-window-attributes!]
			return:       [integer!]
		]
		XStoreName: "XStoreName" [display [x-display!] window [integer!] name [c-string!] return: [integer!]]
		XMapWindow: "XMapWindow" [display [x-display!] window [integer!] return: [integer!]]
		XNextEvent: "XNextEvent" [display [x-display!] event [byte-ptr!] return: [integer!]]
		XQueryPointer: "XQueryPointer" [
			display [x-display!] window [integer!]
			root-return [int-ptr!] child-return [int-ptr!]
			root-x [int-ptr!] root-y [int-ptr!]
			win-x [int-ptr!] win-y [int-ptr!]
			mask-return [int-ptr!]
			return: [integer!]
		]
		XLookupString: "XLookupString" [
			event-buffer [byte-ptr!]
			buffer       [byte-ptr!]
			bytes        [integer!]
			keysym       [int-ptr!]
			status       [byte-ptr!]
			return:      [integer!]
		]
		XDestroyWindow: "XDestroyWindow" [display [x-display!] window [integer!] return: [integer!]]
		XCloseDisplay: "XCloseDisplay" [display [x-display!] return: [integer!]]
	]
	IMGUI-GL-file cdecl [
		glXChooseVisual: "glXChooseVisual" [
			display [x-display!]
			screen  [integer!]
			attribs [int-ptr!]
			return: [x-visual-info!]
		]
		glXCreateContext: "glXCreateContext" [
			display [x-display!]
			vis     [x-visual-info!]
			share   [glx-context!]
			direct? [integer!]
			return: [glx-context!]
		]
		glXMakeCurrent: "glXMakeCurrent" [
			display [x-display!]
			drawable [integer!]
			ctx     [glx-context!]
			return: [integer!]
		]
		glXSwapBuffers: "glXSwapBuffers" [
			display [x-display!]
			drawable [integer!]
		]
		glXDestroyContext: "glXDestroyContext" [
			display [x-display!]
			ctx     [glx-context!]
		]
			glViewport: "glViewport" [x [integer!] y [integer!] width [integer!] height [integer!]]
			glScissor: "glScissor" [x [integer!] y [integer!] width [integer!] height [integer!]]
			glMatrixMode: "glMatrixMode" [mode [integer!]]
		glLoadIdentity: "glLoadIdentity" []
		glOrtho: "glOrtho" [left [float!] right [float!] bottom [float!] top [float!] nearv [float!] farv [float!]]
		glEnable: "glEnable" [cap [integer!]]
		glDisable: "glDisable" [cap [integer!]]
		glBlendFunc: "glBlendFunc" [src [integer!] dst [integer!]]
		glClearColor: "glClearColor" [r [float32!] g [float32!] b [float32!] a [float32!]]
		glClear: "glClear" [mask [integer!]]
		glGenTextures: "glGenTextures" [n [integer!] textures [int-ptr!]]
		glBindTexture: "glBindTexture" [target [integer!] texture [integer!]]
		glTexParameteri: "glTexParameteri" [target [integer!] pname [integer!] param [integer!]]
		glTexImage2D: "glTexImage2D" [
			target [integer!] level [integer!] internal [integer!]
			width [integer!] height [integer!] border [integer!]
			format [integer!] type [integer!] pixels [byte-ptr!]
		]
		glTexSubImage2D: "glTexSubImage2D" [
			target [integer!] level [integer!] xoff [integer!] yoff [integer!]
			width [integer!] height [integer!] format [integer!] type [integer!] pixels [byte-ptr!]
		]
		glActiveTexture: "glActiveTexture" [texture [integer!]]
		glCreateShader: "glCreateShader" [kind [integer!] return: [integer!]]
		glShaderSource: "glShaderSource" [shader [integer!] count [integer!] strings [int-ptr!] lengths [int-ptr!]]
		glCompileShader: "glCompileShader" [shader [integer!]]
		glCreateProgram: "glCreateProgram" [return: [integer!]]
		glAttachShader: "glAttachShader" [program [integer!] shader [integer!]]
		glBindAttribLocation: "glBindAttribLocation" [program [integer!] index [integer!] name [c-string!]]
		glLinkProgram: "glLinkProgram" [program [integer!]]
		glUseProgram: "glUseProgram" [program [integer!]]
		glGetUniformLocation: "glGetUniformLocation" [program [integer!] name [c-string!] return: [integer!]]
		glUniform1i: "glUniform1i" [location [integer!] value [integer!]]
		glUniform2f: "glUniform2f" [location [integer!] x [float32!] y [float32!]]
		glGetShaderiv: "glGetShaderiv" [shader [integer!] pname [integer!] params [int-ptr!]]
		glGetProgramiv: "glGetProgramiv" [program [integer!] pname [integer!] params [int-ptr!]]
		glGetShaderInfoLog: "glGetShaderInfoLog" [shader [integer!] bufsize [integer!] length [int-ptr!] infolog [byte-ptr!]]
		glGetProgramInfoLog: "glGetProgramInfoLog" [program [integer!] bufsize [integer!] length [int-ptr!] infolog [byte-ptr!]]
		glGetIntegerv: "glGetIntegerv" [pname [integer!] params [int-ptr!]]
		glIsEnabled: "glIsEnabled" [cap [integer!] return: [byte!]]
		glGenBuffers: "glGenBuffers" [n [integer!] buffers [int-ptr!]]
		glBindBuffer: "glBindBuffer" [target [integer!] buffer [integer!]]
		glBufferData: "glBufferData" [target [integer!] size [integer!] data [byte-ptr!] usage [integer!]]
		glEnableVertexAttribArray: "glEnableVertexAttribArray" [index [integer!]]
		glDisableVertexAttribArray: "glDisableVertexAttribArray" [index [integer!]]
		glVertexAttribPointer: "glVertexAttribPointer" [
			index [integer!] size [integer!] type [integer!] normalized [integer!]
			stride [integer!] pointer [byte-ptr!]
		]
		glDrawElements: "glDrawElements" [mode [integer!] count [integer!] type [integer!] indices [byte-ptr!]]
		glBegin: "glBegin" [mode [integer!]]
		glEnd: "glEnd" []
		glTexCoord2d: "glTexCoord2d" [s [float!] t [float!]]
		glVertex2d: "glVertex2d" [x [float!] y [float!]]
		glColor4ub: "glColor4ub" [r [byte!] g [byte!] b [byte!] a [byte!]]
		glDeleteProgram: "glDeleteProgram" [program [integer!]]
		glDeleteShader: "glDeleteShader" [shader [integer!]]
		glDeleteBuffers: "glDeleteBuffers" [n [integer!] buffers [int-ptr!]]
		glDeleteTextures: "glDeleteTextures" [n [integer!] textures [int-ptr!]]
	]
]

imgui-glx: context [
	display: as x-display! 0
	screen: 0
	window: 0
	gl-context: as glx-context! 0
	visual-info: as x-visual-info! 0
		event-buf: as byte-ptr! 0
		key-buf: as byte-ptr! 0
		white-texture-id: 0
		atlas-texture-id: 0
		shader-program: 0
		vertex-shader: 0
		fragment-shader: 0
		vbo-id: 0
		ibo-id: 0
		screen-uniform: 0
		texture-uniform: 0
		vertex-buffer: as byte-ptr! 0
		index-buffer: as int-ptr! 0
		atlas-buffer: as byte-ptr! 0
		log-buffer: as byte-ptr! 0
	frame-width: 0
	frame-height: 0
	mouse-x: 0
	mouse-y: 0
	mouse-down?: no

	setup-projection: does [
		glViewport 0 0 frame-width frame-height
		glMatrixMode GL_PROJECTION
		glLoadIdentity
		glOrtho 0.0 as float! frame-width as float! frame-height 0.0 -1.0 1.0
		glMatrixMode GL_MODELVIEW
		glLoadIdentity
	]

	get-gl-texture: func [
		texture-id [integer!]
		return: [integer!]
	][
		either zero? texture-id [white-texture-id][atlas-texture-id]
	]

	check-shader: func [
		shader [integer!]
		label  [c-string!]
		return: [logic!]
		/local ok len [integer!]
	][
		ok: 0
		len: 0
		glGetShaderiv shader GL_COMPILE_STATUS :ok
		if ok <> 0 [return yes]
		glGetShaderiv shader GL_INFO_LOG_LENGTH :len
		if all [len > 0 null? log-buffer][log-buffer: allocate 2048]
		if all [len > 0 not null? log-buffer][
			glGetShaderInfoLog shader 2047 :len log-buffer
			print label
			print ": "
			print-line as c-string! log-buffer
		]
		no
	]

	check-program: func [
		program [integer!]
		label   [c-string!]
		return: [logic!]
		/local ok len [integer!]
	][
		ok: 0
		len: 0
		glGetProgramiv program GL_LINK_STATUS :ok
		if ok <> 0 [return yes]
		glGetProgramiv program GL_INFO_LOG_LENGTH :len
		if all [len > 0 null? log-buffer][log-buffer: allocate 2048]
		if all [len > 0 not null? log-buffer][
			glGetProgramInfoLog program 2047 :len log-buffer
			print label
			print ": "
			print-line as c-string! log-buffer
		]
		no
	]

	build-font-atlas: func [
		/local
			i [integer!]
			ch [integer!]
			cell-x [integer!]
			cell-y [integer!]
			row [integer!]
			col [integer!]
			bits [integer!]
			pix [integer!]
			pix2 [integer!]
			pix3 [integer!]
			pix4 [integer!]
	][
		i: 0
		if null? atlas-buffer [atlas-buffer: allocate (IMGUI-GL-ATLAS-W * IMGUI-GL-ATLAS-H * 4)]
		set-memory atlas-buffer null-byte (IMGUI-GL-ATLAS-W * IMGUI-GL-ATLAS-H * 4)
		atlas-buffer/1: as byte! 255
		atlas-buffer/2: as byte! 255
		atlas-buffer/3: as byte! 255
		atlas-buffer/4: as byte! 255
		ch: 32
		while [ch < 128][
			cell-x: ((ch - 32) % 16) * 8
			cell-y: ((ch - 32) / 16) * 8 + 8
			row: 0
			while [row < 7][
				bits: imgui-pixel-renderer/glyph-row as byte! ch row
				col: 0
				while [col < 5][
					if bits and (1 << (4 - col)) <> 0 [
						pix: (((cell-y + row) * IMGUI-GL-ATLAS-W) + cell-x + col) * 4 + 1
						pix2: pix + 1
						pix3: pix + 2
						pix4: pix + 3
						atlas-buffer/pix: as byte! 255
						atlas-buffer/pix2: as byte! 255
						atlas-buffer/pix3: as byte! 255
						atlas-buffer/pix4: as byte! 255
					]
					col: col + 1
				]
				row: row + 1
			]
			ch: ch + 1
		]
	]

	create-gpu-objects: func [
		/local
			white-pixel [byte-ptr!]
			vertex-src [c-string!]
			fragment-src [c-string!]
			src-list [int-ptr!]
	][
		if null? vertex-buffer [vertex-buffer: allocate (IMGUI-GL-MAX-VERTICES * size? gl-vertex!)]
		if null? index-buffer [index-buffer: as int-ptr! allocate (IMGUI-GL-MAX-INDICES * size? integer!)]
		build-font-atlas
		if zero? white-texture-id [
			white-pixel: as byte-ptr! allocate 4
			white-pixel/1: as byte! 255
			white-pixel/2: as byte! 255
			white-pixel/3: as byte! 255
			white-pixel/4: as byte! 255
			glGenTextures 1 :white-texture-id
			glBindTexture GL_TEXTURE_2D white-texture-id
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_CLAMP_TO_EDGE
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_CLAMP_TO_EDGE
			glTexImage2D GL_TEXTURE_2D 0 GL_RGBA 1 1 0 GL_BGRA GL_UNSIGNED_BYTE white-pixel
		]
		if zero? atlas-texture-id [
			glGenTextures 1 :atlas-texture-id
			glBindTexture GL_TEXTURE_2D atlas-texture-id
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_CLAMP_TO_EDGE
			glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_CLAMP_TO_EDGE
			glTexImage2D GL_TEXTURE_2D 0 GL_RGBA IMGUI-GL-ATLAS-W IMGUI-GL-ATLAS-H 0 GL_BGRA GL_UNSIGNED_BYTE atlas-buffer
		]
		if zero? shader-program [
			vertex-src: "#version 120^/attribute vec2 Position;^/attribute vec2 UV;^/attribute vec4 Color;^/uniform vec2 ScreenSize;^/varying vec2 Frag_UV;^/varying vec4 Frag_Color;^/void main(){vec2 p=Position/ScreenSize*2.0-1.0;gl_Position=vec4(p.x,-p.y,0.0,1.0);Frag_UV=UV;Frag_Color=Color;}"
			fragment-src: "#version 120^/uniform sampler2D Texture;^/varying vec2 Frag_UV;^/varying vec4 Frag_Color;^/void main(){gl_FragColor=Frag_Color*texture2D(Texture,Frag_UV);}"
			src-list: as int-ptr! allocate size? integer!
			src-list/1: as integer! vertex-src
			vertex-shader: glCreateShader GL_VERTEX_SHADER
			glShaderSource vertex-shader 1 src-list as int-ptr! 0
			glCompileShader vertex-shader
			check-shader vertex-shader "vertex-shader"
			src-list/1: as integer! fragment-src
			fragment-shader: glCreateShader GL_FRAGMENT_SHADER
			glShaderSource fragment-shader 1 src-list as int-ptr! 0
			glCompileShader fragment-shader
			check-shader fragment-shader "fragment-shader"
			shader-program: glCreateProgram
			glAttachShader shader-program vertex-shader
			glAttachShader shader-program fragment-shader
			glBindAttribLocation shader-program 0 "Position"
			glBindAttribLocation shader-program 1 "UV"
			glBindAttribLocation shader-program 2 "Color"
			glLinkProgram shader-program
			check-program shader-program "shader-program"
			screen-uniform: glGetUniformLocation shader-program "ScreenSize"
			texture-uniform: glGetUniformLocation shader-program "Texture"
		]
		if zero? vbo-id [glGenBuffers 1 :vbo-id]
		if zero? ibo-id [glGenBuffers 1 :ibo-id]
	]

	render-draw-list: func [
		/local
			i [integer!]
			list-index [integer!]
			list-end [integer!]
			list [imdraw-list!]
			cmd [imdraw-cmd!]
			sx [integer!]
			sy [integer!]
			sw [integer!]
			sh [integer!]
			last-program [integer!]
			last-texture [integer!]
			last-array-buffer [integer!]
			last-element-buffer [integer!]
			blend-was-enabled [logic!]
		][
			create-gpu-objects
			imgui/build-draw-data
			last-program: 0
			last-texture: 0
			last-array-buffer: 0
			last-element-buffer: 0
			glGetIntegerv GL_CURRENT_PROGRAM :last-program
			glGetIntegerv GL_TEXTURE_BINDING_2D :last-texture
			glGetIntegerv GL_ARRAY_BUFFER_BINDING :last-array-buffer
			glGetIntegerv GL_ELEMENT_ARRAY_BUFFER_BINDING :last-element-buffer
			blend-was-enabled: (as integer! (glIsEnabled GL_BLEND)) <> 0
			glClearColor as float32! 0.08 as float32! 0.10 as float32! 0.13 as float32! 1.0
			glClear GL_COLOR_BUFFER_BIT
			setup-projection

			glEnable GL_SCISSOR_TEST
			glEnable GL_BLEND
			glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
			glUseProgram shader-program
			glUniform2f screen-uniform as float32! frame-width as float32! frame-height
			glActiveTexture GL_TEXTURE0
			glBindBuffer GL_ARRAY_BUFFER vbo-id
			glBufferData GL_ARRAY_BUFFER (imgui/mesh-vtx-count? * size? imdraw-vert!) imgui/mesh-verts GL_DYNAMIC_DRAW
			glBindBuffer GL_ELEMENT_ARRAY_BUFFER ibo-id
			glBufferData GL_ELEMENT_ARRAY_BUFFER (imgui/mesh-idx-count? * size? integer!) as byte-ptr! imgui/mesh-indices GL_DYNAMIC_DRAW
			glEnableVertexAttribArray 0
			glEnableVertexAttribArray 1
			glEnableVertexAttribArray 2
			glVertexAttribPointer 0 2 GL_FLOAT 0 (size? imdraw-vert!) as byte-ptr! 0
			glVertexAttribPointer 1 2 GL_FLOAT 0 (size? imdraw-vert!) as byte-ptr! 8
			glVertexAttribPointer 2 4 GL_UNSIGNED_BYTE 1 (size? imdraw-vert!) as byte-ptr! 16
			list-index: 0
			while [list-index < imgui/mesh-list-count?][
				list: imgui/mesh-list list-index
				i: list/cmd-offset
				list-end: list/cmd-offset + list/cmd-count
				while [i < list-end][
					cmd: imgui/mesh-cmd i
				sx: as integer! cmd/clip-x1
				sy: frame-height - as integer! cmd/clip-y2
				sw: as integer! (cmd/clip-x2 - cmd/clip-x1)
				sh: as integer! (cmd/clip-y2 - cmd/clip-y1)
				if sw < 0 [sw: 0]
				if sh < 0 [sh: 0]
				glScissor sx sy sw sh
				glBindTexture GL_TEXTURE_2D get-gl-texture cmd/texture-id
				glUniform1i texture-uniform 0
				glDrawElements GL_TRIANGLES cmd/elem-count GL_UNSIGNED_INT as byte-ptr! (cmd/idx-offset * size? integer!)
				i: i + 1
				]
				list-index: list-index + 1
			]
			glDisableVertexAttribArray 0
			glDisableVertexAttribArray 1
			glDisableVertexAttribArray 2
			glUseProgram 0
			if not blend-was-enabled [glDisable GL_BLEND]
			glDisable GL_SCISSOR_TEST
			glBindBuffer GL_ARRAY_BUFFER last-array-buffer
			glBindBuffer GL_ELEMENT_ARRAY_BUFFER last-element-buffer
			glBindTexture GL_TEXTURE_2D last-texture
			glUseProgram last-program
			glXSwapBuffers display window
		]

	query-pointer: func [
		return: [logic!]
		/local
			root-ret [integer!]
			child-ret [integer!]
			root-x [integer!]
			root-y [integer!]
			win-x [integer!]
			win-y [integer!]
			mask-ret [integer!]
			ok [integer!]
	][
		root-ret: 0 child-ret: 0 root-x: 0 root-y: 0 win-x: 0 win-y: 0 mask-ret: 0
		ok: XQueryPointer display window :root-ret :child-ret :root-x :root-y :win-x :win-y :mask-ret
		if zero? ok [return no]
		mouse-x: win-x
		mouse-y: win-y
		mouse-down?: mask-ret and Button1Mask <> 0
		yes
	]

	handle-keypress: func [
		return: [logic!]
		/local
			keysym [integer!]
			n [integer!]
			ch [byte!]
			close? [logic!]
			tab? [logic!]
			activate? [logic!]
			left? [logic!]
			right? [logic!]
	][
		if null? key-buf [key-buf: allocate 8]
		keysym: 0
		n: XLookupString event-buf key-buf 7 :keysym null
		ch: either n > 0 [key-buf/1][null-byte]
		close?: any [keysym = XK-Escape ch = as byte! 27]
		tab?: ch = as byte! 9
		activate?: any [ch = as byte! 13 ch = as byte! 32]
		left?: keysym = XK-Left
		right?: keysym = XK-Right
		imgui/set-key-state tab? activate? left? right?
		close?
	]

	sync-imgui-mouse: func [pressed? [logic!]][
		query-pointer
		imgui/set-mouse-state as float! mouse-x as float! mouse-y mouse-down? pressed?
	]

	open-window: func [
		title [c-string!]
		width [integer!]
		height [integer!]
		return: [logic!]
		/local
			root [integer!]
			attribs [int-ptr!]
			attrs [x-set-window-attributes!]
			mask [integer!]
	][
		display: XOpenDisplay null
		if null? display [return no]
		screen: XDefaultScreen display
		attribs: as int-ptr! allocate (12 * size? integer!)
		attrs: declare x-set-window-attributes!
		attribs/1: GLX_RGBA
		attribs/2: GLX_DOUBLEBUFFER
		attribs/3: GLX_RED_SIZE
		attribs/4: 8
		attribs/5: GLX_GREEN_SIZE
		attribs/6: 8
		attribs/7: GLX_BLUE_SIZE
		attribs/8: 8
		attribs/9: GLX_DEPTH_SIZE
		attribs/10: 24
		attribs/11: 0
		visual-info: glXChooseVisual display screen attribs
		if null? visual-info [
			XCloseDisplay display
			return no
		]
		root: XRootWindow display screen
		set-memory as byte-ptr! attrs null-byte size? x-set-window-attributes!
		attrs/colormap: XCreateColormap display root visual-info/visual AllocNone
		mask: ExposureMask or KeyPressMask or ButtonPressMask or ButtonReleaseMask or PointerMotionMask or StructureNotifyMask
		attrs/event-mask: mask
		window: XCreateWindow display root 40 40 width height 0 visual-info/depth InputOutput visual-info/visual (CWColormap or CWEventMask) attrs
		if zero? window [
			XCloseDisplay display
			return no
		]
		gl-context: glXCreateContext display visual-info as glx-context! 0 1
		if null? gl-context [
			XDestroyWindow display window
			XCloseDisplay display
			return no
		]
		glXMakeCurrent display window gl-context
		frame-width: width
		frame-height: height
		imgui-pixel-renderer/clear width height
		XStoreName display window title
		XMapWindow display window
		if null? event-buf [event-buf: allocate 256]
		white-texture-id: 0
		atlas-texture-id: 0
		mouse-x: 0
		mouse-y: 0
		mouse-down?: no
		yes
	]

	wait-event: func [return: [integer!] /local type-ptr [int-ptr!]][
		type-ptr: as int-ptr! event-buf
		XNextEvent display event-buf
		type-ptr/value
	]

	close-window: does [
		if white-texture-id <> 0 [glDeleteTextures 1 :white-texture-id white-texture-id: 0]
		if atlas-texture-id <> 0 [glDeleteTextures 1 :atlas-texture-id atlas-texture-id: 0]
		if vbo-id <> 0 [glDeleteBuffers 1 :vbo-id vbo-id: 0]
		if ibo-id <> 0 [glDeleteBuffers 1 :ibo-id ibo-id: 0]
		if shader-program <> 0 [glDeleteProgram shader-program shader-program: 0]
		if vertex-shader <> 0 [glDeleteShader vertex-shader vertex-shader: 0]
		if fragment-shader <> 0 [glDeleteShader fragment-shader fragment-shader: 0]
		glXMakeCurrent display 0 as glx-context! 0
		glXDestroyContext display gl-context
		XDestroyWindow display window
		XCloseDisplay display
	]
]
