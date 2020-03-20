Red/System [
	Title:	"Drawing widgets"
	Author: "Xie Qingtian"
	File: 	%widgets.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

widgets: context [
	#include %widgets/base.reds
	#include %widgets/button.reds

	draw-gob: func [
		gob		[gob!]
		/local
			s	[series!]
			p	[ptr-ptr!]
			e	[ptr-ptr!]
			t	[integer!]
	][
		t: GOB_TYPE(gob)
		switch t [
			GOB_BASE	[draw-base gob]
			GOB_BUTTON	[draw-button gob]
			GOB_WINDOW	[0]
			default		[0]
		]
		if gob/children <> null [
			if t <> GOB_WINDOW [
				renderer/set-tranlation gob/box/left gob/box/top
			]
			s: as series! gob/children/value
			p: as ptr-ptr! s/offset
			e: as ptr-ptr! s/tail
probe ["1 " p " " e]
			while [p < e][
				draw-gob as gob! p/value
				p: p + 1
			]
		]
	]
]
