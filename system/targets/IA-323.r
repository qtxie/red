REBOL [
	Title:   "Red/System source code emitter"
	Author:  "Qingtian"
	File: 	 %red-system.r
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2022 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

make-profilable make target-class [
	target: 'red-system
	little-endian?: yes
	struct-align-size: 	4
	ptr-size: 			4
	default-align:		4
	stack-width:		4
	stack-slot-max:		8							;-- size of biggest datatype on stack (float64!)
	args-offset:		8							;-- stack frame offset to arguments (ebp + ret-addr)
	branch-offset-size:	4							;-- size of JMP offset
	locals-offset:		8							;-- offset from frame pointer to local variables (catch ID + addr)
	
	fpu-cword: none									;-- x87 control word reference in emitter/symbols
	fpu-flags: to integer! #{037A}					;-- default control word, division by zero
													;-- and invalid operands raise exceptions.
	conditions: make hash! [
	;-- name ----------- signed --- unsigned --
		overflow?		 #{00}		-
		not-overflow?	 #{01}		-	
		=				 #{04}		-
		<>				 #{05}		-
		signed?			 #{08}		-
		unsigned?		 #{09}		-
		even?			 #{0A}		-
		odd?			 #{0B}		-
		<				 #{0C}		#{02}
		>=				 #{0D}		#{03}
		<=				 #{0E}		#{06}
		>				 #{0F}		#{07}
	]
	
	patch-floats-definition: func [mode [word!]][
	]
	
	on-init: has [offset][
	]
	
	on-global-prolog: func [runtime? [logic!] type [word!] /local offset][
		if runtime? [
			if type = 'exe [emit-fpu-init]
		]
	]
	
	on-global-epilog: func [runtime? [logic!] type [word!]][
	]

	add-condition: func [op [word!] data [binary!]][
		op: either '- = third op: find conditions op [op/2][
			pick op pick [2 3] signed?
		]
		data/(length? data): (to char! last data) or (to char! first op) ;-- REBOL2's awful binary! handling
		data
	]

	adjust-disp32: func [lcode [binary! block!] offset [binary!] /local code byte][
		if 4 = length? offset [
			lcode: copy/deep lcode
			code: either block? lcode [first back find lcode 'offset][lcode]
			change byte: back tail code byte xor #{C0}	;-- switch to 32-bit displacement mode
		]
		lcode
	]

	emit-variable: func [
		name  [word! object!] 
		gcode [binary! block! none!]				;-- global opcodes
		pcode [binary! block! none!]				;-- PIC opcodes
		lcode [binary! block!] 						;-- local opcodes
		/local offset byte code spec
	][
	]
	
	emit-float: func [opcode [binary!]][
	]

	emit-float-arg: func [arg opcode [binary!]][
	]	
	emit-float-variable: func [
		name [word! object!] gcode [binary!] pcode [binary!] lcode [binary!]
	][
	]
	
	load-float-variable: func [name [word! object!]][
	]
	
	store-float-variable: func [name [word! object!]][
	]
		
	emit-poly: func [spec [block!] /local w to-bin][	;-- polymorphic code generation
	]
	
	emit-variable-poly: func [						;-- polymorphic variable access generation
		name [word! object!]
		    g8 [binary!] 		g32 [binary!]		;-- opcodes for global variables
		    p8 [binary!] 		p32 [binary!]		;-- opcodes for global variables (PIC)
			l8 [binary! block!] l32 [binary! block!];-- opcodes for local variables
	][
	]
	
	emit-indirect-call: func [spec [block!]][
	]
	
	emit-alloc-stack: func [zeroed? [logic!]][
	]
	
	emit-free-stack: does [
	]
	
	emit-reserve-stack: func [slots [integer!] /local size][
	]
	
	emit-release-stack: func [slots [integer!] /bytes /local size][	
	]
	
	emit-move-path-alt: does [
	]
	
	emit-save-last: does [
	]
	
	emit-restore-last: does [
	]
	
	emit-casting: func [value [object!] alt? [logic!] /push /local type old][
	]

	emit-load-literal: func [type [block! none!] value /local spec][	
	]
	
	emit-load-literal-ptr: func [spec [block!]][
	]
	
	emit-fpu-get: func [
		/type
		/options option [word!]
		/masks mask [word!]
		/cword
		/status
		/local
	][
	]
	
	emit-access-register: func [reg [word!] set? [logic!] value /local opcode][
	]
	
	emit-fpu-set: func [
		value
		/options option [word!]
		/masks mask [word!]
		/cword
		/local bit
	][
	]
	
	emit-fpu-update: does [
	]
	
	emit-fpu-init: does [
	]
	
	emit-atomic-load: func [order [word!]][
	]
	
	emit-atomic-store: func [value order [word!]][
	]
	
	emit-atomic-math: func [op [word!] right-op old? [logic!] ret? [logic!] order [word!]][
	]
	
	emit-atomic-cas: func [check value ret? [logic!] order [word!]][
	]
	
	emit-atomic-fence: does [
	]

	emit-get-overflow: does [
	]
	
	emit-get-pc: func [/ebx][
	]
	
	emit-set-stack: func [value /frame][
	]
	
	emit-get-stack: func [/frame][
	]
	
	emit-pop: does [
	]
	
	emit-io-read: func [type][
	]
	
	emit-io-write: func [type][
	]
	
	emit-push-all: does [
	]
	
	emit-pop-all: does [
	]
	
	emit-clear-slot: func [name [word!] /local opcode offset][
	]

	emit-log-b: func [type][
	]

	emit-not: func [value [word! char! tag! integer! logic! path! string! object!] /local opcodes type boxed][
		if verbose >= 3 [print [">>>emitting NOT" mold value]]

		if object? value [boxed: value]
		value: compiler/unbox value
		if block? value [value: <last>]

		opcodes: [
			logic!	 [emit #{3401}]					;-- XOR al, 1			; invert 0<=>1
			byte!	 [emit #{F6D0}]					;-- NOT al				; @@ missing 16-bit support									
			integer! [emit #{F7D0}]					;-- NOT eax
		]
		switch type?/word value [
			logic! [
				emit-load not value
			]
			char! [
				emit-load value
				do opcodes/byte!
			]
			integer! [
				emit-load value
				do opcodes/integer!
			]
			word! [
				emit-load value
				type: either boxed [
					emit-casting boxed no
					boxed/type/1
				][
					first compiler/resolve-aliased compiler/get-variable-spec value
				]
				if find [pointer! c-string! struct!] type [ ;-- type casting trap
					type: 'logic!
				]
				switch type opcodes
			]
			tag! [
				if boxed [
					emit-casting boxed no
					compiler/last-type: boxed/type
				]
				switch compiler/last-type/1 opcodes
			]
			string! [								;-- type casting trap
				emit-load value
				if boxed [emit-casting boxed no]
				do opcodes/logic!
			]
			path! [
				emitter/access-path value none
				either boxed [
					emit-casting boxed no
					switch boxed/type/1 opcodes 
				][
					type: compiler/resolve-path-type value
					compiler/last-type: type
					switch type/1 opcodes
				]
			]
		]
	]
	
	emit-boolean-switch: does [
		reduce [3 7]								;-- [offset-TRUE offset-FALSE]
	]
	
	emit-load: func [
		value [char! logic! integer! word! string! path! paren! get-word! object! decimal! issue!]
		/alt
		/with cast [object!]
		/local offset spec
	][
		if verbose >= 3 [print [">>>loading" mold value]]
		alt: to logic! alt
		
		switch type?/word value [
			path! [
				emitter/access-path value none
			]
			paren! [
				emit-load-literal none value
			]
			object! [
				unless any [block? value/data value/data = <last>][
					either alt [
						emit-load/alt/with value/data value
					][
						emit-load/with value/data value
					]
					set-width value
				]
				;emit-casting value no
				;compiler/last-type: value/type
			]
		]
	]
	
	emit-store: func [
		name [word!] value [char! logic! integer! word! string! binary! paren! tag! get-word! decimal! issue!]
		spec [block! none!]
		/by-value slots [integer!]
	][
	]
	
	emit-init-path: func [name [word! get-word!]][
	]
	
	emit-access-path: func [
		path [path! set-path!] spec [block! none!] /short
	][
	]
		
	emit-load-index: func [idx [word!]][
	]
	
	emit-c-string-path: func [path [path! set-path!] parent [block! none!]][
	]
	
	emit-pointer-path: func [
		path [path! set-path!] parent [block! none!]
	][
	]
	
	emit-load-path: func [path [path!] type [word!] parent [block! none!]][
	]

	emit-store-path: func [
		path [set-path!] type [word!] value parent [block! none!]
	][
	]
	
	emit-start-loop: func [spec [block! none!] name [word! none!]][
	]
	
	emit-end-loop: func [spec [block! none!] name [word! none!] ][
	]

	patch-sub-call: func [buffer [binary!] ptr [integer!] offset [integer!]][
	]
	
	patch-jump-back: func [buffer [binary!] offset [integer!]][
	]
	
	patch-jump-point: func [buffer [binary!] ptr [integer!] exit-point [integer!]][
	]
	
	emit-jump-point: func [type [block!]][
	]

	construct-jump: func [
		"construct the jump instruction binary (internal! for use within emit-branch only!)"
		op [word! none!] "operator to constuct for, NONE for unconditional jump, 'parity for parity jump"
		size [integer!] "jump size"
		back? [logic! none!]
		/local opcode o short? dir
	][
		o: size * dir: pick [-1 1] yes = back?		;-- convert size to signed jump offset
		short?: to logic! all [-126 <= o  o <= 127]	;-- account for 2bytes of Jxx opcode when short-jumping back
		opcode: pick pick [
			[#{EB} #{E9}]							;-- JMP short/near
			[#{70} #{0F80}]							;-- Jcc short/near
			[#{7A} #{0F8A}]							;-- JP  short/near
		]	either op = 'parity [ 3 ][ none? op ]	;-- pick row: 1 = normal, 2 = conditional, 3 = parity
			short? 									;-- pick column
		if all [op op <> 'parity] [
			opcode: add-condition op copy opcode	;-- use `op` to modify the conditional jump Jcc
		]
		if back? [									;-- when jumping back, offset should account for the jump instruction size
			size: size + (length? opcode) + (pick [1 4] short?)
			o: size * dir							;-- recalculate offset with new size
		]
		o: either short? [to-bin8 o][to-bin32 o]	;-- make binary signed offset
		reduce [size rejoin [opcode o]]
	]

	emit-branch: func [
		code [binary!]
		op [word! block! logic! none!]
		offset [integer! none!]
		parity [none! logic!] "yes = also emit parity check for unordered (NaN) comparison"
		/back?
		/local size jump jxx jcc jp unord-jumps-to-true? flip? jump-code
	][
		if verbose >= 3 [print [">>>inserting branch" either op [join "cc: " mold op][""]]]
		size: (length? code) - any [offset 0]			;-- offset from the code's head
		jump: copy #{}									;-- resulting binary
		jxx: [second set [size jump-code] construct-jump op      size back?]
		jp:  [second set [size jump-code] construct-jump 'parity size back?]

		either none? op [								;-- explicitly test for none
			append jump do jxx							;-- JMP offset 	; 8/32-bit displacement
		][
			flip?: no									;-- condition inverted? flag
			op: case [
				block? op [								;-- [cc] => keep
					op: op/1
					either logic? op [					;-- [logic!] or [cc]
						pick [= <>] op
					][ op ]
				]
				logic? op [pick [= <>] op]				;-- test for TRUE/FALSE
				'else 	  [
					flip?: yes 							;-- flip unordered target along with the condition
					opposite? op						;-- 'cc => invert condition; unordered defined by the original op
				]
			]

			unord-jumps-to-true?: either flip? [		;-- should unordered JP jump lead to true branch?
				op <> '=
			][	op = first [<>]
			]

			;-- optimization: JNx jumps fail on NaNs anyways, Jx - succeed; no need for parity tests
			if all [
				parity									;-- with NaN: CF=PF=ZF=1
				either unord-jumps-to-true? [
					;-- JP can be left off if Jcc always succeeds on P=1: JC(<), JZ(=), JBE(<=)
					find [< = <=]  op
				][
					;-- JP can be left off if Jcc always fails on P=1: JNC(>=), JNZ(<>), JA(>)
					find [> <> >=] op
				]
			] [parity: no]

			either not parity [
				append jump do jxx						;-- Jcc offset 	; 8/32-bit displacement
			][
				either back? [							;-- in `back?` mode size is adjusted by jxx automatically
					either unord-jumps-to-true? [
						;; _true:
						;;   <code>
						;;   JP _true		; short/far
						;;   Jcc _true		; short/far
						;; _false:

						append jump do jp				;-- append JP _true
						append jump do jxx				;-- append Jcc _true
					][
						;; _true:
						;;   <code>
						;;   JP _false		; short
						;;   Jcc _true		; short/far
						;; _false:

						size: size + 2					;-- manually skip 2 bytes of the JP
						jcc: do jxx 					;-- lay out Jcc _true
						append jump rejoin [#{7A} to-bin8 length? jcc]	;-- append JP _false, over the Jcc size
						append jump jcc					;-- append Jcc _true
					]
				][										;-- forward jumps, no auto size adjustment
					either unord-jumps-to-true? [
						;;   JP _true		; short/far - needs to know Jcc size
						;;   Jcc _true		; short/far
						;; _false:
						;;   <code>
						;; _true:

						jcc: do jxx 					;-- lay out Jcc _true
						size: size + length? jcc 		;-- manually skip it's size for the JP
						append jump do jp 				;-- append JP _true
						append jump jcc 				;-- append Jcc _true
					][
						;;   JP _false		; short - needs to know Jcc size
						;;   Jcc _true		; short/far
						;; _false:
						;;   <code>
						;; _true:

						jcc: do jxx						;-- lay out Jcc _true
						append jump rejoin [#{7A} to-bin8 length? jcc]	;-- append JP _false, over the Jcc size
						append jump jcc					;-- append Jcc _true
					]
				]
			]
		]
		insert any [all [back? tail code] code] jump
		length? jump
	]
	
	emit-push-struct: func [slots [integer!]][		;-- number of 32-bit slots
	]
	
	emit-push: func [
		value [char! logic! integer! word! block! string! tag! path! get-word! object! decimal! issue!]
		/with cast [object!]
		/cdecl										;-- external call
		/keep
	][
	]
	
	emit-sign-extension: does [
	]
	
	emit-bitshift-op: func [name [word!] a [word!] b [word!] args [block!]][
	]
	
	emit-bitwise-op: func [name [word!] a [word!] b [word!] args [block!]][		
	]
	
	emit-comparison-op: func [name [word!] a [word!] b [word!] args [block!]][
	]
	
	emit-math-op: func [
		name [word!] a [word!] b [word!] args [block!]
	][
	]
	
	emit-integer-operation: func [name [word!] args [block!]][
	]
	
	emit-float-trash-last: does [
	]
	
	emit-float-comparison-op: func [
		name [word!] a [word!] b [word!] args [block!] reversed? [logic!]
	][
	]
	
	emit-float-math-op: func [
		name [word!] a [word!] b [word!] args [block!] reversed? [logic!]
	][
		all [
			find [+ -] name	
			any [
				compiler/any-pointer? compiler/get-type args/1
				compiler/any-pointer? compiler/get-type args/2
			]
			compiler/throw-error "unsupported operation with float numbers"
		]
	
	]

	emit-float-operation: func [
		name [word!] args [block!] 
	][
	]
	
	emit-return-sub: does [
	]
	
	emit-call-sub: func [name [word!] spec [block!]][
	]
	
	emit-cdecl-pop: func [spec [block!] args [block!] /local size slots][
	]
	
	patch-call: func [code-buf rel-ptr dst-ptr][
	]
	
	emit-argument: func [arg fspec [block!]][
		if arg = #_ [exit]							;-- place-holder, no code to emit
		
		either all [
			object? arg
			any [arg/type = 'logic! 'byte! = first compiler/get-type arg/data]
			not path? arg/data
		][
			unless block? arg [emit-load arg]		;-- block! means last value is already in eax (func call)
			emit-casting arg no
			compiler/last-type: arg/type			;-- for inline unary functions
			emit-push <last>
		][
			0
		]
	]
		
	emit-call-syscall: func [args [block!] fspec [block!] attribs [block! none!]][
	]
	
	emit-variadic-data: func [args [block!] /local total][
	]
	
	emit-call-import: func [args [block!] fspec [block!] spec [block!] attribs [block! none!] /local cdecl?][
	]

	emit-call-native: func [
		args [block!] fspec [block!] spec [block!] attribs [block! none!]
		/routine name [word!]
		/local cdecl?
	][
	]
	
	emit-stack-align: does [
	]

	emit-stack-align-prolog: func [args [block!] fspec [block!] /local offset extra][

	]
	
	emit-stack-align-epilog: func [args [block!]][
	]
	
	emit-throw: func [value [integer! word!] /thru][
	]
	
	emit-open-catch: func [body-size [integer!] global? [logic!]][
	]
	
	emit-close-catch: func [offset [integer!] global? [logic!] callback? [logic!]][
	]

	emit-prolog: func [name [word!] locals [block!] /local fspec attribs offset locals-size][
		if verbose >= 3 [print [">>>building:" uppercase mold to-word name "prolog"]]

		fspec: select compiler/functions name
		attribs: compiler/get-attributes fspec/4
			
		emit #{55}									;-- PUSH ebp
		emit #{89E5}								;-- MOV ebp, esp

		emit-push pick [-2 0] to logic! all [		;-- push catch ID
			attribs find attribs 'catch
		]
		emit-push 0									;-- reserve slot for catch resume address

		locals-size: either pos: find locals /local [emitter/calc-locals-offsets pos][0]
		
		unless zero? locals-size [
			emit-reserve-stack (round/to/ceiling locals-size stack-width) / stack-width
		]
		if any [
			fspec/5 = 'callback
			all [attribs any [find attribs 'cdecl find attribs 'stdcall]]
		][
			emit #{53}								;-- PUSH ebx
			emit #{56}								;-- PUSH esi
			emit #{57}								;-- PUSH edi
			
			if PIC? [
				offset: emit-get-pc/ebx
				emit #{81EB}						;-- SUB ebx, <offset>
				emit to-bin32 emitter/tail-ptr + 1 - offset	;-- +1 adjustment for CALL first opcode
			]
		]
		reduce [locals-size 0]
	]

	emit-epilog: func [
		name [word!] locals [block!] args-size [integer!] locals-size [integer!] /with slots [integer! none!]
		/local fspec attribs vars offset cdecl? SysVABI? macOSABI? clean-hidden-ptr? type
	][
		if verbose >= 3 [print [">>>building:" uppercase mold to-word name "epilog"]]
		
		fspec: select compiler/functions name
		
		if slots [
			SysVABI?:  all [compiler/job/OS = 'Linux fspec/3 = 'cdecl]
			macOSABI?: all [compiler/job/OS = 'macOS fspec/3 = 'cdecl]
			case [
				all [not SysVABI? slots = 1][
					emit #{8B00}					;-- MOV eax, [eax]
					if all [macOSABI? type: compiler/is-small-struct-float? fspec/4 type/1 = 'float32!][
						emit #{50}					;-- PUSH eax
						emit #{D90424}				;-- FLD dword [esp]		; load as 32-bit
						emit #{83C404} 				;-- ADD esp, 4
					]
				]
				all [not SysVABI? slots = 2][
					emit #{8B5004}					;-- MOV edx, [eax+4]
					emit #{8B00}					;-- MOV eax, [eax]
					if all [macOSABI? type: compiler/is-small-struct-float? fspec/4 find [float! float64!] type/1][
						emit #{52}					;-- PUSH edx
						emit #{50}					;-- PUSH eax
						emit #{DD0424}				;-- FLD qword [esp]		; load as 64-bit
						emit #{83C408} 				;-- ADD esp, 8
					]
				]
				'else [
					vars: emitter/stack
					unless tag? vars/1 [
						compiler/throw-error ["Function" name "has no return pointer in" mold locals]
					]
					emit #{8B7D}					;-- MOV edi, [ebp+<ptr>]
					emit to-bin8 vars/2
					;@@ needs 32-bit disp also !!
					emit #{89C6}					;-- MOV esi, eax
					emit #{B9}						;-- MOV ecx, <size>
					emit to-bin32 slots
					emit #{F3A5}					;-- REP MOVS
				]
			]
			if clean-hidden-ptr?: all [
				tag? emitter/stack/1
				any [SysVABI? all [slots > 2 compiler/job/OS = 'macOS]]
			][
				emit #{8B45}					    ;-- MOV eax, [ebp+<ptr>]
				emit to-bin8 emitter/stack/2
			]
		]
		if any [
			fspec/5 = 'callback
			all [
				attribs: compiler/get-attributes fspec/4
				any [find attribs 'cdecl find attribs 'stdcall]
			]
		][
			offset: locals-size + locals-offset
			emit #{8DA5}							;-- LEA esp, [ebp-<offset>]
			emit to-bin32 negate offset + 12		;-- account for 3 saved regs
			emit #{5F}								;-- POP edi
			emit #{5E}								;-- POP esi
			emit #{5B}								;-- POP ebx
		]
		emit #{C9}									;-- LEAVE			; catch flag is skipped
		either any [
			zero? args-size
			cdecl?: fspec/3 = 'cdecl
		][
			;; cdecl: Leave original arguments on stack, popped by caller.
			emit either all [cdecl? clean-hidden-ptr?][
				#{C20400}							;-- RETN 4	; macOS with returned struct by value > 8 bytes
			][
				#{C3}								;-- RET
			]
		][
			;; stdcall/reds: Consume original arguments from stack.
			either compiler/check-variable-arity? locals [
				emit #{5E}							;-- POP esi			; retrieve the return address
				emit #{59}							;-- POP ecx			; skip arguments count
				emit #{59}							;-- POP ecx			; skip arguments pointer
				emit #{59}							;-- POP ecx			; get stack offset
				emit #{01CC}						;-- ADD esp, ecx	; skip arguments list (clears stack)
				emit #{56}							;-- PUSH esi		; push return address
				emit #{C3}							;-- RET
			][
				emit #{C2}							;-- RETN args-size
				emit to-bin16 round/to/ceiling args-size 4
			]
		]
	]
]
