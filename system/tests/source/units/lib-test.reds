Red/System [
	Title:   "Red/System lib test script"
	Author:  "Peter W A Wood"
	File: 	 %lib-test-source.reds
	Rights:  "Copyright (C) 2012-2015 Peter W A Wood. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %../../../../quick-test/quick-test.reds

;; library declarations
#import [
	LIBM-file cdecl [
		test-abs-float: "fabs" [
			f		[float!]
			return:	[float!]
		]
		test-abs-int: "abs" [
			i		[integer!]
			return:	[integer!]
		]
	]
]

lt-array!: alias struct! [
	a			[integer!]
	b			[integer!]
	c			[integer!]
	d			[integer!]
]

lt-int!: alias struct! [
	i			[integer!]
]

lt-strlen!: alias function! [
	str			[c-string!]
	return:		[integer!]
]

#import [
	LIBC-file cdecl [
		test-memcpy: "memcpy" [
			to		[c-string!]
			from	[c-string!]
			len		[integer!]
		]
		test-qsort: "qsort" [
			array   [lt-array!]
			count   [integer!]
			size    [integer!]
			compare [function! [
				first   [lt-int!]
				second  [lt-int!] 
				return: [integer!]
			]]
		]
		test-strlen: "strlen" [
			str		[c-string!]
			return:	[integer!]
		]
	]
]


~~~start-file~~~ "library"
  
===start-group=== "calls"

	--test-- "lib1"
		--assert 2 = test-abs-int 2
	--test-- "lib2"
		--assert 2.0 = test-abs-float -2.0
	--test-- "lib3"
		s: "hello, world"
		--assert 12 = test-strlen s
	--test-- "lib4"
		new: "123456789012"
		old: "HW"
		test-memcpy new old 12
		--assert new/1 = #"H"
		--assert new/2 = #"W"
		--assert 2 = length? new
		--assert old/1 = #"H"
		--assert old/2 = #"W"
		--assert 2 = length? old
		
===end-group===

===start-group=== "callbacks"

	--test-- "libcallback1"
		lib-array: declare lt-array!
		lib-array/a: 4
		lib-array/b: 3
		lib-array/c: 2
		lib-array/d: 1
		lib-compare: func [
			[cdecl]
			first     [lt-int!]
			second    [lt-int!]
			return:   [integer!]
		][
			first/i - second/i
		]
		test-qsort lib-array 4 4 :lib-compare
		--assert 1 = lib-array/a
		--assert 2 = lib-array/b
		--assert 3 = lib-array/c
		--assert 4 = lib-array/d
    
===end-group===

#switch OS [
	Windows [
		#include %lib-win32-test.reds   
	]
	macOS [
		#include %lib-macOS-test.reds
	]
	Linux []
]

;-- An object format names an import three ways and only one of them is a
;-- call: a branch reaches a function through its stub, while a read of an
;-- imported variable and the address of an imported function both go through
;-- the slot the loader fills with the symbol's address. A variable read
;-- patched at the stub instead loads the stub's first instruction word --
;-- 0xF0 on AArch64, 0xFF on x86-64 -- and dereferences that, so an
;-- environment entry that does not begin with a printable character is the
;-- failure this group is here to catch.
#either any [OS = 'Linux OS = 'macOS] [
	#import [
		LIBC-file cdecl [
			test-environ: "environ" [pointer! [c-string!]]
		]
	]

	env-entry: declare c-string!
	strlen-fn: declare lt-strlen!

	===start-group=== "imported data"

	--test-- "lib-data-1"
		env-entry: test-environ/value
		--assert env-entry <> null
		--assert all [
			env-entry/1 >= #"A"
			env-entry/1 <= #"z"
		]
	--test-- "lib-data-2"
		strlen-fn: as lt-strlen! :test-strlen
		--assert 12 = strlen-fn "hello, world"

	===end-group===
][]
  
~~~end-file~~~

