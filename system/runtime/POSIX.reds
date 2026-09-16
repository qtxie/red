Red/System [
	Title:   "Red/System POSIX runtime"
	Author:  "Nenad Rakocevic"
	File: 	 %POSIX.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define OS_DIR_SEP 47						;-- #"/"

#import [									;-- mandatory C bindings
	LIBC-file cdecl [
		sigaction: "sigaction" [
			signum	[integer!]
			action	[sigaction!]
			oldact	[sigaction!]
			return: [integer!]
		]
		sigemptyset: "sigemptyset" [
			mask	[byte-ptr!]
			return: [integer!]
		]
		sigaltstack: "sigaltstack" [
			ss		[sigaltstack!]
			oldss	[sigaltstack!]
			return: [integer!]
		]
		atexit: "__cxa_atexit" [			;-- https://refspecs.linuxbase.org/LSB_3.1.1/LSB-Core-generic/LSB-Core-generic/baselib---cxa-atexit.html
			handler		[int-ptr!]
			arg			[int-ptr!]			;-- requires NULL in our use-case
			dso_handle	[int-ptr!]			;-- requires NULL in our use-case
			return:		[integer!]
		]
	]
]

stdin:  0
stdout: 1
stderr: 2

#if use-natives? = yes [
	prin: func [s [c-string!] return: [integer!]][
		write stdout s length? s
	]
]

;====== Catching runtime errors ======

;; sources:
;;		http://www.kernel.org/doc/man-pages/online/pages/man2/sigaction.2.html

#include %POSIX-signals.reds

; Debug builds run the signal handlers on a dedicated stack and dump the
; faulting context before reporting, so a crash can be diagnosed on a target
; without a debugger. Release builds must stay behaviorally identical: no
; alternate stack is installed and nothing extra is printed. The type and its
; library binding stay unconditional because #import is collected before the
; preprocessor runs, so it cannot be gated; declaring them costs no code.
sigaltstack!: alias struct! [
	ss_sp		[byte-ptr!]
	ss_flags	[integer!]
	ss_pad		[integer!]
	ss_size		[int-ptr!]
]

#if debug? = yes [
	rs-dump-ctx: func [pc lr sp fp [integer!]][
		print [lf "SCTX pc=" pc " lr=" lr " sp=" sp " fp=" fp lf]
	]

	__alt-stack: as byte-ptr! 0
]

posix-startup-ctx: context [

	UCTX_DEFINITION

	;-- Singleton debug record. system/debug outlives the handler frame, so the
	;-- record is declared once at context level regardless of the storage a
	;-- function-scope DECLARE would use.
	__debug-stack: declare __stack!

	***-on-signal: func [
		[cdecl]
		signal	[integer!]
		info	[siginfo!]
		ctx		[_ucontext!]
		/local code error
	][
		#if debug? = yes [
			rs-dump-ctx as integer! UCTX_INSTRUCTION(ctx)
				#either all [OS = 'macOS target = 'ARM64][
					as integer! ctx/mcontext/state/lr
				][0]
				as integer! UCTX_GET_STACK_TOP(ctx)
				as integer! UCTX_GET_STACK_FRAME(ctx)
		]

		error: 99								;-- default unknown error
		code: info/code
		
		system/debug: __debug-stack				;-- reuse the context-level struct
		#switch target [
			X86-64 [
				system/debug/frame: UCTX_GET_STACK_FRAME(ctx)
				system/debug/top: UCTX_GET_STACK_TOP(ctx)
			]
			ARM64 [
				system/debug/frame: UCTX_GET_STACK_FRAME(ctx)
				system/debug/top: UCTX_GET_STACK_TOP(ctx)
			]
			#default [
				system/debug/frame: as int-ptr! UCTX_GET_STACK_FRAME(ctx)
				system/debug/top: as int-ptr! UCTX_GET_STACK_TOP(ctx)
			]
		]

		error: switch signal [
			SIGILL [
				switch code [
					ILL_ILLOPC [17]				;-- illegal opcode
					ILL_ILLOPN [23]				;-- illegal operand
					ILL_ILLADR [24]				;-- illegal addressing mode
					ILL_ILLTRP [25]				;-- illegal trap
					ILL_PRVOPC [15]				;-- privileged opcode
					ILL_PRVREG [31]				;-- privileged register
					ILL_COPROC [26]				;-- coprocessor error
					ILL_BADSTK [19]				;-- internal stack error
					default    [99]
				]
			]
			SIGBUS [
				switch code [
					BUS_ADRALN    [2]			;-- invalid address alignment
					BUS_ADRERR   [27]			;-- non-existant physical address
					BUS_OBJERR   [28]			;-- object specific hardware error
					BUS_MCERR_AR [29]			;-- hardware memory error consumed (action required)
					BUS_MCERR_AO [30]			;-- hardware memory error consumed (action optional)
					default      [34]
				]
			]
			SIGFPE [
				switch code [
					FPE_INTDIV [13]				;-- integer divide by zero
					FPE_INTOVF [14]				;-- integer overflow
					FPE_FLTDIV  [7]				;-- floating point divide by zero
					FPE_FLTOVF [10]				;-- floating point overflow
					FPE_FLTUND [12]				;-- floating point underflow
					FPE_FLTRES  [8]				;-- floating point inexact result
					FPE_FLTINV  [9]				;-- floating point invalid operation
					FPE_FLTSUB  [5]				;-- subscript out of range
					default    [33]
				]
			]
			SIGSEGV [
				switch code [
					SEGV_MAPERR  [1]			;-- address not mapped to object
					SEGV_ACCERR [16]			;-- invalid permissions for mapped object
					default     [32]
				]
			]
		]

		***-on-quit error as byte-ptr! UCTX_INSTRUCTION(ctx)
	]

	init: func [
		/local
			__sigaction-options [sigaction!]
			__ss [sigaltstack!]
	][
		__sigaction-options: declare sigaction!

		__sigaction-options/sigaction: 	#either OS = 'macOS [
			#either ABI = 'apple-aarch64 [
				as byte-ptr! :***-on-signal
			][
				as integer! :***-on-signal
			]
		][
			#either any [OS = 'FreeBSD OS = 'NetBSD] [
				as integer! :***-on-signal
			][
				as byte-ptr! :***-on-signal
			]
		]
		#if debug? = yes [
			__alt-stack: allocate 1048576
			__ss: declare sigaltstack!
			__ss/ss_sp: __alt-stack
			__ss/ss_flags: 0
			__ss/ss_size: as int-ptr! 1048576
			sigaltstack __ss as sigaltstack! 0
		]
		__sigaction-options/flags: #either debug? = yes [
			SA_SIGINFO or SA_ONSTACK					;-- run handlers on __alt-stack
		][
			SA_SIGINFO
		]

		sigaction SIGILL  __sigaction-options as sigaction! 0
		sigaction SIGBUS  __sigaction-options as sigaction! 0
		sigaction SIGFPE  __sigaction-options as sigaction! 0
		sigaction SIGSEGV __sigaction-options as sigaction! 0
		
		#if any [libRedRT? = yes dev-mode? = no red-pass? = no][ ;-- avoid installing quit handler more than once!
			atexit as int-ptr! :on-quit null null
		]
	]
	
	on-quit: func [[cdecl]][heap-free-all]
]

#if OS <> 'macOS [								;-- macOS has it's own start code
	#switch type [
		dll [
			***-dll-entry-point: func [
				[cdecl]
			][
				system/image: ***-exec-image
				#either target = 'ARM64 [
					system/image/base: (as byte-ptr! ***-exec-image) - (as integer! system/image/base)
				][
					;-- X86-64 ELF R_X86_64_RELATIVE relocation already sets image/base.
					#if target <> 'X86-64 [
						system/image/base: as byte-ptr!
							#either target = 'IA-32 [system/cpu/ebx][system/cpu/r9]
							- system/image/code
					]
				]

				***-init-system-image
				
				#either red-pass? = no [		;-- only for pure R/S DLLs
					***-boot-rs
					on-load
					***-main
				][
					on-load
				]
			]
		]
		exe [
			#if all [target = 'ARM64 PIC? = yes][
				system/image/base: (as byte-ptr! ***-exec-image) - (as integer! system/image/base)
			]
			posix-startup-ctx/init
		]
	]
]
