Red/System [
	Title:   "Hybrid compiler Linux process startup"
	Author:  "Nenad Rakocevic"
	File: 	 %start-hybrid.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2026 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

;-- The hybrid code generator emits an executable entry as a function complete
;-- with a frame, so the module body cannot be the process entry on its own: on
;-- Linux an entry point starts on the kernel stack and libc has not run yet.
;-- The entry prologue of the code generator therefore publishes the raw stack
;-- pointer in the startup register (ARM64: X19, X86-64: R12) before it builds
;-- its frame; argc sits at the top of that stack, followed by the argv pointers
;-- and the environment.
;--
;-- The compiler core splices this source after the module body. It is compiled
;-- into the entry function, while the body is published as ***_start and handed
;-- to __libc_start_main as the C `main`. The body runs with libc initialized,
;-- and returning from it lets libc finish the process with its status.

#import [ LIBC-file cdecl [
	libc-start: "__libc_start_main" [
		main      [function! []]
		argc      [integer!]
		argv      [pointer! [integer!]]
		init      [function! []]
		fini      [function! []]
		rtld-fini [function! []]
		stack-end [pointer! [integer!]]
	]
]]

#either target = 'ARM64 [
	hybrid-entry-stack: as int-ptr! system/cpu/x19
][
	hybrid-entry-stack: as int-ptr! system/cpu/r12
]

;-- The runtime reads the command line from these globals once the body runs.
***__argc: hybrid-entry-stack/value
***__argv: hybrid-entry-stack + 2

libc-start :***_start ***__argc ***__argv null null null hybrid-entry-stack

;-- __libc_start_main only returns for a failed initialization; stop here
;-- rather than returning into a frame that has no caller.
quit 1
