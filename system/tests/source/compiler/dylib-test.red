Red [
	Title:   "Red/System dynamic library compiler test script"
	Author:  "Nenad Rakocevic & Peter W A Wood"
	File: 	 %dylib-test.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2015 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSL-License.txt"
]

; Ported from dylib-test.r. The original derived the library target from
; `fourth system/version`, which is a Rebol version tuple with no Red
; equivalent; the driver supplies qt/target instead, and the runner sets the
; working directory to the repo root so the source paths are root-relative.

~~~start-file~~~ "dylib compiler"

===start-group=== "dylib compiles"

	--test-- "compile dll1"
	--compile-dll %system/tests/source/units/libtest-dll1.reds
	--assert qt/compile-ok?

	--test-- "compile dll2"
	--compile-dll %system/tests/source/units/libtest-dll2.reds
	--assert qt/compile-ok?

===end-group===

~~~end-file~~~
