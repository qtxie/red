Red/System [
	Title:	"Some utility functions"
	Author: "Xie Qingtian"
	File: 	%utils.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

LARGE_INTEGER: alias struct! [
	LowPart		[integer!]
	HighPart	[integer!]
]

#import [
	"kernel32.dll" stdcall [
		QueryPerformanceFrequency: "QueryPerformanceFrequency" [
			lpFrequency	[LARGE_INTEGER]
			return:		[logic!]
		]
		QueryPerformanceCounter: "QueryPerformanceCounter" [
			lpCount		[LARGE_INTEGER]
			return:		[logic!]
		]
		Sleep: "Sleep" [
			dwMilliseconds	[integer!]
		]
	]
]

time-meter!: alias struct! [
	t1	[LARGE_INTEGER value]
	t2	[LARGE_INTEGER value]
]

sub64: func [
	a		[LARGE_INTEGER]
	b		[LARGE_INTEGER]
	return:	[integer!]
][
	;-- mov edx, [ebp + 8]
	;-- mov ecx, [ebp + 12]
	;-- mov eax, [edx]
	;-- mov edx, [edx + 4]
	;-- sub eax, [ecx]
	;-- sbb edx, [ecx + 4]
	#inline [
		#{8B55088B4D0C8B028B52042B011B5104}
		return: [integer!]
	]
]

time-meter: context [
	freq: 0

	init: func [/local t [LARGE_INTEGER value]][
		QueryPerformanceFrequency :t
		freq: t/LowPart
	]

	start: func [t [time-meter!]][
		if zero? freq [init]
		QueryPerformanceCounter t/t1
	]

	elapse: func [
		t		[time-meter!]
		return: [float32!]		;-- ms
		/local
			d	[integer!]
	][
		QueryPerformanceCounter t/t2
		d: sub64 t/t2 t/t1
		(as float32! d) * (as float32! 1e3) / (as float32! freq)
	]
]