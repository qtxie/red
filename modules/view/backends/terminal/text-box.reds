Red/System [
	Title:	"Text Box Windows DirectWrite Backend"
	Author: "Xie Qingtian"
	File: 	%text-box.reds
	Tabs: 	4
	Dependency: %draw.reds
	Rights: "Copyright (C) 2023 Xie Qingtian. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define TBOX_METRICS_OFFSET?		0
#define TBOX_METRICS_INDEX?			1
#define TBOX_METRICS_LINE_HEIGHT	2
#define TBOX_METRICS_SIZE			3
#define TBOX_METRICS_LINE_COUNT		4
#define TBOX_METRICS_CHAR_INDEX?	5
#define TBOX_METRICS_OFFSET_LOWER	6

OS-text-box-color: func [
	target	[handle!]
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	color	[integer!]
][
]

OS-text-box-background: func [
	target	[handle!]
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	color	[integer!]
][
]

OS-text-box-weight: func [
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	weight	[integer!]
][
]

OS-text-box-italic: func [
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
][
]

OS-text-box-underline: func [
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	opts	[red-value!]					;-- options
	tail	[red-value!]
][
]

OS-text-box-strikeout: func [
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	opts	[red-value!]					;-- options
	tail	[red-value!]
][
]

OS-text-box-border: func [
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	opts	[red-value!]					;-- options
	tail	[red-value!]
][
	0
]

OS-text-box-font-name: func [
	font	[handle!]
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	name	[red-string!]
][
]

OS-text-box-font-size: func [
	font	[handle!]
	layout	[handle!]
	pos		[integer!]
	len		[integer!]
	size	[float!]
][
]

OS-text-box-metrics: func [
	state	[red-block!]
	arg0	[red-value!]
	type	[integer!]
	return: [red-value!]
][
	null
]

OS-text-box-layout: func [
	box		[red-object!]
	target	[handle!]
	ft-clr	[integer!]
	catch?	[logic!]
	return: [handle!]
][
	null
]

txt-box-draw-background: func [
	target	[int-ptr!]
	pos		[red-pair!]
	layout	[handle!]
][
]

adjust-index: func [
	str		[red-string!]
	offset	[integer!]
	idx		[integer!]
	adjust	[integer!]
	return: [integer!]
	/local
		s		[series!]
		unit	[integer!]
		head	[byte-ptr!]
		tail	[byte-ptr!]
		i		[integer!]
		c		[integer!]
][
	assert TYPE_OF(str) = TYPE_STRING
	s: GET_BUFFER(str)
	unit: GET_UNIT(s)
	if unit = UCS-4 [
		head: (as byte-ptr! s/offset) + (str/head + offset << 2)
		tail: head + (idx * 4)
		i: 0
		while [head < tail][
			c: string/get-char head unit
			if c >= 00010000h [
				idx: idx + adjust
				if adjust < 0 [tail: tail - unit]
			]
			head: head + unit
		]
	]
	idx
]