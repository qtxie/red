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

#either OS = 'Windows [
    LARGE_INTEGER: alias struct! [
        LowPart     [integer!]
        HighPart    [integer!]
    ]

    #import [
        "kernel32.dll" stdcall [
            QueryPerformanceFrequency: "QueryPerformanceFrequency" [
                lpFrequency [LARGE_INTEGER]
                return:     [logic!]
            ]
            QueryPerformanceCounter: "QueryPerformanceCounter" [
                lpCount     [LARGE_INTEGER]
                return:     [logic!]
            ]
        ]
    ]

    time-meter!: alias struct! [
        base [LARGE_INTEGER value]
    ]

    sub64: func [
        a       [LARGE_INTEGER]
        b       [LARGE_INTEGER]
        return: [integer!]
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
            QueryPerformanceCounter t/base
        ]

        elapse: func [ 
            t       [time-meter!]
            return: [float32!]      ;-- millisecond
            /local
            	t1  [LARGE_INTEGER value]
                d   [integer!]
        ][
            QueryPerformanceCounter t1
            d: sub64 t1 t/base
            (as float32! d) * (as float32! 1e3) / (as float32! freq)
        ]
    ]
][
    time-meter!: alias struct! [
        base-s  [integer!]
        base-m  [integer!]          ;-- microsecond
    ]

    time-meter: context [
        timeval!: alias struct! [
            tv_sec  [integer!]
            tv_usec [integer!]
        ]
        #import [
            LIBC-file cdecl [
                gettimeofday: "gettimeofday" [
                    tv      [timeval!]
                    tz      [integer!]          ;-- obsolete
                    return: [integer!]          ;-- 0: success -1: failure
                ]
            ]
        ]

        start: func [
            t       [time-meter!]
            /local
                tm  [timeval! value]
        ][
            gettimeofday :tm 0
            t/base-s: tm/tv_sec
            t/base-m: tm/tv_usec    ;-- microsecond
        ]

        elapse: func [
            t       [time-meter!]
            return: [float32!]      ;-- millisecond
            /local
                tm  [timeval! value]
                s   [float32!]
                ms  [float32!]
        ][
            gettimeofday :tm 0
            s: as float32! (tm/tv_sec - t/base-s)
            ms: as float32! (tm/tv_usec - t/base-m)
            s * (as float32! 1000.0) + (ms / as float32! 1000.0)
        ]
    ]
]

copy-rect: func [
	src		[RECT_F!]
	dst		[RECT_F!]
][
	dst/left: src/left
	dst/right: src/right
	dst/top: src/top
	dst/bottom: src/bottom
]

zero-memory: func [
	dest	[byte-ptr!]
	size	[integer!]
][
	loop size [dest/value: #"^@" dest: dest + 1]
]

utf16-length?: func [
	s 		[c-string!]
	return: [integer!]
	/local base [c-string!]
][
	base: s
	while [any [s/1 <> null-byte s/2 <> null-byte]][s: s + 2]
	(as-integer s - base) >>> 1							;-- do not count the terminal zero
]