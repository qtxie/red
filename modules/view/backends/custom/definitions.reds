Red/System [
	Title:	"Structure Definitions"
	Author: "Xie Qingtian"
	File: 	%definitions.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define coord!	integer!

point!: alias struct! [
	x	[coord!]
	y	[coord!]
]

area!: alias struct! [
	x1	[coord!]
	y1	[coord!]
	x2	[coord!]
	x2	[coord!]
]