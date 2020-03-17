Red/System [
	Title:	"Animation related structures and functions"
	Author: "Xie Qingtian"
	File: 	%animation.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#enum animation-flags! [
	ANIM_STOP:		0
	ANIM_PLAYBACK:	1
	ANIM_REPEAT:	2
	ANIM_RUNNING:	4
]

#enum animation-type! [
	ANIM_TYPE_INT32
	ANIM_TYPE_FLOAT32
	ANIM_TYPE_SIZE
	ANIM_TYPE_OFFSET
	ANIM_TYPE_TUPLE
]

anim-property!: alias struct! [
	next		[anim-property!]
	ptr			[int-ptr!]			;-- point to a property of the gob
	sym			[integer!]
	type		[animation-type!]
	duration	[integer!]
	start		[int-ptr!]			;-- start value
	end			[int-ptr!]			;-- end value
]

animation!: alias struct! [
	gob			[gob!]				;-- animation in this gob
	flags		[animation-flags!]			
	exec		[int-ptr!]			;-- anim-function!
	ticks		[integer!]			;-- current animation ticks in ms
	properties	[anim-property!]
]

anim-function!: alias function! [
	anim		[animation!]
]

#define NEW_ANIM_PROPERTY(data-size) [as anim-property! alloc0 data-size + size? anim-property!]

#define ANIM_RESOLUTION 1024
#define ANIM_RES_SHIFT 10

cubic-bezier: func [
	t		[uint!]
	u0		[integer!]
	u1		[integer!]
	u2		[integer!]
	u3		[integer!]
	return: [integer!]
	/local
		rem	[uint!]
		rem2 [uint!]
		rem3 [uint!]
		t2	[uint!]
		t3	[uint!]
		v1	[uint!]
		v2	[uint!]
		v3	[uint!]
		v4	[uint!]
][
	rem: 1024 - t
	rem2: rem * rem >> 10
	rem3: rem2 * rem >> 10
	t2: t * t >> 10
	t3: t2 * t >> 10

	v1: rem3 * u0 >> 10
	v2: 3 * rem2 * t * u1 >> 20
	v3: 3 * rem * t2 * u2 >> 20
	v4: t3 * u3 >> 10

	v1 + v2 + v3 + v4
]

animation: context [
	anim-list:	as node! 0

	init: func [][
		anim-list: array/make 32 size? int-ptr!
	]

	add: func [anim [animation!]][
		array/append-ptr anim-list as int-ptr! anim
	]

	;timing-linear-f32: func [
		
	;	start		[float32!]
	;	end			[float32!]
	;	return:		[float32!]
	;	/local
	;		val		[float32!]
	;		step
	;][
		
	;]

	run: func [
		anim		[animation!]
		elaps		[integer!]
		/local
			timing-func [anim-function!]
			prop	[anim-property!]
			sym		[integer!]
			g		[gob!]
			t		[integer!]
			new		[integer!]
			pf		[float32-ptr!]
			p-int	[int-ptr!]
	][
		if zero? anim/flags [exit]			;-- stopped

		timing-func: as anim-function! anim/exec
		g: anim/gob
		prop: anim/properties
		sym: prop/sym
		anim/ticks: anim/ticks + elaps

		either anim/ticks >= prop/duration [
			t: ANIM_RESOLUTION
			anim/flags: ANIM_STOP
			anim/ticks: 0
		][
			t: anim/ticks * ANIM_RESOLUTION / prop/duration
		]

		case [
			sym = facets/size [
				t: cubic-bezier t 0 1 1 1024
				p-int: :prop/start
				new: p-int/3 - p-int/1
				new: t * new >> 10 + p-int/1	;-- new width
				g/box/right: g/box/left + as-float32 new

				new: p-int/4 - p-int/2
				new: t * new >> 10 + p-int/2	;-- new height
				g/box/bottom: g/box/top + as-float32 new
			]
		]
		ui-manager/redraw
	]

	run-all: func [
		elaps		[integer!]
		/local
			s		[series!]
			p		[ptr-ptr!]
			e		[ptr-ptr!]
	][
		s: as series! anim-list/value
		p: as ptr-ptr! s/offset
		e: as ptr-ptr! s/tail
		while [p < e][
			run as animation! p/value elaps
			p: p + 1
		]
	]

	set-property: func [
		g		[gob!]
		prop	[anim-property!]
		sym		[integer!]
		end?	[logic!]
		/local
			pf	[float32-ptr!]
			pint [int-ptr!]
	][
		case [
			sym = facets/size [
				pint: :prop/start
				if end? [pint: pint + 2]
				pint/1: as-integer g/box/right - g/box/left
				pint/2: as-integer g/box/bottom - g/box/top
			]
			true [0]
		]
	]

	check: func [
		g		[gob!]
		val		[red-value!]
		sym		[integer!]
		return: [anim-property!]
		/local
			s		[series!]
			p		[ptr-ptr!]
			e		[ptr-ptr!]
			anim	[animation!]
			prop	[anim-property!]
	][
		s: as series! anim-list/value
		p: as ptr-ptr! s/offset
		e: as ptr-ptr! s/tail
		while [p < e][
			anim: as animation! p/value
			if anim/gob = g [
				prop: anim/properties
				while [prop <> null][
					if prop/sym = sym [
						set-property g prop sym no
						anim/flags: ANIM_RUNNING
						return prop
					]
					prop: prop/next
				]
			]
			p: p + 1
		]
		null
	]
]

parse-transition: func [
	gob		[gob!]
	cmds	[red-block!]
	/local
		anim	[animation!]
		cmd		[red-value!]
		tail	[red-value!]
		start	[red-value!]
		word	[red-word!]
		sym		[integer!]
		nprop	[integer!]
		prop	[anim-property!]
		new		[anim-property!]
		t		[float32!]
][
	anim: as animation! alloc0 size? animation!
	anim/gob: gob

	cmd:  block/rs-head cmds
	tail: block/rs-tail cmds

	while [cmd < tail][
		switch TYPE_OF(cmd) [
			TYPE_WORD [
				word: as red-word! cmd
				sym: symbol/resolve word/symbol
				start: cmd + 1
				case [
					sym = facets/size [
						new: NEW_ANIM_PROPERTY(16)		;-- 2 * size? WxH
						new/sym: sym
						new/ptr: :gob/box
						new/type: ANIM_TYPE_SIZE
					]
					true [0]
				]
				either null? anim/properties [
					anim/properties: new
				][
					prop/next: new
				]
				prop: new
			]
			TYPE_INTEGER TYPE_FLOAT [
				t: get-float32 as red-integer! cmd
				prop/duration: as-integer t * as float32! 1000.0	;-- convert to ms
			]
			default [0]
		]
		cmd: cmd + 1
	]

	animation/add anim
]