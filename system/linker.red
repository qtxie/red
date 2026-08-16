Red [
	Title:   "Red/System linker"
	Author:  "Nenad Rakocevic"
	File: 	 %linker.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

linker: context [
	target-64?: func [target [word!]][to logic! find [X86-64 ARM64] target]

	patch-arm64-page-ref: func [
		buffer [binary!]
		ptr [integer!]
		pc [integer!]
		target-ptr [integer!]
		reg [integer!]
		/local page-delta imm immlo immhi adrp add
	][
		page-delta: (target-ptr - (target-ptr // 4096))
			- (pc - (pc // 4096))
		if any [page-delta < -4294967296 page-delta > 4294963200][
			throw-error "ARM64 ADRP target is out of range"
		]
		imm: shift page-delta 12
		immlo: imm and 3
		immhi: shift/logical (imm and 2097148) 2
		adrp: (to integer! #{90000000}) or (immlo * 536870912) or (immhi * 32) or reg
		add: (to integer! #{91000000}) or ((target-ptr and 4095) * 1024)
			or (reg * 32) or reg
		change/part at buffer ptr int-to-bin/to-bin32 adrp 4
		change/part at buffer ptr + 4 int-to-bin/to-bin32 add 4
	]
	version: 		1.0.0							;-- emitted linker version
	cpu-class: 		'IA-32							;-- default target
	verbose: 		0								;-- logs verbosity level
	codegen-error: none

	read-codegen-word: func [data [binary!] offset [integer!] /local high][
		if any [offset < 0 (offset + 4) > (length? data)][return none]
		high: to integer! pick data (offset + 4)
		if high > 127 [return none]
		(to integer! pick data (offset + 1))
			+ ((to integer! pick data (offset + 2)) * 256)
			+ ((to integer! pick data (offset + 3)) * 65536)
			+ (high * 16777216)
	]

	codegen-fail: func [message [string!]][
		codegen-error: message
		false
	]

	; Native codegen emits the linker's own compact tables. There is no object
	; protocol or adapter between this reader and JOB/SECTIONS.
	load-codegen: func [
		job [object!]
		image [binary!]
		/local size kind entry function-count global-count import-count reference-count names-size
			code-offset code-size data-size functions-size globals-size imports-size refs-size
			globals-start imports-start refs-start names-start data-offset expected remainder id index record
			name-offset name-size function-offset function-size frame-size bitmap-offset
			bitmap-size global-offset global-size first-reference count-reference reference-id reference
			name-bytes name symbols refs imports functions library-offset library-size
			external-offset external-size library external last-library code data sections
	][
		codegen-error: none
		unless all [object? job binary? image (length? image) >= 44][
			return codegen-fail "native codegen returned a truncated image"
		]
		size: read-codegen-word image 0
		kind: read-codegen-word image 4
		entry: read-codegen-word image 8
		function-count: read-codegen-word image 12
		import-count: read-codegen-word image 16
		reference-count: read-codegen-word image 20
		names-size: read-codegen-word image 24
		code-offset: read-codegen-word image 28
		code-size: read-codegen-word image 32
		data-size: read-codegen-word image 36
		global-count: read-codegen-word image 40
		unless all [
			integer? size integer? kind integer? entry integer? function-count
			integer? import-count integer? reference-count integer? names-size
			integer? code-offset integer? code-size integer? data-size integer? global-count
			size = length? image
			kind = 3
			function-count > 0
			entry > 0 entry <= function-count
			global-count >= 0 import-count >= 0 reference-count >= 0 names-size > 0
			code-size > 0 data-size >= 0
		][return codegen-fail "native codegen returned an invalid image header"]

		if function-count > ((size - 44) / 36) [
			return codegen-fail "native codegen function table exceeds its image"
		]
		functions-size: function-count * 36
		globals-start: 44 + functions-size
		if global-count > ((size - globals-start) / 24) [
			return codegen-fail "native codegen global table exceeds its image"
		]
		globals-size: global-count * 24
		imports-start: globals-start + globals-size
		if import-count > ((size - imports-start) / 24) [
			return codegen-fail "native codegen import table exceeds its image"
		]
		imports-size: import-count * 24
		if reference-count > ((size - imports-start - imports-size) / 4) [
			return codegen-fail "native codegen reference table exceeds its image"
		]
		refs-size: reference-count * 4
		refs-start: imports-start + imports-size
		names-start: refs-start + refs-size
		if names-size > (size - names-start) [
			return codegen-fail "native codegen names exceed their image"
		]
		expected: names-start + names-size
		remainder: expected // 16
		if remainder <> 0 [expected: expected + 16 - remainder]
		unless code-offset = expected [
			return codegen-fail "native codegen code is not directly aligned after metadata"
		]
		if code-size > (size - code-offset) [
			return codegen-fail "native codegen code exceeds its image"
		]
		data-offset: code-offset + code-size
		remainder: data-offset // 4
		if remainder <> 0 [data-offset: data-offset + 4 - remainder]
		unless all [data-size <= (size - data-offset) size = (data-offset + data-size)][
			return codegen-fail "native codegen data does not finish its image"
		]

		symbols: make hash! ((function-count + global-count) * 2)
		id: 1
		while [id <= function-count][
			record: 44 + ((id - 1) * 36)
			name-offset: read-codegen-word image record
			name-size: read-codegen-word image (record + 4)
			function-offset: read-codegen-word image (record + 8)
			function-size: read-codegen-word image (record + 12)
			frame-size: read-codegen-word image (record + 16)
			bitmap-offset: read-codegen-word image (record + 20)
			bitmap-size: read-codegen-word image (record + 24)
			first-reference: read-codegen-word image (record + 28)
			count-reference: read-codegen-word image (record + 32)
			unless all [
				integer? name-offset integer? name-size name-size > 0
				name-offset <= (names-size - name-size)
				integer? function-offset integer? function-size function-size > 0
				function-offset <= (code-size - function-size)
				integer? frame-size frame-size >= 0
				integer? bitmap-offset integer? bitmap-size bitmap-size >= 0
				bitmap-offset <= (data-size - bitmap-size)
				integer? first-reference integer? count-reference count-reference >= 0
			][return codegen-fail "native codegen returned an invalid function record"]
			if any [
				all [count-reference = 0 first-reference <> 0]
				all [count-reference > 0 any [
					first-reference <= 0
					first-reference > reference-count
					count-reference > (reference-count - first-reference + 1)
				]]
			][return codegen-fail "native function references exceed their table"]
			if all [id = entry function-offset <> 0][
				return codegen-fail "executable entry is not the first code byte"
			]
			name-bytes: copy/part at image (names-start + name-offset + 1) name-size
			if find name-bytes 0 [return codegen-fail "native function name contains NUL"]
			name: attempt [to word! to string! name-bytes]
			unless word? name [return codegen-fail "native function name is not a Red word"]
			if find symbols name [return codegen-fail "native codegen returned duplicate symbols"]
			refs: make block! count-reference
			reference-id: first-reference
			repeat index count-reference [
				reference: read-codegen-word image
					(refs-start + ((reference-id - 1) * 4))
				unless all [integer? reference reference <= (code-size - 4)][
					return codegen-fail "native function reference exceeds code"
				]
				append refs reference + 1
				reference-id: reference-id + 1
			]
			append symbols name
			append/only symbols reduce ['native (function-offset + 1) refs]
			id: id + 1
		]

		id: 1
		while [id <= global-count][
			record: globals-start + ((id - 1) * 24)
			name-offset: read-codegen-word image record
			name-size: read-codegen-word image (record + 4)
			global-offset: read-codegen-word image (record + 8)
			global-size: read-codegen-word image (record + 12)
			first-reference: read-codegen-word image (record + 16)
			count-reference: read-codegen-word image (record + 20)
			unless all [
				integer? name-offset integer? name-size name-size > 0
				name-offset <= (names-size - name-size)
				integer? global-offset global-offset >= 16
				integer? global-size global-size >= 0
				global-offset <= (data-size - global-size)
				integer? first-reference integer? count-reference count-reference >= 0
			][return codegen-fail "native codegen returned an invalid global record"]
			if any [
				all [count-reference = 0 first-reference <> 0]
				all [count-reference > 0 any [
					first-reference <= 0
					first-reference > reference-count
					count-reference > (reference-count - first-reference + 1)
				]]
			][return codegen-fail "native global references exceed their table"]
			name-bytes: copy/part at image (names-start + name-offset + 1) name-size
			if find name-bytes 0 [return codegen-fail "native global name contains NUL"]
			name: attempt [to word! to string! name-bytes]
			unless word? name [return codegen-fail "native global name is not a Red word"]
			if find symbols name [return codegen-fail "native codegen returned duplicate symbols"]
			refs: make block! count-reference
			reference-id: first-reference
			repeat index count-reference [
				reference: read-codegen-word image
					(refs-start + ((reference-id - 1) * 4))
				unless all [integer? reference reference <= (code-size - 4)][
					return codegen-fail "native global reference exceeds code"
				]
				append refs reference + 1
				reference-id: reference-id + 1
			]
			append symbols name
			append/only symbols reduce ['global global-offset refs]
			id: id + 1
		]

		imports: make block! (import-count * 2)
		last-library: none
		functions: none
		id: 1
		while [id <= import-count][
			record: imports-start + ((id - 1) * 24)
			library-offset: read-codegen-word image record
			library-size: read-codegen-word image (record + 4)
			external-offset: read-codegen-word image (record + 8)
			external-size: read-codegen-word image (record + 12)
			first-reference: read-codegen-word image (record + 16)
			count-reference: read-codegen-word image (record + 20)
			unless all [
				integer? library-offset integer? library-size library-size > 0
				library-offset <= (names-size - library-size)
				integer? external-offset integer? external-size external-size > 0
				external-offset <= (names-size - external-size)
				integer? first-reference first-reference > 0
				integer? count-reference count-reference > 0
				first-reference <= reference-count
				count-reference <= (reference-count - first-reference + 1)
			][return codegen-fail "native codegen returned an invalid import record"]
			library: to string! copy/part at image
				(names-start + library-offset + 1) library-size
			external: to string! copy/part at image
				(names-start + external-offset + 1) external-size
			if any [find to binary! library 0 find to binary! external 0][
				return codegen-fail "native import name contains NUL"
			]
			unless library = last-library [
				last-library: library
				functions: make block! 8
				append imports library
				append/only imports functions
			]
			refs: make block! count-reference
			reference-id: first-reference
			repeat index count-reference [
				reference: read-codegen-word image
					(refs-start + ((reference-id - 1) * 4))
				unless all [integer? reference reference <= (code-size - 4)][
					return codegen-fail "native import reference exceeds code"
				]
				append refs reference + 1
				reference-id: reference-id + 1
			]
			append functions external
			append/only functions refs
			id: id + 1
		]

		code: copy/part at image (code-offset + 1) code-size
		data: copy/part at image (data-offset + 1) data-size
		sections: make block! 6
		append sections 'code
		append/only sections reduce ['- code]
		append sections 'data
		append/only sections reduce ['- data]
		unless empty? imports [
			append sections 'import
			append/only sections reduce ['- '- imports]
		]
		set in job 'sections sections
		set in job 'symbols symbols
		set in job 'debug-info none
		true
	]

	line-record!: virtual-struct/make-value [
		ptr		[integer!]							;-- code pointer
		line	[integer!]							;-- line number
		file	[integer!]							;-- filename string offset
	] none

	func-record!: virtual-struct/make-value [					;-- debug lines records associating code addresses and source lines
		address [integer!]							;-- entry point of the funcion
		name	[integer!]							;-- function's name c-string offset (from first record)
		arity	[integer!]							;-- function's arity
		args	[integer!]							;-- array of arguments types pointer
	] none

	job-class: context [
		format: 									;-- 'PE | 'ELF | 'Mach-o
		type: 										;-- 'exe | 'obj | 'lib | 'dll | 'drv
		target:										;-- CPU identifier
		sections:									;-- code/data sections
		flags:										;-- global flags
		sub-system:									;-- target environment (GUI | console)
		symbols:									;-- symbols table
		output:										;-- output file name (without extension)
		debug-info:									;-- debugging informations
		base-address:								;-- base address
		static-objs:								;-- external C objects for static linking
		static-data:								;-- libc data-symbol imports [name offset size ...]
		PIE?:										;-- position independent executable
		buffer: none								;-- output buffer
		static-align: 1								;-- peak alignment of merged static sections
	]

	throw-error: func [err [word! string! block!] /warn][
		print [
			"*** Linker" pick ["Warning:" "Error:"] to-logic warn
			either word? err [
				join uppercase/part mold err 1 " error"
			][reform err]
			lf
		]
		unless warn [system-dialect/compiler/quit-on-error]
	]

	set-ptr: func [job [object!] name [word!] value [integer!] /local spec][
		if spec: find job/symbols name [
			spec/2/2: value
		]
	]

	set-integer-at: func [job [object!] pos [integer!] value [integer!] /local spec][
		change/part at job/sections/data/2 pos + 1 int-to-bin/to-bin32 value 4
	]

	set-integer: func [job [object!] name [word!] value [integer!] /local spec][
		if spec: find job/symbols name [
			change/part at job/sections/data/2 spec/2/2 + 1 int-to-bin/to-bin32 value 4
		]
	]

	check-dup-symbols: func [job [object!] imports [block!] /local exports dup][
		all [
			exports: select job/sections 'export
			not empty? dup: intersect imports exports/3
			throw-error/warn [
				"possibly conflicting import and export symbols:" dup
			]
		]
	]

	set-image-info: func [
		job			 [object!]
		base-address [integer!]
		code-offset	 [integer!]
		code-size	 [integer!]
		data-offset	 [integer!]
		data-size	 [integer!]
		rodata-offset [integer!]					;-- protected data (0 if none / already RO by segment)
		rodata-size	 [integer!]
		/high
			base-address-high [integer!]
		/local
			spec bits-offset struct-offset field-offset image-base
	][
		unless job/runtime? [exit]
		bits-offset: second second find job/symbols '***-ptr-bitmaps
		spec: find job/symbols '***-exec-image
		struct-offset: either target-64? job/target [8][4]
		;-- ARM64 PIC startup derives the load base from this struct's runtime address.
		image-base: either all [job/PIC? job/target = 'ARM64][
			data-offset + spec/2/2 + struct-offset
		][base-address]
		field-offset: struct-offset
		either target-64? job/target [
			change/part
				at job/sections/data/2 spec/2/2 + field-offset + 1
				rejoin [
					int-to-bin/to-bin32 image-base
					int-to-bin/to-bin32 any [base-address-high 0]
				]
				8
			field-offset: field-offset + 8
		][
			set-integer-at job spec/2/2 + field-offset image-base
			field-offset: field-offset + 4
		]
		set-integer-at job spec/2/2 + field-offset      code-offset
		set-integer-at job spec/2/2 + field-offset + 4  code-size
		set-integer-at job spec/2/2 + field-offset + 8  data-offset
		set-integer-at job spec/2/2 + field-offset + 12 data-size
		set-integer-at job spec/2/2 + field-offset + 16 data-offset + bits-offset
		set-integer-at job spec/2/2 + field-offset + 20 rodata-offset
		set-integer-at job spec/2/2 + field-offset + 24 rodata-size
	]

	resolve-symbol-refs: func [
		job 	   [object!]
		cbuf 	   [binary!]						;-- code buffer
		dbuf 	   [binary!]						;-- data buffer
		robuf	   [binary!]						;-- read-only data buffer
		code-ptr   [integer!]						;-- code memory address
		data-ptr   [integer!]						;-- data memory address
		rodata-ptr [integer!]						;-- read-only data memory address
		pointer	   [object!]
		/local
			data-offset ro-offset ptr target-ptr
	][
		data-offset: either job/PIC? [data-ptr - code-ptr][data-ptr]
		ro-offset:	 either job/PIC? [rodata-ptr - code-ptr][rodata-ptr]
		foreach [name spec] job/symbols [
			unless empty? spec/3 [
				case [
					job/target = 'ARM64 [
						foreach ref spec/3 [
							either block? ref [
								target-ptr: case [
									spec/1 = 'global [data-ptr + spec/2]
									spec/1 = 'constant [rodata-ptr + spec/2]
									spec/1 = 'native-ref [code-ptr + spec/2 - 1]
								]
								if integer? target-ptr [
									patch-arm64-page-ref
										cbuf ref/1 code-ptr + ref/1 - 1 target-ptr ref/2
								]
							][
								unless find [import import-var] spec/1 [
									throw-error [
										"invalid ARM64 symbol reference:"
										name "type:" spec/1 "ref:" mold ref
									]
								]
							]
						]
					]
					job/target = 'X86-64 [
					parse spec/3 [
						any [
							ref: integer! (
								target-ptr: case [
									spec/1 = 'global [
										(data-ptr + spec/2) - (code-ptr + ref/1 - 1 + 4)
									]
									spec/1 = 'constant [
										(rodata-ptr + spec/2) - (code-ptr + ref/1 - 1 + 4)
									]
									spec/1 = 'native-ref [
										(spec/2 - 1) - (ref/1 - 1 + 4)
									]
								]
								if integer? target-ptr [
									change/part at cbuf ref/1 int-to-bin/to-bin32 target-ptr 4
								]
							)
							| skip
						]
					]
					]
					true [
					all [
						any [
							all [
								spec/1 = 'global		;-- code to data references
								pointer/value: data-offset + spec/2
							]
							all [
								spec/1 = 'constant		;-- code to read-only data references
								pointer/value: ro-offset + spec/2
							]
							all [
								spec/1 = 'native-ref	;-- code to code references
								pointer/value: either job/PIC? [spec/2][code-ptr + spec/2]
							]
						]
						ptr: virtual-struct/form-value pointer
						parse spec/3 [any [ref: integer! (change at cbuf ref/1 ptr) | skip]]
					]
					]
				]
			]
			if block? spec/4 [
				pointer/value: case [
					spec/1 = 'global [data-ptr + spec/2]	;-- data to data references
					spec/1 = 'constant [rodata-ptr + spec/2]
					'else [code-ptr + spec/2 - 1]			;-- data to code references (base-relative addend; rebased via reloc under PIC)
				]
				ptr: virtual-struct/form-value pointer
				foreach ref spec/4 [					;-- negative refs live in the read-only buffer
					either negative? ref [
						change at robuf negate ref ptr
					][
						change at dbuf ref ptr
					]
				]
			]
		]
	]

	get-debug-lines-size: func [job [object!] /local size][
		size: 12 * (length? job/debug-info/lines/records) / 3
		foreach file job/debug-info/lines/files [
			size: size + 1 + length? file			;-- file is supposed to be FORMed not MOLDed
		]
		size
	]

	build-debug-lines: func [
		job 	 [object!]
		code-ptr [integer!]							;-- code memory address
		/local	records files rec-size buffer table strings record data-buf spec
	][
		records: job/debug-info/lines/records
		files: job/debug-info/lines/files

		rec-size: 12 * (length? records) / 3 		;-- 12 = pointer! + integer! + integer!
													;--  3 = nb of elements in records (flat structure)
		buffer:  make binary! rec-size		 		;-- main buffer
		table:   make block! length? files	 		;-- intermediary file strings offsets table
		strings: make binary! 32 * length? files	;-- file strings buffer

		foreach file files [
			append table length? strings			;-- save file string offsets
			append strings form file
			append strings null
		]

		record: virtual-struct/make-value line-record! none
		while [not tail? records][
			record/ptr:  code-ptr + records/1 - 1
			record/line: records/2
			record/file: rec-size + pick table records/3	;-- store file offsets
			append buffer virtual-struct/form-value record
			records: skip records 3
		]
		data-buf: job/sections/data/2
		set-ptr job '__debug-lines length? data-buf	;-- patch __debug-lines symbol to point to 1st record
		set-integer job '__debug-lines-nb (length? records) / 3

		append data-buf buffer
		append data-buf strings
	]

	undecorate: func [name [word!]][
		name: form name
		if find/match name "exec/" [name: skip name 5]
		if find/match name "f_" [name: skip name 2]
		name
	]

	is-native?: func [name [word! tag!] spec [block!]][
		all [spec/1 = 'native not find [_div_ _udiv_ _i64_div_] name]
	]

	get-debug-funcs-size: func [job [object!] /local size sc name spec][
		sc: system-dialect/compiler
		size: 0
		foreach [name spec] job/symbols [
			if is-native? name spec [
				size: size + 1 + (length? undecorate name)
					+ 16							;-- size of a record
					+ sc/get-arity sc/functions/:name/4
			]
		]
		size
	]

	build-debug-func-names: func [
		job 	 [object!]
		code-ptr [integer!]							;-- code memory address
		/local buffer specs args arity sc list rec-size record name name-ptr args-ptr data-buf spec nb entry-ptr
	][
		sc: system-dialect/compiler
		list: make block! 4000

		foreach [name spec] job/symbols [
			if is-native? name spec [
				append list name
				append list spec/2
			]
		]
		nb:	(length? list) / 2
		rec-size: 16 * nb
		buffer:	make binary! rec-size		 		;-- main buffer
		specs:  make binary! rec-size + 10'000		;-- funcs name + args spec

		foreach [name entry-ptr] list [
			set [arity args] sc/get-args-array name
			name-ptr: rec-size + length? specs
			append specs undecorate name
			append specs null

			either arity > 0 [
				args-ptr: rec-size + length? specs
				append specs args
			][
				args-ptr: 0
			]
			if name = '***_start [args-ptr: -1]	;-- set a barrier for call stack reporting

			record: virtual-struct/make-value func-record! none
			record/address: code-ptr + entry-ptr - 1
			record/name:	name-ptr
			record/arity:	arity
			record/args:	args-ptr
			append buffer virtual-struct/form-value record
			if job/verbosity >= 3 [print [to-hex record/address #":" name]]
		]
		data-buf: job/sections/data/2
		set-ptr job '__debug-funcs length? data-buf		;-- patch __debug-funcs symbol to point to 1st record
		set-integer job '__debug-funcs-nb nb

		append data-buf buffer
		append data-buf specs
	]

	show-funcs-map: func [
		job 	 [object!]
		code-ptr [integer!]							;-- code memory address
		/local name spec
	][
		print "^/--- Functions entry points ---"
		foreach [name spec] job/symbols [
			if is-native? name spec [print [to-hex code-ptr + spec/2 - 1 #":" name]]
		]
		print "--- end ---^/"
	]

	clean-imports: func [imports [block!]][			;-- remove unused imports
		foreach [lib list] imports/3 [
			remove-each [name refs] list [empty? refs]
		]
	]

	make-filename: func [job [object!] /local base provided suffix][
		provided: suffix? base: job/build-basename
		suffix: any [
			job/build-suffix
			system-file-extension job
		]
		if any [none? suffix suffix <> provided][
			base: join base suffix
		]
		join any [job/build-prefix %""] base
	]

	build: func [job [object!] /local file][
		unless job/target [job/target: cpu-class]
		job/buffer: make binary! 512 * 1024

		if all [find job/sections 'rodata job/type = 'obj][
			throw-error "protected data is not supported for object file output"
		]

		external-linker/merge job					;-- merge optional external C objects

		clean-imports job/sections/import

		emit-system-file job

		file: make-filename job
		if verbose >= 1 [print ["output file:" file]]

		if error? try [write/binary file job/buffer][
			throw-error ["locked or unreachable file:" to-local-file file]
		]

		finish-system-file job file

		;if find get-modes file 'file-modes 'owner-execute [
		;	set-modes file [owner-execute: true]
		;]
		file
	]

]
