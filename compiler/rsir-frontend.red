Red [
	Title: "Compact Red/System IR frontend"
	File:  %rsir-frontend.red
]

unless value? 'int-to-bin [do %int-to-bin.red]
unless value? 'ieee-754 [do %ieee-754.red]
unless value? 'unicode [do %unicode.red]

compiler-rsir-frontend: context [
	DEFAULT-MAX-BYTES: 16777216

	ERROR-ARGUMENTS: 1
	ERROR-KIND: 2
	ERROR-LIMIT: 3
	ERROR-NAME: 4
	ERROR-FUNCTION-COUNT: 5
	ERROR-UNSUPPORTED: 6
	ERROR-DUPLICATE: 7
	ERROR-REFERENCE: 8
	ERROR-CONTEXT: 9

	last-error: none
	error-position: none
	warnings: make block! 32
	definitions: none
	module-kind: 0
	debug?: false
	runtime-library?: false
	red-pass?: false
	runtime-functions: make block! 512
	runtime-specs: make map! 1024
	functions: make block! (10 * 256)
	function-ids: make map! 256
	call-ids: make map! 512
	infix-targets: make hash! 16
	contexts: make map! 32
	context-members: make map! 32
	types: make block! (5 * 128)
	type-ids: make map! 128
	enum-types: make map! 32
	enum-values: make map! 128
	pointer-types: make map! 64
	array-types: make map! 64
	aggregate-types: make map! 64
	canonical-refs: make block! 128
	ref-kinds: make block! 128
	function-types: make map! 64
	function-call-types: make block! 256
	import-call-types: make block! 256
	subroutine-types: make map! 16
	typed-call-types: make map! 64
	alias-type-ids: make map! 64
	literal-values: make map! 256
	protected: make map! 64
	resolved-functions: make map! 64
	resolved-imports: make map! 64
	resolved-calls: make map! 64
	resolved-globals: make map! 64
	resolved-literals: make map! 32
	resolved-protected: make map! 16
	resolved-value-kinds: make map! 64
	resolved-value-ids: make map! 64
	resolved-value-id: none
	imports: make block! (10 * 64)
	import-ids: make map! 256
	libraries: make map! 32
	exports: make block! (5 * 32)
	export-names: make hash! 32
	globals: make map! 1024
	global-data: make block! (5 * 384)
	boot-code: make binary! (16 * 1024)
	boot-locals: make block! 12
	module-code: make binary! (16 * 1024)
	module-locals: make block! 12
	active-module-code: none
	active-module-locals: none
	split-module?: false
	user-code?: false
	function-code: make binary! (1024 * 1024)
	function-states: make block! 256
	no-return-functions: make map! 64
	initializers: make binary! (16 * 256)
	switches: make binary! (12 * 128)
	strings: make binary! (2 * 1024)
	native-names: make map! 32
	native-name-patches: make block! 32
	function-count: 0
	context-count: 0
	type-count: 0
	import-count: 0
	global-count: 0
	alias-count: 0

	type-kinds: make map! [
		int8! i8 byte! byte uint8! u8 int16! i16 uint16! u16
		integer! i32 int32! i32 uint32! u32 int64! i64 uint64! u64
		float32! f32 float! f64 float64! f64 logic! logic
		pointer! pointer c-string! c-string struct! pointer union! pointer
		function! pointer subroutine! pointer array! pointer
		byte-ptr! pointer int-ptr! pointer ptr-ptr! pointer
		float32-ptr! pointer
	]
	reserved-words: make hash! [
		alias as assert break case catch comment context continue declare
		either exit func function if loop not overflow? pop protect push return
		size? switch throw until use variant? while with any all
	]

	type-codes: make map! [
		i8 1 u8 2 i16 3 u16 4 i32 5 u32 6 i64 7 u64 8
		f32 9 f64 10 logic 11 pointer 12 c-string 13 null 14 byte 15
		alias -1 struct -2 union -3 function -4 subroutine -5
		pointer-node -6 array -7 typed-call -8
	]
	builtin-pointees: make map! [
		byte-ptr! [byte!]
		int-ptr! [integer!]
		ptr-ptr! [pointer!]
		float32-ptr! [float32!]
	]

	cdecl-flag: 1
	return-value-flag: 4
	variadic-flag: 8
	typed-flag: 16
	custom-flag: 32
	callback-flag: 64
	objc-flag: 128
	catch-flag: 256
	red-internal-flag: 512
	no-return-flag: 1024
	call-shape-flags: return-value-flag + variadic-flag + typed-flag
		+ custom-flag + objc-flag
	inline-flag: 1
	protected-flag: 2
	tagged-type-flag: 1
	scalar-initializer: 1
	address-initializer: 2
	bytes-initializer: 3

	; Semantic postfix operations. Operands are typed by the surrounding
	; declaration tables; no source-specific value IDs cross the boundary.
	literal-op: 1
	constant-op: 2
	address-op: 3
	load-op: 4
	set-op: 5
	member-op: 6
	call-op: 7
	cast-op: 8
	size-op: 9
	native-op: 10
	return-op: 11
	drop-op: 12
	duplicate-op: 13
	unary-op: 14
	binary-op: 15
	jump-op: 16
	branch-op: 17
	switch-op: 18
	fail-op: 19
	reference-op: 20
	index-op: 21
	tag-op: 22
	overflow-op: 23
	catch-op: 24
	end-catch-op: 25
	throw-op: 26
	entry-op: 27
	subroutine-call-op: 28
	subroutine-return-op: 29

	; Operation IDs follow the language families, not source spellings or x64
	; encodings. The postfix stream preserves the specified left-to-right order.
	not-operation: 1
	binary-operations: make map! [
		+   1  -   2  *   3  /   4  %   5  //  6
		<<  7  >>  8  >>> 9  or 10  xor 11  and 12
		=  13  <> 14  >  15  <  16  >= 17  <= 18
	]

	local-address: 1
	global-address: 2
	import-address: 3
	function-address: 4

	stack-top-native: 1
	stack-push-native: 2
	stack-pop-native: 3
	stack-frame-native: 4
	stack-top-set-native: 5
	stack-frame-set-native: 6
	stack-align-native: 7
	stack-allocate-native: 8
	stack-allocate-zero-native: 9
	stack-free-native: 10
	stack-push-all-native: 11
	stack-pop-all-native: 12
	program-counter-native: 13
	cpu-register-native: 14
	cpu-register-set-native: 15
	cpu-overflow-native: 16
	atomic-fence-native: 17
	atomic-load-native: 18
	atomic-store-native: 19
	atomic-cas-native: 20
	atomic-math-native: 21
	log-b-native: 22
	atomic-old-flag: 8
	atomic-operations: make map! [
		add 1 sub 2 or 3 xor 4 and 5
	]
	statement-value: 0
	expression-value: 1
	tail-value: 2
	inferred-value: 3

	last-type: 0
	last-flags: 0
	last-stopped?: false
	function-base: 0
	function-return: 0
	function-flags: 0
	function-active?: false
	function-returns?: false
	function-scope: none
	function-uses: none
	active-function: none
	loops: make block! 8
	overflows: make block! 8
	catches: make block! 8
	thrown-global: 0
	; Function-local lexical constructs are lowered while the postfix stream is
	; built. USE slots stay in the frame table, while their names are tombstoned
	; when the lexical body ends. Subroutine bodies precede the main body and are
	; emitted once, with direct intra-function calls.
	use-local-slots: make map! 32
	function-storage: make map! 64
	; name [body entry result stopped? state]
	subroutines: make map! 32
	subroutine-order: make block! 16
	active-subroutine: none
	subroutine-inferred: make map! 16
	static?: false
	static-ref: 0
	static-low: 0
	static-high: 0
	static-flags: 0
	static-initializer: none
	static-next: none

	emit: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
	]

	emit-native-register: func [
		instructions [binary!]
		operation [integer!]
		name [word!]
	][
		append/only native-name-patches instructions
		append native-name-patches (length? instructions) + 9
		append native-name-patches name
		emit instructions reduce [native-op operation 0 0]
	]

	finish-native-names: func [
		/local patch info bytes code offset
	][
		clear native-names
		patch: native-name-patches
		while [not tail? patch][
			info: select native-names patch/3
			unless block? info [
				bytes: to binary! form patch/3
				info: reduce [length? strings length? bytes]
				put native-names patch/3 info
				append strings bytes
			]
			code: patch/1
			offset: patch/2
			change/part at code offset int-to-bin/to-bin32 info/1 4
			change/part at code (offset + 4) int-to-bin/to-bin32 info/2 4
			patch: skip patch 3
		]
		clear native-name-patches
	]

	instruction-here: func [output [binary!] return: [integer!]][
		1 + to integer! (((length? output) / 16) - function-base)
	]

	emit-control: func [
		output [binary!]
		op sense [integer!]
		return: [integer!]
		/local patch
	][
		patch: (length? output) + 5
		emit output reduce [op 0 sense 0]
		patch
	]

	patch-control: func [output [binary!] patch target [integer!]][
		change/part at output patch int-to-bin/to-bin32 target 4
	]

	patch-control-drop: func [output [binary!] patch count [integer!]][
		change/part at output (patch + 4) int-to-bin/to-bin32 count 4
	]

	patch-control-catches: func [output [binary!] patch count [integer!]][
		change/part at output (patch + 8) int-to-bin/to-bin32 count 4
	]

	emit-switch-case: func [low high [integer!] return: [integer!] /local patch][
		patch: (length? switches) + 9
		emit switches reduce [low high 0]
		patch
	]

	patch-switch-case: func [patch target [integer!]][
		change/part at switches patch int-to-bin/to-bin32 target 4
	]

	add-hidden-local: func [
		params locals [block!]
		ref flags [integer!]
		return: [integer!]
		/local slot
	][
		slot: 1 + ((length? params) / 3) + storage-local-count locals
		append locals none
		append locals ref
		append locals flags
		; Hidden temporaries have no source name, so they remain usable only
		; through the instruction slot returned here.
		slot
	]

	add-hidden-global: func [ref flags [integer!] return: [integer!] /local id][
		id: global-count + 1
		append/only global-data make binary! 0
		append global-data ref
		append global-data flags
		append global-data 0
		append global-data 0
		global-count: id
		id
	]

	add-global: func [
		key [word! string!]
		return: [integer!]
		/local id spelling
	][
		spelling: form key
		unless valid-name? spelling [fail ERROR-NAME "invalid RSIR global name"]
		id: global-count + 1
		put globals key id
		append/only global-data to binary! spelling
		append global-data none
		append global-data 0
		append global-data 0
		append global-data 0
		global-count: id
		id
	]

	ensure-thrown-global: func [return: [integer!]][
		if thrown-global = 0 [thrown-global: add-hidden-global -5 0]
		thrown-global
	]

	set-global-initializer: func [
		record [block!]
		values [block!]
		/local count data
	][
		unless ((length? values) // 4) = 0 [
			fail ERROR-UNSUPPORTED "invalid static initializer"
		]
		count: (length? values) / 4
		unless all [count > 0 record/5 = 0][
			fail ERROR-UNSUPPORTED "global value is already initialized"
		]
		data: make binary! (count * 16)
		emit data values
		record/4: data
		record/5: count
	]

	write-initializers: func [/local position data][
		clear initializers
		position: global-data
		while [not tail? position][
			data: position/4
			either binary? data [
				position/4: (length? initializers) / 16
				append initializers data
			][position/4: 0]
			position: skip position 5
		]
	]

	emit-local-address: func [output [binary!] slot [integer!]][
		emit output reduce [address-op local-address slot 0]
	]

	storage-local?: func [record [block!] return: [logic!]][
		(ref-kind record/2) <> 'subroutine
	]

	storage-local-count: func [locals [block!] return: [integer!] /local count record][
		count: 0
		record: locals
		while [not tail? record][
			if storage-local? record [count: count + 1]
			record: skip record 3
		]
		count
	]

	logical-value?: func [ref flags [integer!] return: [logic!]][
		all [stack-type-compatible? -11 ref flags = 0]
	]

	fail: func [code [integer!] message [string! block!] /local error][
		error: make object! [code: 0 message: none position: none]
		error/code: code
		error/message: form either block? message [reduce message][message]
		error/position: error-position
		last-error: error
		throw/name error 'rsir-error
	]

	warn: func [message [string! block!]][
		append/only warnings form either block? message [reduce message][message]
	]

	source-name: func [value return: [string!]][
		either binary? value [to string! copy value][form value]
	]

	valid-name?: func [name [string!]][
		all [not empty? name not find name #"^(00)"]
	]

	qualified: func [scope [block!] value [word! path!] /local output item][
		if all [empty? scope word? value][return value]
		output: make string! 48
		foreach item scope [
			unless empty? output [append output ">"]
			append output form item
		]
		either path? value [
			foreach item value [
				unless empty? output [append output ">"]
				append output form item
			]
		][
			unless empty? output [append output ">"]
			append output form value
		]
		output
	]

	extend-scope: func [scope [block!] value [word! path!] /local output item][
		output: copy scope
		either path? value [
			foreach item value [append output item]
		][
			append output value
		]
		output
	]

	root-qualified?: func [value [word! path!]][
		all [
			path? value
			(length? value) > 2
			value/1 = 'system
			value/2 = 'words
		]
	]

	root-name: func [value [path!] /local parts][
		parts: skip to block! value 2
		either (length? parts) = 1 [parts/1][to path! copy parts]
	]

	context-rank: func [scope [block!] /local key rank][
		if empty? scope [return 0]
		key: qualified (copy/part scope ((length? scope) - 1)) (last scope)
		rank: select contexts key
		any [rank 0]
	]

	context-scope-key: func [
		scope [block!]
		return: [word! string! none!]
	][
		if empty? scope [return none]
		qualified (copy/part scope ((length? scope) - 1)) (last scope)
	]

	add-context-word: func [scope [block!] name [word!] /local members][
		if empty? scope [exit]
		members: select context-members context-scope-key scope
		if all [hash? members not find members name][append members name]
	]

	warn-context-collisions: func [
		scopes [block!]
		/local seen duplicates names scope members name
	][
		if (length? scopes) < 2 [exit]
		seen: make hash! 32
		duplicates: make hash! 8
		names: make block! 8
		foreach scope scopes [
			members: select context-members context-scope-key scope
			if hash? members [
				foreach name members [
					either find seen name [
						unless find duplicates name [
							append duplicates name
							append names name
						]
					][append seen name]
				]
			]
		]
		unless empty? names [
			warn rejoin [
				"contexts are using identical word"
				either (length? names) > 1 ["s: "][": "]
				form names
			]
		]
	]

	resolve-used-name: func [
		value [word! path!]
		uses [block!]
		names [map!]
		/local found best imported key candidate rank
	][
		found: none
		best: -1
		foreach imported uses [
			key: qualified imported value
			candidate: select names key
			unless none? candidate [
				rank: context-rank imported
				if rank > best [
					found: candidate
					best: rank
				]
			]
		]
		found
	]

	resolve-name-in: func [
		value [word! path!]
		scope uses [block!]
		names [map!]
		/local depth key id
	][
		if root-qualified? value [
			value: root-name value
			key: qualified copy [] value
			return select names key
		]
		depth: length? scope
		while [depth > 0][
			key: qualified copy/part scope depth value
			if id: select names key [return id]
			depth: depth - 1
		]
		id: resolve-used-name value uses names
		unless none? id [return id]
		key: qualified copy [] value
		select names key
	]

	clear-resolved-names: does [
		clear resolved-functions
		clear resolved-imports
		clear resolved-calls
		clear resolved-globals
		clear resolved-literals
		clear resolved-protected
		clear resolved-value-kinds
		clear resolved-value-ids
	]

	exact-value-kind: func [
		key [word! string!]
		return: [integer!]
		/local id record
	][
		if find literal-values key [
			resolved-value-id: select literal-values key
			return 1
		]
		if id: select call-ids key [resolved-value-id: id return 2]
		if id: select globals key [resolved-value-id: id return 3]
		if id: select import-ids key [
			record: skip imports ((id - 1) * 10)
			if record/5 = 'variable [resolved-value-id: id return 4]
		]
		resolved-value-id: none
		0
	]

	resolve-value-kind: func [
		value [word! path!]
		scope uses [block!]
		return: [integer!]
		/local cache-key depth key kind imported rank best best-kind best-id root?
	][
		cache-key: either word? value [value][form value]
		if all [
			function-active?
			same? scope function-scope
			same? uses function-uses
			find resolved-value-kinds cache-key
		][
			kind: select resolved-value-kinds cache-key
			resolved-value-id: select resolved-value-ids cache-key
			return kind
		]
		kind: 0
		root?: root-qualified? value
		if root? [
			value: root-name value
			kind: exact-value-kind qualified copy [] value
		]
		if all [kind = 0 not root?][
			depth: length? scope
			while [depth > 0][
				key: qualified copy/part scope depth value
				kind: exact-value-kind key
				if kind <> 0 [break]
				depth: depth - 1
			]
		]
		if all [kind = 0 not root?][
			best: -1
			best-kind: 0
			best-id: none
			foreach imported uses [
				key: qualified imported value
				kind: exact-value-kind key
				if kind <> 0 [
					rank: context-rank imported
					if rank > best [
						best: rank
						best-kind: kind
						best-id: resolved-value-id
					]
				]
			]
			kind: best-kind
			resolved-value-id: best-id
		]
		if all [kind = 0 not root?][
			kind: exact-value-kind qualified copy [] value
		]
		if all [function-active? same? scope function-scope same? uses function-uses][
			put resolved-value-kinds cache-key kind
			if kind <> 0 [put resolved-value-ids cache-key resolved-value-id]
		]
		kind
	]

	name-cache: func [
		names [map!]
		scope uses [block!]
		return: [map! none!]
	][
		unless all [
			function-active?
			same? scope function-scope
			same? uses function-uses
		][return none]
		case [
			same? names function-ids [resolved-functions]
			same? names import-ids [resolved-imports]
			same? names call-ids [resolved-calls]
			same? names globals [resolved-globals]
			same? names literal-values [resolved-literals]
			same? names protected [resolved-protected]
			true [none]
		]
	]

	resolve-name: func [
		value [word! path!]
		scope uses [block!]
		names [map!]
		/local cache key id
	][
		cache: name-cache names scope uses
		if map? cache [
			key: either word? value [value][form value]
			if find cache key [return select cache key]
		]
		id: resolve-name-in value scope uses names
		if map? cache [put cache key id]
		id
	]

	import-variable-id: func [
		value [word! path!]
		scope uses [block!]
		/local id record
	][
		unless id: resolve-name value scope uses import-ids [return none]
		record: skip imports ((id - 1) * 10)
		either record/5 = 'variable [id][none]
	]

	resolve-context: func [
		value [word! path!]
		scope uses [block!]
		/local depth key imported id found best
	][
		if root-qualified? value [
			value: root-name value
			key: qualified copy [] value
			if select contexts key [return extend-scope copy [] value]
			return none
		]
		depth: length? scope
		while [depth > 0][
			key: qualified copy/part scope depth value
			if select contexts key [
				return extend-scope copy/part scope depth value
			]
			depth: depth - 1
		]
		found: none
		best: -1
		foreach imported uses [
			key: qualified imported value
			id: select contexts key
			if all [integer? id id > best][
				found: extend-scope imported value
				best: id
			]
		]
		if block? found [return found]
		key: qualified copy [] value
		if select contexts key [return extend-scope copy [] value]
		none
	]

	resolve-with: func [
		target [word! path! block!]
		scope uses [block!]
		/local values result value child
	][
		values: either block? target [target][reduce [target]]
		if empty? values [fail ERROR-CONTEXT "WITH requires a context"]
		result: make block! length? values
		foreach value values [
			unless any [word? value path? value][
				fail ERROR-CONTEXT ["invalid WITH context " mold value]
			]
			unless child: resolve-context value scope uses [
				fail ERROR-CONTEXT ["unknown context " mold value]
			]
			unless find/only result child [append/only result child]
		]
		warn-context-collisions result
		result
	]

	context-member-key: func [
		value [path!]
		scope uses [block!]
		return: [word! string! none!]
		/local parts count parent member child
	][
		parts: to block! value
		count: length? parts
		if count < 2 [return none]
		member: last parts
		unless word? member [return none]
		parent: either count = 2 [parts/1][to path! copy/part parts (count - 1)]
		unless any [word? parent path? parent][return none]
		child: resolve-context parent scope uses
		if block? child [qualified child member]
	]

	add-context-global: func [
		value [path!]
		scope uses [block!]
		return: [integer! none!]
		/local key
	][
		unless key: context-member-key value scope uses [return none]
		if any [
			select globals key
			select function-ids key
			select import-ids key
			select protected key
			select literal-values key
			select contexts key
			select type-ids key
		][return none]
		clear-resolved-names
		add-global key
	]

	used-value?: func [
		value [word! path!]
		uses [block!]
		count [integer!]
		/local active
	][
		if count = 0 [return false]
		active: skip uses ((length? uses) - count)
		not none? any [
			resolve-used-name value active globals
			resolve-used-name value active import-ids
			resolve-used-name value active function-ids
			resolve-used-name value active protected
			resolve-used-name value active literal-values
			resolve-used-name value active contexts
		]
	]

	import-variable-key?: func [key [word! string!] /local id record][
		unless id: select import-ids key [return false]
		record: skip imports ((id - 1) * 10)
		record/5 = 'variable
	]

	intern-pointer: func [pointee [integer!] /local id kind][
		kind: ref-kind pointee
		unless find [i8 byte u8 i16 u16 i32 u32 i64 u64 f32 f64 pointer c-string] kind [
			fail ERROR-UNSUPPORTED "pointer pointee type is unsupported"
		]
		if id: select pointer-types pointee [return id]
		id: type-count + 1
		put pointer-types pointee id
		append types none
		append types 'pointer
		append types pointee
		append/only types copy []
		append/only types copy []
		append canonical-refs id
		append ref-kinds 'pointer
		type-count: id
		id
	]

	intern-array: func [
		element count width [integer!]
		return: [integer!]
		/local key id kind
	][
		kind: ref-kind element
		unless all [
			count > 0
			find [1 2 4 8] width
			find [
				i8 byte u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer c-string function
			] kind
		][
			fail ERROR-UNSUPPORTED "literal array element type is unsupported"
		]
		key: mold/flat reduce [element count width]
		if id: select array-types key [return id]
		id: type-count + 1
		put array-types key id
		append types none
		append types 'array
		append types element
		append types count
		append types width
		append canonical-refs id
		append ref-kinds 'array
		type-count: id
		id
	]

	tagged-union?: func [kind [word!] spec [block!] return: [logic!]][
		all [
			kind = 'union
			not empty? spec
			block? spec/1
			spec/1 = [variant]
		]
	]

	aggregate-members: func [kind [word!] spec [block!] return: [block!]][
		either tagged-union? kind spec [next spec][spec]
	]

	validate-aggregate: func [
		kind [word!]
		spec [block!]
		/local position names field
	][
		position: aggregate-members kind spec
		unless all [not empty? position ((length? position) // 2) = 0][
			fail ERROR-UNSUPPORTED "aggregate type requires field/type pairs"
		]
		names: make hash! 16
		while [not tail? position][
			field: position/1
			unless all [word? field block? position/2][
				fail ERROR-UNSUPPORTED ["invalid aggregate member " mold field]
			]
			if find names field [
				fail ERROR-DUPLICATE ["duplicate aggregate member " mold field]
			]
			append names field
			position: skip position 2
		]
		true
	]

	intern-aggregate: func [
		kind [word!]
		spec scope uses [block!]
		return: [integer!]
		/local key id
	][
		unless find [struct union] kind [
			fail ERROR-UNSUPPORTED "invalid aggregate type"
		]
		validate-aggregate kind spec
		key: mold/flat reduce [kind spec scope uses]
		if id: select aggregate-types key [return id]
		id: type-count + 1
		put aggregate-types key id
		append types none
		append types kind
		append/only types copy/deep spec
		append/only types copy scope
		append/only types copy/deep uses
		append canonical-refs id
		append ref-kinds kind
		type-count: id
		id
	]

	type-kind: func [
		type [block!]
		scope uses [block!]
		/local name kind id record steps target
	][
		unless all [not empty? type any [word? type/1 path? type/1]][return none]
		name: type/1
		kind: all [word? name select type-kinds name]
		unless kind [
			unless id: resolve-name name scope uses type-ids [return none]
			steps: 0
			forever [
				steps: steps + 1
				if steps > type-count [fail ERROR-REFERENCE "cyclic type alias"]
				record: skip types ((id - 1) * 5)
				kind: record/2
				if kind <> 'alias [break]
				target: record/3
				if block? target [
					kind: type-kind target record/4 record/5
					break
				]
				name: target
				if all [word? name kind: select type-kinds name][break]
				unless id: resolve-name name record/4 record/5 type-ids [return none]
			]
		]
		case [
			find [struct union] kind [
				case [
					(length? type) = 1 ['pointer]
					all [(length? type) = 2 type/2 = 'value][kind]
					true [none]
				]
			]
			find [function subroutine] kind [
				either (length? type) = 1 ['pointer][none]
			]
			kind = 'pointer [
				case [
					(length? type) = 1 [kind]
					all [(length? type) = 2 block? type/2][kind]
					true [none]
				]
			]
			(length? type) = 1 [kind]
			true [none]
		]
	]

	type-ref: func [
		type [block!]
		scope uses [block!]
		/local name kind code id pointee
	][
		unless all [not empty? type any [word? type/1 path? type/1]][
			fail ERROR-UNSUPPORTED "invalid type reference"
		]
		name: type/1
		if all [
			word? name
			find [struct! union!] name
			any [
				all [(length? type) = 2 block? type/2]
				all [(length? type) = 3 block? type/2 type/3 = 'value]
			]
		][
			return intern-aggregate either name = 'struct! ['struct]['union]
				type/2 scope uses
		]
		if all [
			word? name
			name = 'function!
			(length? type) = 2
			block? type/2
		][return intern-function-type type/2 scope uses]
		if all [
			word? name
			name = 'subroutine!
			(length? type) = 1
		][return intern-subroutine-type scope uses]
		kind: type-kind type scope uses
		unless kind [fail ERROR-UNSUPPORTED ["unsupported type " mold type]]
		if all [word? name pointee: select builtin-pointees name][
			return intern-pointer type-ref pointee scope uses
		]
		if all [word? name name = 'pointer! (length? type) = 2][
			pointee: type-ref type/2 scope uses
			if enum-ref? pointee [
				fail ERROR-UNSUPPORTED ["invalid literal syntax:" mold type/2]
			]
			return intern-pointer pointee
		]
		if all [
			word? name
			select type-kinds name
			code: select type-codes kind
		][return negate code]
		unless id: resolve-name name scope uses type-ids [
			fail ERROR-REFERENCE ["unknown type " mold name]
		]
		id
	]

	type-flags: func [type [block!] scope uses [block!] /local kind direct?][
		direct?: all [
			(length? type) = 3
			word? type/1
			find [struct! union!] type/1
			block? type/2
			type/3 = 'value
		]
		either any [all [(length? type) = 2 type/2 = 'value] direct?][
			kind: either direct? [
				either type/1 = 'struct! ['struct]['union]
			][type-kind type scope uses]
			unless find [struct union] kind [
				fail ERROR-UNSUPPORTED "only aggregate types can be passed by value"
			]
			inline-flag
		][0]
	]

	member-type-info: func [
		kind [word!]
		spec field-type scope uses [block!]
		return: [block!]
		/local member-kind
	][
		member-kind: type-kind field-type scope uses
		if all [tagged-union? kind spec none? member-kind][
			validate-aggregate 'struct field-type
			return reduce [
				intern-aggregate 'struct field-type scope uses
				inline-flag
			]
		]
		reduce [
			type-ref field-type scope uses
			type-flags field-type scope uses
		]
	]

	ref-kind: func [ref [integer!] /local origin kind][
		if ref < 0 [
			if ref < -15 [return none]
			return pick [
				i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer c-string null byte
			]
				negate ref
		]
		if any [ref = 0 ref > type-count][return none]
		origin: ref
		kind: pick ref-kinds ref
		if word? kind [return kind]
		ref: canonical-ref ref
		kind: case [
			ref < -15 [none]
			ref < 0 [
				pick [
					i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 logic
					pointer c-string null byte
				] negate ref
			]
			ref > 0 [pick ref-kinds ref]
			true [none]
		]
		if word? kind [poke ref-kinds origin kind]
		kind
	]

	type-spelling: func [ref [integer!] return: [string!] /local kind][
		kind: ref-kind ref
		switch/default kind [
			i8         ["int8!"]
			u8         ["uint8!"]
			i16        ["int16!"]
			u16        ["uint16!"]
			i32        ["integer!"]
			u32        ["uint32!"]
			i64        ["int64!"]
			u64        ["uint64!"]
			f32        ["float32!"]
			f64        ["float!"]
			logic      ["logic!"]
			pointer    ["pointer!"]
			c-string   ["c-string!"]
			struct     ["struct!"]
			union      ["union!"]
			function   ["function!"]
			subroutine ["subroutine!"]
			array      ["array!"]
			null       ["null"]
			byte       ["byte!"]
		]["unknown!"]
	]

	canonical-ref: func [ref [integer!] /local origin record target steps][
		if ref <= 0 [return ref]
		if ref > type-count [return 0]
		origin: ref
		steps: 0
		while [steps < type-count][
			if ref > type-count [return 0]
			target: pick canonical-refs ref
			if target <> 0 [
				poke canonical-refs origin target
				return target
			]
			record: skip types ((ref - 1) * 5)
			unless record/2 = 'alias [
				poke canonical-refs origin ref
				return ref
			]
			target: record/3
			target: either block? target [target][reduce [target]]
			ref: type-ref target record/4 record/5
			if ref <= 0 [
				poke canonical-refs origin ref
				return ref
			]
			steps: steps + 1
		]
		fail ERROR-REFERENCE "cyclic type alias"
	]

	tagged-union-ref?: func [ref [integer!] return: [logic!] /local record][
		ref: canonical-ref ref
		if any [ref <= 0 ref > type-count][return false]
		record: skip types ((ref - 1) * 5)
		all [record/2 = 'union tagged-union? record/2 record/3]
	]

	array-info: func [ref [integer!] return: [block! none!] /local record][
		ref: canonical-ref ref
		if any [ref <= 0 ref > type-count][return none]
		record: skip types ((ref - 1) * 5)
		either record/2 = 'array [reduce [record/3 record/4 record/5]][none]
	]

	member-info: func [
		ref [integer!]
		name [word!]
		/local record kind target definition spec index steps info
	][
		if any [ref <= 0 ref > type-count][return none]
		steps: 0
		while [steps < type-count][
			record: skip types ((ref - 1) * 5)
			kind: record/2
			if kind = 'alias [
				target: record/3
				if block? target [
					ref: type-ref target record/4 record/5
					if ref <= 0 [return none]
				]
				if not block? target [
					if all [word? target select type-kinds target][return none]
					unless ref: resolve-name target record/4 record/5 type-ids [return none]
				]
				steps: steps + 1
				continue
			]
			unless find [struct union] kind [return none]
			definition: record/3
			spec: aggregate-members kind definition
			index: 0
			while [not tail? spec][
				if spec/1 = name [
					info: member-type-info kind definition spec/2 record/4 record/5
					return reduce [
						index
						info/1
						info/2
					]
				]
				index: index + 1
				spec: skip spec 2
			]
			return none
		]
		none
	]

	pointee-ref: func [ref [integer!] return: [integer! none!] /local base kind record][
		base: canonical-ref ref
		kind: ref-kind base
		case [
			kind = 'c-string [-15]
			kind = 'array [
				record: skip types ((base - 1) * 5)
				record/3
			]
			all [kind = 'pointer base > 0][
				record: skip types ((base - 1) * 5)
				either record/2 = 'pointer [record/3][none]
			]
			find [struct union] kind [base]
			true [none]
		]
	]

	typed-pointer-id: func [
		ref [integer!]
		return: [integer!]
		/local base record target kind
	][
		base: canonical-ref ref
		target: none
		if all [base > 0 base <= type-count][
			record: skip types ((base - 1) * 5)
			if find [pointer array] record/2 [target: record/3]
		]
		unless integer? target [return 10]
		kind: ref-kind target
		case [
			kind = 'i32 [8]
			kind = 'pointer [10]
			true [7]
		]
	]

	typed-type-id: func [
		ref [integer!]
		return: [integer!]
		/local record target alias-id kind
	][
		if ref = 0 [return 8]
		kind: ref-kind ref
		if all [ref > 0 ref <= type-count][
			record: skip types ((ref - 1) * 5)
			alias-id: select alias-type-ids record/1
			if all [
				integer? alias-id
				alias-id > 1000
				not integer-kind? kind
			][
				return alias-id
			]
			if record/2 = 'alias [
				target: either block? record/3 [
					type-ref record/3 record/4 record/5
				][
					type-ref reduce [record/3] record/4 record/5
				]
				return typed-type-id target
			]
		]
		case [
			kind = 'logic [1]
			kind = 'i32 [2]
			kind = 'byte [3]
			kind = 'u8 [14]
			kind = 'f32 [4]
			kind = 'f64 [5]
			kind = 'c-string [6]
			kind = 'pointer [typed-pointer-id ref]
			kind = 'array [typed-pointer-id ref]
			kind = 'function [9]
			kind = 'i64 [11]
			kind = 'u64 [12]
			kind = 'i8 [13]
			kind = 'i16 [15]
			kind = 'u16 [16]
			kind = 'u32 [17]
			kind = 'struct [1000]
			kind = 'union [1001]
			kind = 'null [8]
			true [0]
		]
	]

	address-reference-ref: func [
		ref flags [integer!]
		return: [integer! none!]
		/local base kind target
	][
		base: canonical-ref ref
		kind: ref-kind base
		if all [
			flags = inline-flag
			find [struct union] kind
		][return base]
		if all [flags = inline-flag kind = 'array][
			target: pointee-ref base
			if integer? target [return intern-pointer target]
		]
		if flags <> 0 [return none]
		case [
			integer-kind? kind [intern-pointer base]
			float-kind? kind [intern-pointer base]
			kind = 'pointer [intern-pointer -12]
			true [none]
		]
	]

	one-based-index-bits: func [value [integer!] return: [block!] /local low][
		if value = -2147483648 [return reduce [2147483647 -1]]
		low: value - 1
		reduce [low either low < 0 [-1][0]]
	]

	infix-spec?: func [spec [block!] return: [logic!] /local position][
		position: spec
		if all [not tail? position string? position/1][position: next position]
		to logic! all [
			not tail? position
			block? position/1
			find position/1 'infix
		]
	]

	check-infix-arity: func [name signature [block!] /local count][
		count: (length? signature/2) / 3
		unless count = 2 [
			fail ERROR-ARGUMENTS rejoin [
				"infix function requires 2 arguments, found " count
				" for " source-name name
			]
		]
	]

	signature-flags: func [attributes [block!] /local flags convention item bit][
		if (length? attributes) > 2 [
			fail ERROR-UNSUPPORTED "too many function attributes"
		]
		if all [find attributes 'catch (length? attributes) <> 1][
			fail ERROR-UNSUPPORTED "catch cannot be combined with another function attribute"
		]
		if all [
			(length? attributes) = 2
			attributes/1 = attributes/2
		][fail ERROR-UNSUPPORTED "duplicate function attribute"]
		flags: 0
		convention: 0
		foreach item attributes [
			unless word? item [fail ERROR-UNSUPPORTED "invalid function attribute"]
			bit: 0
			case [
				item = 'cdecl [
					if convention <> 0 [
						fail ERROR-UNSUPPORTED "conflicting calling conventions"
					]
					convention: 1
				]
				item = 'stdcall [
					if convention <> 0 [
						fail ERROR-UNSUPPORTED "conflicting calling conventions"
					]
					convention: 2
				]
				item = 'variadic [bit: variadic-flag]
				item = 'typed [bit: typed-flag]
				item = 'custom [bit: custom-flag]
				item = 'callback [bit: callback-flag]
				item = 'objc [bit: objc-flag]
				item = 'catch [bit: catch-flag]
				item = 'infix []
				item = 'red-internal [bit: red-internal-flag]
				true [fail ERROR-UNSUPPORTED ["unknown function attribute " mold item]]
			]
			if all [
				bit >= variadic-flag
				bit <= custom-flag
				(flags and (variadic-flag + typed-flag + custom-flag)) <> 0
			][fail ERROR-UNSUPPORTED "conflicting variable-arity attributes"]
			flags: flags + bit
		]
		flags + convention
	]

	check-function-type: func [
		type [block!]
		function-name [word! string! binary! none!]
	][
		if all [function-name not empty? type path? type/1][
			fail ERROR-UNSUPPORTED [
				"invalid definition for function" source-name function-name
			]
		]
	]

	read-signature: func [
		spec scope uses [block!]
		function-name [word! string! binary! none!]
		/local position names-start names-end item name type params locals names flags
			ref type-flags-value return-ref value? locals?
	][
		position: spec
		if all [not tail? position string? position/1][position: next position]
		flags: 0
		if all [not tail? position block? position/1][
			flags: signature-flags position/1
			position: next position
		]
		if all [not tail? position string? position/1][position: next position]
		if all [not tail? position position/1 = 'red-internal][
			if (flags and red-internal-flag) <> 0 [
				fail ERROR-UNSUPPORTED "duplicate function attribute"
			]
			flags: flags + red-internal-flag
			position: next position
		]

		params: make block! 12
		locals: make block! 12
		names: make hash! 16
		return-ref: 0
		value?: false
		locals?: false
		while [not tail? position][
			item: position/1
			case [
				refinement? item [
					unless all [item = /local not locals?][
						fail ERROR-UNSUPPORTED "function refinement is unsupported"
					]
					locals?: true
					position: next position
				]
				all [set-word? item not locals?][
					unless all [
						item = to set-word! 'return
						not value?
						(length? position) >= 2
						block? position/2
					][fail ERROR-UNSUPPORTED "invalid function return type"]
					type: position/2
					check-function-type type function-name
					return-ref: type-ref type scope uses
					if (ref-kind return-ref) = 'subroutine [
						fail ERROR-UNSUPPORTED "subroutine! cannot be returned"
					]
					if (type-flags type scope uses) = 1 [
						flags: flags + return-value-flag
					]
					value?: true
					position: skip position 2
					if all [not tail? position string? position/1][position: next position]
				]
				word? item [
					if all [value? not locals?][
						fail ERROR-UNSUPPORTED "function parameter follows its return type"
					]
					names-start: position
					while [all [not tail? position word? position/1]][
						name: position/1
						if find names name [
							fail ERROR-UNSUPPORTED "duplicate function variable"
						]
						if all [
							not locals?
							resolve-name name scope uses enum-values
						][warn ["function's argument redeclares enumeration:" name]]
						append names name
						position: next position
					]
					names-end: position
					either locals? [
						ref: 0
						type-flags-value: 0
						if all [not tail? position block? position/1][
							type: position/1
							check-function-type type function-name
							ref: type-ref type scope uses
							type-flags-value: type-flags type scope uses
							position: next position
						]
						while [names-start <> names-end][
							repend locals [names-start/1 ref type-flags-value]
							names-start: next names-start
						]
					][
						unless all [not tail? position block? position/1][
							fail ERROR-UNSUPPORTED "function parameter is missing its type"
						]
						type: position/1
						check-function-type type function-name
						ref: type-ref type scope uses
						type-flags-value: type-flags type scope uses
						if (ref-kind ref) = 'subroutine [
							fail ERROR-UNSUPPORTED "subroutine! is only allowed for locals"
						]
						while [names-start <> names-end][
							repend params [names-start/1 ref type-flags-value]
							names-start: next names-start
						]
						position: next position
					]
					if all [not tail? position string? position/1][position: next position]
				]
				true [fail ERROR-UNSUPPORTED "function signature is unsupported"]
			]
		]
		reduce [return-ref params locals flags]
	]

	resolved-signature?: func [value return: [logic!]][
		all [
			block? value
			(length? value) = 4
			integer? value/1
			block? value/2
			block? value/3
			integer? value/4
		]
	]

	signature-key: func [signature [block!] /local key parameter][
		key: make block! ((length? signature/2) + 2)
		append key canonical-ref signature/1
		append key signature/4
		parameter: signature/2
		while [not tail? parameter][
			append key canonical-ref parameter/2
			append key parameter/3
			parameter: skip parameter 3
		]
		mold/flat key
	]

	intern-function-signature: func [
		signature scope uses [block!]
		return: [integer!]
		/local key id
	][
		unless empty? signature/3 [
			fail ERROR-UNSUPPORTED "function type cannot declare locals"
		]
		key: signature-key signature
		if id: select function-types key [return id]
		id: type-count + 1
		put function-types key id
		append types none
		append types 'function
		append/only types copy/deep signature
		append/only types copy scope
		append/only types copy/deep uses
		append canonical-refs id
		append ref-kinds 'function
		type-count: id
		id
	]

	intern-function-type: func [
		spec scope uses [block!]
		return: [integer!]
	][
		intern-function-signature (read-signature spec scope uses none) scope uses
	]

	intern-subroutine-type: func [
		scope uses [block!]
		return: [integer!]
		/local key id
	][
		key: mold/flat reduce [scope uses]
		if id: select subroutine-types key [return id]
		id: type-count + 1
		put subroutine-types key id
		append types none
		append types 'subroutine
		append/only types copy []
		append/only types copy scope
		append/only types copy/deep uses
		append canonical-refs id
		append ref-kinds 'subroutine
		type-count: id
		id
	]

	prepare-types: func [/local record kind target definition spec scope uses
		signature key info id
	][
		id: 1
		while [id <= type-count][
			record: skip types ((id - 1) * 5)
			kind: record/2
			case [
				kind = 'alias [
					target: record/3
					scope: record/4
					uses: record/5
					target: either block? target [target][reduce [target]]
					type-ref target scope uses
				]
				find [struct union] kind [
					definition: record/3
					spec: aggregate-members kind definition
					scope: record/4
					uses: record/5
					while [not tail? spec][
						info: member-type-info kind definition spec/2 scope uses
						spec: skip spec 2
					]
				]
				find [function subroutine] kind [
					target: record/3
					scope: record/4
					uses: record/5
					signature: either resolved-signature? target [
						target
					][read-signature target scope uses none]
					unless empty? signature/3 [
						fail ERROR-UNSUPPORTED "function type cannot declare locals"
					]
					record: skip types ((id - 1) * 5)
					record/3: signature
					if kind = 'function [
						key: signature-key signature
						unless select function-types key [
							put function-types key id
						]
					]
				]
				true [0]
			]
			id: id + 1
		]
	]

	collect-local-uses: func [
		body [block!]
		candidates used [hash!]
		/local value name parts
	][
		foreach value body [
			name: none
			case [
				any [word? value set-word? value get-word? value][
					name: to word! value
				]
				any [path? value set-path? value get-path? value][
					parts: to block! value
					if all [not empty? parts word? parts/1][name: parts/1]
				]
				any [block? value paren? value][
					collect-local-uses to block! value candidates used
				]
			]
			if all [
				word? name
				find candidates name
				not find used name
			][append used name]
		]
	]

	prune-unused-locals: func [
		locals body [block!]
		/local candidates used position
	][
		if empty? locals [exit]
		candidates: make hash! ((length? locals) / 3)
		position: locals
		while [not tail? position][
			append candidates position/1
			position: skip position 3
		]
		used: make hash! (length? candidates)
		collect-local-uses body candidates used
		position: locals
		while [not tail? position][
			either find used position/1 [
				position: skip position 3
			][position: remove/part position 3]
		]
	]

	function-signature: func [ref [integer!] return: [block! none!] /local record][
		ref: canonical-ref ref
		if any [ref <= 0 ref > type-count][return none]
		record: skip types ((ref - 1) * 5)
		unless record/2 = 'function [return none]
		either resolved-signature? record/3 [record/3][none]
	]

	make-call-signature-ref: func [target [integer!] return: [integer!] /local record][
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			intern-function-signature reduce [
				record/6 record/7 copy [] record/9
			] copy [] copy []
		][
			record: skip imports (((0 - target) - 1) * 10)
			intern-function-signature reduce [
				record/8 record/9 copy [] record/10
			] copy [] copy []
		]
	]

	call-signature-ref: func [
		target [integer!]
		return: [integer!]
		/local cache index cached fresh
	][
		cache: either target > 0 [function-call-types][import-call-types]
		index: absolute target
		cached: pick cache index
		if cached <> 0 [return cached]
		fresh: make-call-signature-ref target
		poke cache index fresh
		fresh
	]

	intern-typed-call: func [
		signature [integer!]
		arguments [block!]
		return: [integer!]
		/local key id
	][
		key: mold/flat reduce [signature arguments]
		if id: select typed-call-types key [return id]
		id: type-count + 1
		put typed-call-types key id
		append types key
		append types 'typed-call
		append/only types copy arguments
		append/only types copy []
		append/only types copy []
		append canonical-refs id
		append ref-kinds 'typed-call
		type-count: id
		id
	]

	prepare-functions: func [/local record signature id][
		clear function-call-types
		record: functions
		id: 1
		while [not tail? record][
			signature: read-signature record/2 record/4 record/5 record/1
			prune-unused-locals signature/3 record/3
			if find infix-targets id [check-infix-arity record/1 signature]
			record/6: signature/1
			record/7: signature/2
			record/8: signature/3
			record/9: signature/4
			append function-call-types 0
			id: id + 1
			record: skip record 10
		]
	]

	prepare-imports: func [/local record signature cc id][
		clear import-call-types
		record: imports
		id: -1
		while [not tail? record][
			cc: record/8
			either record/5 = 'function [
				signature: read-signature record/4 record/6 record/7 record/1
				if find infix-targets id [check-infix-arity record/1 signature]
				unless empty? signature/3 [
					fail ERROR-UNSUPPORTED "import signature cannot declare locals"
				]
				if (signature/4 and 3) <> 0 [
					fail ERROR-UNSUPPORTED
						"import calling convention is specified twice"
				]
				record/8: signature/1
				record/9: signature/2
				record/10: signature/4 + either cc = 'cdecl [1][2]
			][
				record/8: type-ref record/4 record/6 record/7
				record/9: none
				record/10: 0
			]
			append import-call-types 0
			id: id - 1
			record: skip record 10
		]
	]

	add-module-function: func [
		name [word!]
		code [binary!]
		locals [block!]
		/local key id
	][
		key: name
		if any [
			select function-ids key
			select import-ids key
			select globals key
		][fail ERROR-DUPLICATE [form name " is reserved for the module body"]]
		id: function-count + 1
		put function-ids key id
		put call-ids key id
		append/only functions to binary! form name
		append/only functions copy []
		append/only functions code
		append/only functions copy []
		append/only functions copy []
		append functions 0
		append/only functions copy []
		append/only functions copy locals
		append functions 0
		append functions 0
		function-count: id
		id
	]

	collect-call-dependencies: func [
		body scope uses [block!]
		local-names seen [map!]
		dependencies [block!]
		/local value base target
	][
		foreach value body [
			case [
				any [word? value path? value][
					base: either word? value [value][value/1]
					if all [word? base not select local-names base][
						target: resolve-name value scope uses call-ids
						if all [
							integer? target
							target > 0
							not select seen target
						][
							put seen target true
							append dependencies target
						]
					]
				]
				any [block? value paren? value][
					collect-call-dependencies to block! value scope uses
						local-names seen dependencies
				]
				true [0]
			]
		]
	]

	collect-local-names: func [
		records [block!]
		names [map!]
		/local record
	][
		record: records
		while [not tail? record][
			if word? record/1 [put names record/1 true]
			record: skip record 3
		]
	]

	lower-function: func [
		id [integer!]
		/local record body code count dependencies seen local-names target returns?
	][
		if (pick function-states id) <> 0 [exit]
		poke function-states id 1
		record: skip functions ((id - 1) * 10)
		body: record/3
		either binary? body [
			unless ((length? body) // 16) = 0 [
				fail ERROR-UNSUPPORTED "invalid module instruction stream"
			]
			record/10: (length? body) / 16
		][
			dependencies: make block! 16
			seen: make map! 16
			local-names: make map! 16
			collect-local-names record/7 local-names
			collect-local-names record/8 local-names
			collect-call-dependencies body record/4 record/5
				local-names seen dependencies
			foreach target dependencies [
				if (pick function-states target) = 0 [lower-function target]
			]

			active-function: record/1
			code: make binary! ((length? body) * 16)
			count: stack-body record/6 body record/4 record/5 code
				record/7 record/8 record/9
			returns?: function-returns?
			record/3: code
			record/10: count
			unless returns? [put no-return-functions id true]
		]
		poke function-states id 2
	]

	lower-functions: func [/local id record][
		clear function-code
		clear function-states
		clear no-return-functions
		append/dup function-states 0 function-count
		id: 1
		while [id <= function-count][
			lower-function id
			id: id + 1
		]
		finish-native-names
		record: functions
		while [not tail? record][
			append function-code record/3
			record: skip record 10
		]
		active-function: none
	]

	check-enum-name: func [
		name [word!]
		scope [block!]
		/local key enum
	][
		key: qualified scope name
		case [
			all [name <> 'context find reserved-words name][
				fail ERROR-DUPLICATE ["attempt to redefine a protected keyword:" name]
			]
			select function-ids key [
				fail ERROR-DUPLICATE ["attempt to redefine existing function name:" name]
			]
			all [definitions find definitions name][
				fail ERROR-DUPLICATE ["attempt to redefine existing definition:" name]
			]
			select enum-types key [
				fail ERROR-DUPLICATE ["redeclaration of enum identifier:" name]
			]
			select type-ids key [
				fail ERROR-DUPLICATE ["attempt to redefine existing alias definition:" name]
			]
			select type-kinds name [
				fail ERROR-DUPLICATE ["redeclaration of base type:" name]
			]
			any [
				select globals key
				select import-ids key
				select protected key
			][fail ERROR-DUPLICATE ["redeclaration of variable:" name]]
			enum: select enum-values key [
				fail ERROR-DUPLICATE ["redeclaration of enumerator:" name]
			]
		]
	]

	enum-ref?: func [ref [integer!] return: [logic!] /local record][
		if any [ref <= 0 ref > type-count][return false]
		record: skip types ((ref - 1) * 5)
		integer? select enum-types record/1
	]

	scan-enum: func [
		name [word!]
		values scope [block!]
		/local key position labels after-labels next-position item label value
			constant-key id count record
	][
		key: qualified scope name
		check-enum-name name scope
		id: type-count + 1
		put type-ids key id
		put enum-types key id
		add-context-word scope name
		append types key
		append types 'i32
		append types 0
		append/only types copy scope
		append/only types copy []
		append canonical-refs -5
		append ref-kinds 'i32
		type-count: id
		value: 0
		count: 0
		position: values
		while [not tail? position][
			error-position: position
			case [
				word? position/1 [
					label: position/1
					labels: position
					after-labels: next position
					next-position: after-labels
				]
				set-word? position/1 [
					label: to word! position/1
					labels: position
					after-labels: position
					while [all [not tail? after-labels set-word? after-labels/1]][
						after-labels: next after-labels
					]
					if tail? after-labels [
						fail ERROR-UNSUPPORTED "enum value is missing"
					]
					case [
						integer? after-labels/1 [value: after-labels/1]
						word? after-labels/1 [
							unless integer? value: resolve-name
								after-labels/1 scope [] literal-values [
								fail ERROR-REFERENCE [
									"cannot resolve literal enum value for:" label
								]
							]
						]
						true [fail ERROR-UNSUPPORTED "invalid enum value"]
					]
					next-position: next after-labels
				]
				true [fail ERROR-UNSUPPORTED "invalid enum declaration"]
			]
			while [labels <> after-labels][
				item: to word! labels/1
				constant-key: qualified scope item
				check-enum-name item scope
				put literal-values constant-key value
				put enum-values constant-key key
				add-context-word scope item
				count: count + 1
				labels: next labels
			]
			if value < 2147483647 [value: value + 1]
			position: next-position
		]
		record: skip types ((id - 1) * 5)
		record/3: count
	]

	count-enum: func [
		name [word! path!]
		scope uses [block!]
		return: [integer! none!]
		/local id record
	][
		unless id: resolve-name name scope uses type-ids [return none]
		record: skip types ((id - 1) * 5)
		all [record/2 = 'i32 integer? record/3 record/3]
	]

	scan-imports: func [
		definitions scope uses [block!]
		/local position library canonical cc entries entry name key external spec kind id
	][
		if empty? definitions [fail ERROR-UNSUPPORTED "import block is empty"]
		position: definitions
		while [not tail? position][
			unless all [
				(length? position) >= 3
				string? position/1
				find [cdecl stdcall] position/2
				block? position/3
			][fail ERROR-UNSUPPORTED "invalid import group"]
			unless valid-name? position/1 [
				fail ERROR-NAME "invalid import library name"
			]
			library: to binary! position/1
			either canonical: select libraries library [
				library: canonical
			][put libraries library library]
			cc: position/2
			entries: position/3
			if empty? entries [
				fail ERROR-UNSUPPORTED "empty import group is unsupported"
			]
			entry: entries
			while [not tail? entry][
				unless all [
					(length? entry) >= 3
					set-word? entry/1
					string? entry/2
					block? entry/3
				][fail ERROR-UNSUPPORTED "invalid import declaration"]
				name: to word! entry/1
				key: qualified scope name
				if any [
					select import-ids key
					select function-ids key
					select globals key
					select protected key
				][
					fail ERROR-DUPLICATE ["duplicate import " mold key]
				]
				unless valid-name? entry/2 [
					fail ERROR-NAME "invalid external import name"
				]
				external: to binary! entry/2
				spec: entry/3
				kind: either any [
					all [(length? spec) = 1 not block? spec/1]
					all [
						(length? spec) = 2
						find [pointer! struct!] spec/1
						block? spec/2
					]
				]['variable]['function]
				id: import-count + 1
				add-context-word scope name
				put import-ids key id
				if kind = 'function [put call-ids key (0 - id)]
				if all [kind = 'function infix-spec? spec][
					append infix-targets (0 - id)
				]
				append imports key
				append/only imports library
				append/only imports external
				append/only imports spec
				append imports kind
				append/only imports scope
				append/only imports uses
				append imports cc
				append imports none
				append imports none
				import-count: id
				entry: skip entry 3
			]
			position: skip position 3
		]
	]

	scan-exports: func [
		position scope uses [block!]
		return: [block!]
		/local cursor convention list symbol external
	][
		unless module-kind = 4 [
			fail ERROR-CONTEXT "#export requires a shared library module"
		]
		cursor: next position
		convention: 1
		if all [not tail? cursor word? cursor/1][
			unless find [cdecl stdcall] cursor/1 [
				fail ERROR-UNSUPPORTED [
					"invalid export calling convention " mold cursor/1
				]
			]
			convention: either cursor/1 = 'cdecl [1][2]
			cursor: next cursor
		]
		unless all [not tail? cursor block? cursor/1][
			fail ERROR-ARGUMENTS "#export expects a block of symbols"
		]
		list: cursor/1
		if empty? list [fail ERROR-ARGUMENTS "#export block is empty"]
		while [not tail? list][
			symbol: list/1
			unless any [word? symbol path? symbol][
				fail ERROR-NAME ["invalid exported symbol " mold symbol]
			]
			external: none
			if all [(length? list) >= 2 string? list/2][
				external: list/2
				unless valid-name? external [
					fail ERROR-NAME "invalid external export name"
				]
				list: next list
			]
			append/only exports symbol
			append/only exports copy scope
			append/only exports copy/deep uses
			append exports convention
			append/only exports either external [to binary! external][none]
			list: next list
		]
		next cursor
	]

	add-runtime-export: func [
		symbol [word! path!]
		external [string!]
	][
		unless valid-name? external [
			fail ERROR-NAME "invalid external runtime export name"
		]
		append/only exports symbol
		append/only exports copy []
		append/only exports copy []
		append exports 2
		append/only exports to binary! external
	]

	add-runtime-exports: func [
		definitions [block!]
		/local position symbol external
	][
		unless zero? ((length? definitions) // 2) [
			fail ERROR-ARGUMENTS "runtime exports require symbol/name pairs"
		]
		position: definitions
		while [not tail? position][
			symbol: position/1
			external: position/2
			unless any [word? symbol path? symbol][
				fail ERROR-NAME ["invalid runtime export " mold symbol]
			]
			unless string? external [
				fail ERROR-NAME ["invalid external runtime export " mold external]
			]
			add-runtime-export symbol external
			position: skip position 2
		]
	]

	prepare-runtime-functions: func [
		/local record spelling key symbol external
	][
		record: functions
		while [not tail? record][
			spelling: to string! copy record/1
			key: to word! spelling
			put runtime-specs key copy/deep record/2
			if all [
				find/match spelling "exec>"
				not find skip spelling 5 ">"
			][
				external: copy skip spelling 5
				replace/all spelling ">" "/"
				symbol: transcode/one spelling
				add-runtime-export symbol external
			]
			record: skip record 10
		]
	]

	add-library-callbacks: func [/local declarations code name spec][
		declarations: [
			on-load        [handle [pointer! [integer!]]]
			on-unload      [handle [pointer! [integer!]]]
			on-new-thread  [handle [pointer! [integer!]]]
			on-exit-thread [handle [pointer! [integer!]]]
		]
		code: make block! 16
		foreach [name spec] declarations [
			unless select function-ids name [
				repend code [to set-word! name 'func copy/deep spec copy []]
			]
		]
		unless empty? code [scan-block code copy [] copy [] 0]
	]

	prepare-exports: func [
		/local position symbol scope uses convention external id record flags internal
	][
		position: exports
		while [not tail? position][
			symbol: position/1
			scope: position/2
			uses: position/3
			convention: position/4
			external: position/5
			id: resolve-name symbol scope uses function-ids
			either integer? id [
				record: skip functions ((id - 1) * 10)
				flags: record/9
				if (flags and catch-flag) <> 0 [
					fail ERROR-UNSUPPORTED "a catch function cannot be exported"
				]
				record/9: (((flags and -4) or convention) or callback-flag)
				if runtime-library? [
					record/9: record/9 or red-internal-flag
					unless find/only runtime-functions symbol [
						append/only runtime-functions symbol
					]
				]
				internal: record/1
			][
				id: resolve-name symbol scope uses globals
				unless integer? id [
					fail ERROR-REFERENCE ["undefined exported symbol " mold symbol]
				]
				record: skip global-data ((id - 1) * 5)
				internal: record/1
				id: 0 - id
			]
			if none? external [external: copy internal]
			if find/case export-names external [
				fail ERROR-DUPLICATE ["duplicate external export " to string! external]
			]
			append/only export-names external
			position/1: id
			position/5: external
			position: skip position 5
		]
	]

	skip-script: func [
		position [block!]
		return: [block!]
	][
		while [
			all [
				not tail? position
				issue? position/1
				position/1 = #script
			]
		][
			unless (length? position) >= 2 [
				fail ERROR-ARGUMENTS "#script is missing its source"
			]
			unless any [
				file? position/2
				position/2 = 'in-memory
			][fail ERROR-ARGUMENTS "#script requires a file source"]
			position: skip position 2
		]
		position
	]

	scan-block: func [
		values scope uses [block!]
		with-count [integer!]
		/local position name spec body child key kind target next-uses
			spelling id type-spec protected-id alias-id canonical enum
	][
		position: values
		while [not tail? position][
			error-position: position
			case [
				all [
					position/1 = 'comment
					(length? position) >= 2
				][position: skip position 2]
				all [
					issue? position/1
					position/1 = #script
				][position: skip-script position]
				all [issue? position/1 position/1 = #user-code][
					either all [(length? position) >= 2 block? position/2][
						scan-block position/2 scope uses with-count
						position: skip position 2
					][position: next position]
				]
				all [issue? position/1 position/1 = #export][
					position: scan-exports position scope uses
				]
				all [
					issue? position/1
					position/1 = #enum
					(length? position) >= 3
					word? position/2
					block? position/3
				][
					scan-enum position/2 position/3 scope
					position: skip position 3
				]
				all [
					issue? position/1
					position/1 = #import
					(length? position) >= 2
					block? position/2
				][
					scan-imports position/2 scope uses
					position: skip position 2
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'alias
				][
					key: qualified scope to word! position/1
					add-context-word scope to word! position/1
					if any [select type-ids key select contexts key][
						fail ERROR-DUPLICATE ["duplicate alias " mold key]
					]
					case [
						position/3 = 'pointer! [
							unless all [
								(length? position) >= 4
								block? position/4
							][fail ERROR-UNSUPPORTED "pointer alias is missing its pointee"]
							kind: 'alias
							type-spec: reduce [position/3 position/4]
							position: skip position 4
						]
						find [struct! union! function! subroutine!] position/3 [
							unless all [
								(length? position) >= 4
								block? position/4
							][fail ERROR-UNSUPPORTED "alias type is missing its spec"]
							kind: case [
								position/3 = 'struct! ['struct]
								position/3 = 'union! ['union]
								position/3 = 'function! ['function]
								true ['subroutine]
							]
							type-spec: position/4
							if find [struct union] kind [validate-aggregate kind type-spec]
							position: skip position 4
						]
						any [word? position/3 path? position/3][
							kind: 'alias
							type-spec: position/3
							position: skip position 3
						]
						true [fail ERROR-UNSUPPORTED "invalid alias declaration"]
					]
					id: type-count + 1
					put type-ids key id
					if find [struct union] kind [
						spelling: mold/flat reduce [kind type-spec scope uses]
						target: select aggregate-types spelling
						unless integer? target [
							target: id
							put aggregate-types spelling id
						]
					]
					canonical: case [
						find [struct union] kind [target]
						kind = 'alias [0]
						true [id]
					]
					append types key
					append types kind
					append/only types type-spec
					append/only types copy scope
					append/only types copy/deep uses
					append canonical-refs canonical
					append ref-kinds either kind = 'alias [none][kind]
					type-count: id
					alias-count: alias-count + 1
					alias-id: 1000 + alias-count
					put alias-type-ids key alias-id
				]
				all [
					set-word? position/1
					(length? position) >= 4
					find [func function] position/2
					block? position/3
					block? position/4
				][
					name: position/1
					spec: position/3
					body: position/4
					key: qualified scope to word! name
					spelling: form key
					add-context-word scope to word! name
					unless valid-name? spelling [
						fail ERROR-NAME "invalid RSIR function name"
					]
					if any [
						select function-ids key
						select import-ids key
						select globals key
						select protected key
						select literal-values key
						select contexts key
					][
						fail ERROR-DUPLICATE ["duplicate function " mold key]
					]
					id: function-count + 1
					put function-ids key id
					put call-ids key id
					if infix-spec? spec [append infix-targets id]
					append/only functions to binary! spelling
					append/only functions spec
					append/only functions body
					append/only functions copy scope
					append/only functions copy/deep uses
					append functions none
					append functions none
					append functions none
					append functions none
					append functions none
					function-count: id
					position: skip position 4
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'context
					block? position/3
				][
					name: to word! position/1
					key: qualified scope name
					if any [
						select contexts key
						select function-ids key
						select import-ids key
						select globals key
						select protected key
						select literal-values key
						select type-ids key
					][
						fail ERROR-DUPLICATE "context name is already taken"
					]
					context-count: context-count + 1
					add-context-word scope name
					put contexts key context-count
					put context-members key make hash! 16
					child: append copy scope name
					scan-block position/3 child uses 0
					position: skip position 3
				]
				all [
					position/1 = 'with
					(length? position) >= 3
					any [word? position/2 path? position/2 block? position/2]
					block? position/3
				][
					target: position/2
					child: resolve-with target scope uses
					next-uses: copy/deep uses
					append next-uses child
					scan-block position/3 scope next-uses
						(with-count + (length? child))
					position: skip position 3
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'protect
				][
					name: to word! position/1
					key: qualified scope name
					add-context-word scope name
					if any [
						select function-ids key
						select import-ids key
						select globals key
						select protected key
						select literal-values key
						select contexts key
					][fail ERROR-DUPLICATE ["duplicate protected value " mold key]]
					protected-id: 0
					unless protected-scalar? position/3 [protected-id: add-global key]
					put protected key protected-id
					position: next position
				]
				set-word? position/1 [
					name: to word! position/1
					key: qualified scope name
					if name = 'context [
						fail ERROR-DUPLICATE
							"attempt to redefine a protected keyword: context"
					]
					if enum: select enum-values key [
						fail ERROR-DUPLICATE [
							"redeclaration of enumerator" name "from" source-name enum
						]
					]
					add-context-word scope name
					unless any [
						select globals key
						select protected key
						import-variable-key? key
						used-value? name uses with-count
					][
						if any [
							select function-ids key
							select import-ids key
							select literal-values key
							select contexts key
						][
							fail ERROR-DUPLICATE ["duplicate global " mold key]
						]
						add-global key
					]
					position: next position
				]
				true [position: next position]
			]
		]
	]

	compile-source: func [
		source [block!]
		runtime-exports [block! none!]
		/local header body
	][
		unless all [not tail? source source/1 = 'Red/System] [
			fail ERROR-ARGUMENTS "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2] [
			fail ERROR-ARGUMENTS "missing Red/System program header"
		]
		header: source/2
		unless parse header [any [set-word! skip]] [
			fail ERROR-ARGUMENTS "invalid Red/System program header"
		]

		body: skip source 2
		scan-block body copy [] copy [] 0
		if runtime-exports [add-runtime-exports runtime-exports]
		if module-kind = 4 [
			if empty? exports [
				fail ERROR-CONTEXT "a shared library must export at least one symbol"
			]
			add-library-callbacks
		]
		prepare-types
		prepare-functions
		if runtime-exports [prepare-runtime-functions]
		prepare-imports
		prepare-exports
		split-module?: to logic! all [module-kind = 4 find body #user-code]
		user-code?: false
		active-module-code: either split-module? [boot-code][module-code]
		active-module-locals: either split-module? [boot-locals][module-locals]
		compile-module body copy [] copy []
		case [
			module-kind = 3 [
				emit module-code reduce [return-op 0 0 0]
				add-module-function '***-main module-code module-locals
			]
			module-kind = 4 [
				emit boot-code reduce [return-op 0 0 0]
				add-module-function '***-boot-rs boot-code boot-locals
				emit module-code reduce [return-op 0 0 0]
				add-module-function '***-main module-code module-locals
			]
		]
		if all [module-kind < 3 any [not empty? boot-code not empty? module-code]][
			fail ERROR-UNSUPPORTED "runtime module body requires a glue module"
		]
		if function-count < 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
		lower-functions
		prepare-types
	]

	write-types: func [type-output members [binary!] /local record kind definition
		spec scope uses field-type info ref flags count code first signature
		params parameter target typed-arguments typed-argument id
	][
		first: 0
		id: 1
		while [id <= type-count][
			record: skip types ((id - 1) * 5)
			kind: record/2
			case [
				kind = 'alias [
					code: select type-codes 'alias
					target: record/3
					scope: record/4
					uses: record/5
					target: either block? target [target][reduce [target]]
					emit type-output reduce [
						code
						type-ref target scope uses
						0
						first
						0
					]
				]
				kind = 'typed-call [
					typed-arguments: record/3
					count: ((length? typed-arguments) - 1) / 2
					emit type-output reduce [
						select type-codes 'typed-call
						typed-arguments/1
						0
						first
						count
					]
					typed-argument: skip typed-arguments 1
					while [not tail? typed-argument][
						emit members reduce [typed-argument/1 typed-argument/2]
						typed-argument: skip typed-argument 2
					]
					first: first + count
				]
				kind = 'pointer [
					emit type-output reduce [
						select type-codes 'pointer-node record/3 0 first 0
					]
				]
				kind = 'array [
					emit type-output reduce [
						select type-codes 'array record/3 record/5 first record/4
					]
				]
				find [struct union] kind [
					target: pick canonical-refs id
					either all [integer? target target <> id][
						emit type-output reduce [
							select type-codes 'alias target 0 first 0
						]
					][
						code: select type-codes kind
						definition: record/3
						spec: aggregate-members kind definition
						scope: record/4
						uses: record/5
						count: (length? spec) / 2
						emit type-output reduce [
							code 0 either tagged-union? kind definition [tagged-type-flag][0]
							first count
						]
						while [not tail? spec][
							field-type: spec/2
							info: member-type-info kind definition field-type scope uses
							ref: info/1
							flags: info/2
							emit members reduce [ref flags]
							spec: skip spec 2
						]
						first: first + count
					]
				]
				find [function subroutine] kind [
					signature: record/3
					unless resolved-signature? signature [
						fail ERROR-REFERENCE "function type signature is unresolved"
					]
					unless empty? signature/3 [
						fail ERROR-UNSUPPORTED "function type cannot declare locals"
					]
					params: signature/2
					count: (length? params) / 3
					emit type-output reduce [
						select type-codes kind
						signature/1
						signature/4
						first
						count
					]
					parameter: params
					while [not tail? parameter][
						emit members reduce [parameter/2 parameter/3]
						parameter: skip parameter 3
					]
					first: first + count
				]
				true [
					emit type-output reduce [(select type-codes kind) 0 0 first 0]
					]
			]
			id: id + 1
		]
	]

	write-rsir: func [limit [integer!] /local output position name
		params locals flags record-offset param-count local-count first-param first-local
		instruction-count size entry id parameter import-records global-records
		function-records export-records export-count
		library external last-library library-offset external-offset names
		type-output members type-bytes member-bytes switch-count
	][
		type-output: make binary! (type-count * 20)
		members: make binary! 64
		write-types type-output members
		write-initializers
		type-bytes: length? type-output
		member-bytes: length? members
		names: copy strings
		switch-count: (length? switches) / 12
		export-count: (length? exports) / 5
		output: make binary! (36 + type-bytes + member-bytes + (length? initializers)
			+ (length? switches)
			+ (length? strings)
			+ (length? function-code) + (import-count * 64)
			+ (global-count * 40) + (function-count * 112) + (export-count * 24))
		append/dup output 0 36
		append output type-output
		append output members
		import-records: 37 + type-bytes + member-bytes
		global-records: import-records + (import-count * 32)
		function-records: global-records + (global-count * 24)
		export-records: function-records + (function-count * 36)
		append/dup output 0 (import-count * 32)
		append/dup output 0 (global-count * 24)
		append/dup output 0 (function-count * 36)
		append/dup output 0 (export-count * 12)

		position: imports
		last-library: none
		library-offset: 0
		first-param: 0
		id: 1
		while [not tail? position][
			library: position/2
			external: position/3
			unless same? library last-library [
				library-offset: length? names
				append names library
				last-library: library
			]
			external-offset: length? names
			append names external
			params: position/9
			param-count: either block? params [(length? params) / 3][0]
			record-offset: import-records + ((id - 1) * 32)
			change/part at output record-offset
				int-to-bin/to-bin32 library-offset 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? library) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 external-offset 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 (length? external) 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 position/8 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 position/10 4
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 first-param 4
			change/part at output (record-offset + 28)
				int-to-bin/to-bin32 param-count 4
			if block? params [
				parameter: params
				while [not tail? parameter][
					emit output reduce [parameter/2 parameter/3]
					parameter: skip parameter 3
				]
			]
			first-param: first-param + param-count
			id: id + 1
			position: skip position 10
		]

		position: global-data
		id: 1
		while [not tail? position][
			name: position/1
			unless integer? position/2 [
				fail ERROR-UNSUPPORTED ["global type is unresolved: " mold name]
			]
			record-offset: global-records + ((id - 1) * 24)
			change/part at output record-offset
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 position/2 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 position/3 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 position/4 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 position/5 4
			append names name
			id: id + 1
			position: skip position 5
		]

		position: functions
		instruction-count: 0
		id: 1
		while [not tail? position][
			name: position/1
			params: position/7
			locals: position/8
			flags: position/9
			if select no-return-functions id [flags: flags or no-return-flag]
			param-count: (length? params) / 3
			local-count: storage-local-count locals
			first-local: first-param + param-count
			record-offset: function-records + ((id - 1) * 36)
			change/part at output record-offset
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 position/6 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 flags 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 first-param 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 param-count 4
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 first-local 4
			change/part at output (record-offset + 28)
				int-to-bin/to-bin32 local-count 4
			change/part at output (record-offset + 32)
				int-to-bin/to-bin32 position/10 4
			parameter: params
			while [not tail? parameter][
				emit output reduce [parameter/2 parameter/3]
				parameter: skip parameter 3
			]
			parameter: locals
			while [not tail? parameter][
				if all [storage-local? parameter parameter/2 = 0][
					fail ERROR-UNSUPPORTED [
						"local type is unresolved: " mold parameter/1
					]
				]
				if storage-local? parameter [
					emit output reduce [parameter/2 parameter/3]
				]
				parameter: skip parameter 3
			]
			append names name
			first-param: first-local + local-count
			instruction-count: instruction-count + position/10
			id: id + 1
			position: skip position 10
		]

		position: exports
		id: 1
		while [not tail? position][
			name: position/5
			record-offset: export-records + ((id - 1) * 12)
			change/part at output record-offset int-to-bin/to-bin32 position/1 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 (length? name) 4
			append names name
			id: id + 1
			position: skip position 5
		]
		append output initializers
		append output switches
		append output function-code
		append output names
		size: length? output
		if any [limit <= 0 size > limit] [
			fail ERROR-LIMIT "RSIR output exceeds its limit"
		]
		entry: either module-kind = 3 [function-count][0]
		change/part output int-to-bin/to-bin32 module-kind 4
		change/part at output 5 int-to-bin/to-bin32 entry 4
		change/part at output 9 int-to-bin/to-bin32 type-count 4
		change/part at output 13 int-to-bin/to-bin32 import-count 4
		change/part at output 17 int-to-bin/to-bin32 function-count 4
		change/part at output 21 int-to-bin/to-bin32 instruction-count 4
		change/part at output 25 int-to-bin/to-bin32 global-count 4
		change/part at output 29 int-to-bin/to-bin32 switch-count 4
		change/part at output 33 int-to-bin/to-bin32 export-count 4
		output
	]

	; Bodies lower directly to typed postfix values and places.
	resolve-stack-call: func [
		value [word! path!]
		scope uses [block!]
		return: [integer! none!]
		/local id
	][
		id: resolve-name value scope uses call-ids
		either integer? id [id][none]
	]

	stack-call-address: func [
		value [word! path!]
		scope uses [block!]
		instructions [binary!]
		return: [logic!]
		/local base target ref
	][
		base: either path? value [value/1][value]
		if all [
			word? base
			not root-qualified? value
			block? stack-storage-info base
		][return false]
		unless (resolve-value-kind value scope uses) = 2 [return false]
		target: resolved-value-id
		ref: call-signature-ref target
		emit instructions reduce [
			address-op either target > 0 [function-address][import-address]
			either target > 0 [target][0 - target]
			ref
		]
		emit instructions reduce [reference-op ref 0 0]
		last-type: ref
		last-flags: 0
		last-stopped?: false
		true
	]

	array-pointer-compatible?: func [
		expected actual [integer!]
		return: [logic!]
		/local info target
	][
		unless info: array-info actual [return false]
		unless target: pointee-ref expected [return false]
		(canonical-ref target) = canonical-ref info/1
	]

	reference-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [pointer c-string struct union array function null] kind
	]

	function-signatures-compatible?: func [
		expected actual [integer!]
		visited [block!]
		return: [logic!]
		/local left right left-parameter right-parameter cursor
	][
		cursor: visited
		while [not tail? cursor][
			if all [cursor/1 = expected cursor/2 = actual][return true]
			cursor: skip cursor 2
		]
		append visited expected
		append visited actual
		left: function-signature expected
		right: function-signature actual
		unless all [block? left block? right][return false]
		if any [
			(left/4 and cdecl-flag) <> (right/4 and cdecl-flag)
			(left/4 and call-shape-flags) <> (right/4 and call-shape-flags)
		][
			return false
		]
		either left/1 = 0 [
			if right/1 <> 0 [return false]
		][
			if any [
				right/1 = 0
				not stack-type-compatible-at? left/1 right/1 visited
			][return false]
		]
		if (length? left/2) <> length? right/2 [return false]
		left-parameter: left/2
		right-parameter: right/2
		while [not tail? left-parameter][
			if any [
				left-parameter/3 <> right-parameter/3
				not stack-type-compatible-at? left-parameter/2 right-parameter/2
					visited
			][return false]
			left-parameter: skip left-parameter 3
			right-parameter: skip right-parameter 3
		]
		true
	]

	stack-type-compatible-at?: func [
		expected actual [integer!]
		visited [block! none!]
		return: [logic!]
		/local expected-kind actual-kind
	][
		expected: canonical-ref expected
		actual: canonical-ref actual
		if expected = actual [return true]
		if any [expected = 0 actual = 0] [return false]
		expected-kind: ref-kind expected
		actual-kind: ref-kind actual
		if any [expected-kind = 'null actual-kind = 'null][
			return all [reference-kind? expected-kind reference-kind? actual-kind]
		]
		if all [
			any [expected = -12 actual = -12]
			expected-kind = 'pointer
			actual-kind = 'pointer
		][return true]
		if array-pointer-compatible? expected actual [return true]
		if all [expected-kind = 'function actual-kind = 'function][
			if none? visited [visited: make block! 8]
			return function-signatures-compatible? expected actual visited
		]
		if any [reference-kind? expected-kind reference-kind? actual-kind][return false]
		either all [expected > 0 actual > 0][
			false
		][
			expected-kind = actual-kind
		]
	]

	stack-type-compatible?: func [
		expected actual [integer!]
		return: [logic!]
	][
		expected: canonical-ref expected
		actual: canonical-ref actual
		if expected = actual [return true]
		stack-type-compatible-at? expected actual none
	]

	integer-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [i8 byte u8 i16 u16 i32 u32 i64 u64] kind
	]

	cast-compatible?: func [
		source target [integer!]
		return: [logic!]
		/local source-kind target-kind
	][
		source-kind: ref-kind source
		target-kind: ref-kind target
		not any [
			all [
				source-kind = 'function
				not find [function pointer i32 u32 i64 u64] target-kind
			]
			all [
				target-kind = 'function
				not find [function c-string pointer struct union array i32 u32 i64 u64]
					source-kind
			]
			all [
				float-kind? target-kind
				not any [float-kind? source-kind source-kind = 'i32]
			]
			all [
				float-kind? source-kind
				not any [float-kind? target-kind target-kind = 'i32]
			]
			all [
				target-kind = 'byte
				find [c-string pointer struct union] source-kind
			]
			all [
				find [c-string pointer struct union] target-kind
				find [byte logic] source-kind
			]
		]
	]

	check-cast: func [
		source source-flags target target-flags [integer!]
		keep? [logic!]
		/local source-kind target-kind
	][
		source-kind: ref-kind source
		target-kind: ref-kind target
		unless all [
			cast-compatible? source target
			any [
				not any [float-kind? source-kind float-kind? target-kind]
				all [
					source-flags = 0
					target-flags = 0
					float-cast-compatible? source target keep?
				]
			]
		][
			fail ERROR-REFERENCE rejoin [
				"type casting from " type-spelling source
				" to " type-spelling target " is not allowed"
			]
		]
		if all [
			source-kind <> 'function
			source-flags = target-flags
			(canonical-ref source) = canonical-ref target
		][
			warn rejoin [
				"type casting from " type-spelling source
				" to " type-spelling target " is not necessary"
			]
		]
	]

	hex-digit: func [value [char!] return: [integer!] /local code][
		code: to integer! value
		case [
			all [code >= 48 code <= 57][code - 48]
			all [code >= 65 code <= 70][code - 55]
			true [-1]
		]
	]

	hex-word: func [digits [string!] return: [integer! none!] /local value digit][
		value: 0
		foreach character digits [
			digit: hex-digit character
			if digit < 0 [return none]
			value: (value << 4) or digit
		]
		value
	]

	greater-digits?: func [left right [string!] return: [logic!]][
		any [
			(length? left) > (length? right)
			all [(length? left) = (length? right) left > right]
		]
	]

	decimal-bits: func [
		digits [string!]
		negative? [logic!]
		return: [block! none!]
		/local limbs carry value digit index low high
	][
		if empty? digits [return none]
		limbs: copy [0 0 0 0]
		foreach character digits [
			digit: (to integer! character) - (to integer! #"0")
			if any [digit < 0 digit > 9][return none]
			carry: digit
			repeat index 4 [
				value: (limbs/:index * 10) + carry
				limbs/:index: value and 65535
				carry: to integer! (value / 65536)
			]
			if carry <> 0 [return none]
		]
		if negative? [
			repeat index 4 [limbs/:index: 65535 - limbs/:index]
			carry: 1
			repeat index 4 [
				value: limbs/:index + carry
				limbs/:index: value and 65535
				carry: to integer! (value / 65536)
			]
		]
		low: (limbs/2 << 16) or limbs/1
		high: (limbs/4 << 16) or limbs/3
		reduce [low high]
	]

	wide-literal: func [
		value
		return: [block! none!]
		/local spelling payload digits negative? bits low high ref
	][
		unless issue? value [return none]
		spelling: form value
		case [
			find/match spelling "u64h-" [
				payload: uppercase copy skip spelling 5
				if any [empty? payload (length? payload) > 16][return none]
				insert/dup payload #"0" (16 - length? payload)
				high: hex-word copy/part payload 8
				low: hex-word skip payload 8
				unless all [integer? low integer? high][return none]
				ref: either high < 0 [-8][-7]
				reduce [ref low high]
			]
			find/match spelling "i64-" [
				payload: skip spelling 4
				negative?: to logic! all [not empty? payload payload/1 = #"n"]
				if negative? [payload: next payload]
				digits: copy payload
				if greater-digits? digits either negative? [
					"9223372036854775808"
				]["9223372036854775807"][return none]
				bits: decimal-bits digits negative?
				if none? bits [return none]
				reduce [-7 bits/1 bits/2]
			]
			find/match spelling "u64-" [
				digits: copy skip spelling 4
				if greater-digits? digits "18446744073709551615" [return none]
				bits: decimal-bits digits false
				if none? bits [return none]
				ref: either bits/2 < 0 [-8][-7]
				reduce [ref bits/1 bits/2]
			]
			true [none]
		]
	]

	little-word: func [data [binary!] return: [integer!]][
		(to integer! data/1)
			or ((to integer! data/2) << 8)
			or ((to integer! data/3) << 16)
			or ((to integer! data/4) << 24)
	]

	integer-literal-since: func [
		output [binary!]
		offset [integer!]
		return: [integer! none!]
		/local instruction ref value high
	][
		unless (length? output) = (offset + 16) [return none]
		instruction: at output (offset + 1)
		unless (little-word instruction) = literal-op [return none]
		ref: little-word skip instruction 4
		unless (ref-kind ref) = 'i32 [return none]
		value: little-word skip instruction 8
		high: little-word skip instruction 12
		unless high = (either value < 0 [-1][0]) [return none]
		value
	]

	float-literal?: func [value return: [logic!]][
		any [
			float? value
			all [issue? value not none? select ieee-754/special64 value]
		]
	]

	null-literal?: func [value return: [logic!]][
		while [paren? value][
			unless (length? value) = 1 [return false]
			value: value/1
		]
		value = 'null
	]

	protected-scalar?: func [value return: [logic!] /local wide][
		case [
			any [integer? value float? value char? value][true]
			issue? value [
				wide: wide-literal value
				any [block? wide float-literal? value]
			]
			true [false]
		]
	]

	float-bits: func [
		value
		kind [word!]
		return: [block! none!]
		/local bytes width low high
	][
		width: either kind = 'f32 [4][either kind = 'f64 [8][0]]
		if width = 0 [return none]
		bytes: either width = 4 [
			ieee-754/to-binary32/rev value
		][ieee-754/to-binary64/rev value]
		unless all [binary? bytes (length? bytes) = width][return none]
		low: little-word bytes
		high: either width = 8 [little-word skip bytes 4][0]
		reduce [low high]
	]

	add-static-bytes: func [
		value [binary!]
		nul? protected? [logic!]
		return: [integer!]
		/local data offset ref id record
	][
		data: copy value
		if nul? [append data 0]
		offset: length? strings
		append strings data
		ref: intern-array -15 length? data 1
		id: add-hidden-global ref (
			inline-flag + either protected? [protected-flag][0]
		)
		record: skip global-data ((id - 1) * 5)
		set-global-initializer record reduce [
			bytes-initializer offset length? data 0
		]
		id
	]

	static-literal-info: func [
		value
		scope uses [block!]
		protected? [logic!]
		return: [block! none!]
		/local wide bits id key target record ref literal
	][
		case [
			issue? value [
				wide: wide-literal value
				if block? wide [
					return reduce [
						wide/1 scalar-initializer wide/2 wide/3 0
					]
				]
				bits: either float-literal? value [float-bits value 'f64][none]
				if block? bits [
					return reduce [-10 scalar-initializer bits/1 bits/2 0]
				]
			]
			float? value [
				bits: float-bits value 'f64
				if block? bits [
					return reduce [-10 scalar-initializer bits/1 bits/2 0]
				]
			]
			integer? value [
				return reduce [
					-5 scalar-initializer value either value < 0 [-1][0] 0
				]
			]
			char? value [
				id: to integer! value
				if id <= 255 [return reduce [-15 scalar-initializer id 0 0]]
			]
			logic? value [
				return reduce [
					-11 scalar-initializer either value [1][0] 0 0
				]
			]
			all [word? value find [true false yes no] value][
				return reduce [
					-11 scalar-initializer either find [true yes] value [1][0] 0 0
				]
			]
			string? value [
				id: add-static-bytes to binary! value true protected?
				return reduce [-13 address-initializer global-address id 0]
			]
			any [get-word? value get-path? value][
				target: either get-word? value [to word! value][to path! value]
				id: resolve-name target scope uses call-ids
				if integer? id [
					ref: call-signature-ref id
					return reduce [
						ref address-initializer
						either id > 0 [function-address][import-address]
						absolute id 0
					]
				]
				id: resolve-name target scope uses globals
				if integer? id [
					record: skip global-data ((id - 1) * 5)
					if integer? record/2 [
						ref: address-reference-ref record/2 record/3
						if integer? ref [
							return reduce [
								ref address-initializer global-address id 0
							]
						]
					]
				]
			]
			any [word? value path? value][
				literal: resolve-name value scope uses literal-values
				if block? literal [return copy literal]
				if integer? literal [
					return reduce [
						-5 scalar-initializer literal
							either literal < 0 [-1][0] 0
					]
				]
			]
		]
		none
	]

	static-literal-width: func [ref [integer!] return: [integer!] /local kind][
		kind: ref-kind ref
		case [
			find [i8 byte u8] kind [1]
			find [i16 u16] kind [2]
			find [i32 u32 f32 logic] kind [4]
			find [i64 u64 f64 pointer c-string function null] kind [8]
			true [0]
		]
	]

	constant-operation: func [
		left operation right
		return: [block! none!]
		/local result
	][
		set/any 'result try [
			switch operation [
				1  [left + right]
				2  [left - right]
				3  [left * right]
				4  [left / right]
				5  [left % right]
				6  [left // right]
				7  [left << right]
				8  [left >> right]
				9  [left >>> right]
				10 [left or right]
				11 [left xor right]
				12 [left and right]
			]
		]
		either error? :result [none][reduce [:result]]
	]

	constant-operand: func [
		value scope uses [block!]
		return: [block! none!]
		/local literal
	][
		case [
			any [integer? value float? value char? value logic? value][reduce [value]]
			all [word? value find [true false yes no] value][
				reduce [not none? find [true yes] value]
			]
			value = 'null [reduce [0]]
			any [word? value path? value][
				literal: resolve-name value scope uses literal-values
				either integer? literal [reduce [literal]][none]
			]
			paren? value [constant-expression value scope uses]
			true [none]
		]
	]

	constant-expression: func [
		value [paren!]
		scope uses [block!]
		return: [block! none!]
		/local position left right operation result
	][
		if empty? value [return none]
		unless left: constant-operand value/1 scope uses [return none]
		left: left/1
		position: next value
		while [not tail? position][
			if (length? position) < 2 [return none]
			operation: select binary-operations position/1
			unless all [integer? operation operation <= 12][return none]
			unless right: constant-operand position/2 scope uses [return none]
			unless result: constant-operation left operation right/1 [return none]
			left: result/1
			position: skip position 2
		]
		reduce [left]
	]

	array-literal-info: func [
		value [block! binary!]
		scope uses [block!]
		protected? [logic!]
		return: [block!]
		/local values item info element count offset width item-width uniform?
	][
		if empty? value [fail ERROR-UNSUPPORTED "literal array is empty"]
		if binary? value [
			offset: length? strings
			append strings value
			return reduce [
				intern-array -15 length? value 1
				reduce [bytes-initializer offset length? value 0]
			]
		]

		values: make block! ((length? value) * 4)
		element: 0
		count: 0
		width: 0
		uniform?: true
		foreach item value [
			if paren? item [
				info: constant-expression item scope uses
				if block? info [item: info/1]
			]
			info: static-literal-info item scope uses protected?
			unless block? info [
				fail ERROR-UNSUPPORTED ["invalid literal array item " mold item]
			]
			item-width: static-literal-width info/1
			if item-width = 0 [
				fail ERROR-UNSUPPORTED ["invalid literal array item " mold item]
			]
			if item-width > width [width: item-width]
			if info/2 = address-initializer [info/5: info/1]
			either element = 0 [
				element: info/1
			][
				if (canonical-ref element) <> canonical-ref info/1 [uniform?: false]
			]
			repend values [info/2 info/3 info/4 info/5]
			count: count + 1
		]
		unless uniform? [
			if width < 4 [width: 4]
			element: either width = 8 [-8][-5]
		]
		reduce [intern-array element count width values]
	]

	stack-array-literal: func [
		position scope uses [block!]
		instructions [binary!]
		return: [block!]
		/local info id record
	][
		info: array-literal-info position/1 scope uses false
		id: add-hidden-global info/1 inline-flag
		record: skip global-data ((id - 1) * 5)
		set-global-initializer record info/2
		emit instructions reduce [address-op global-address id 0]
		emit instructions reduce [load-op 0 0 0]
		last-type: info/1
		last-flags: 0
		last-stopped?: false
		next position
	]

	float-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [f32 f64] kind
	]

	float-cast-compatible?: func [
		source target [integer!]
		keep? [logic!]
		return: [logic!]
		/local source-kind target-kind
	][
		source-kind: ref-kind source
		target-kind: ref-kind target
		unless any [float-kind? source-kind float-kind? target-kind][return true]
		if keep? [
			return any [
				source-kind = target-kind
				all [source-kind = 'i32 target-kind = 'f32]
				all [source-kind = 'f32 target-kind = 'i32]
			]
		]
		any [
			source-kind = target-kind
			all [float-kind? source-kind float-kind? target-kind]
			all [source-kind = 'i32 float-kind? target-kind]
			all [float-kind? source-kind target-kind = 'i32]
		]
	]

	same-stack-type?: func [
		left left-flags right right-flags [integer!]
		return: [logic!]
	][
		all [
			(canonical-ref left) = canonical-ref right
			left-flags = right-flags
		]
	]

	common-stack-ref: func [
		left left-flags right right-flags [integer!]
		return: [integer!]
		/local left-kind right-kind
	][
		if same-stack-type? left left-flags right right-flags [return left]
		unless all [left-flags = 0 right-flags = 0][return 0]
		left-kind: ref-kind left
		right-kind: ref-kind right
		; Null stays polymorphic when it is the selection's first live type.
		case [
			all [left-kind = 'null reference-kind? right-kind][left]
			all [right-kind = 'null reference-kind? left-kind][left]
			all [
				left-kind = right-kind
				find [pointer struct union] left-kind
			][left]
			true [0]
		]
	]

	stack-binary: func [
		operation left left-flags [integer!]
		right-start [integer!]
		instructions [binary!]
		/local left-kind right-kind comparison?
			scope-state anchor overflow-data right-literal shift-limit tracked?
	][
		left-kind: ref-kind left
		right-kind: ref-kind last-type
		comparison?: operation >= 13

		anchor: 0
		overflow-data: 0
		tracked?: false
		unless empty? overflows [
			scope-state: last overflows
			if block? scope-state [
				case [
					all [
						operation <= 3
						left-flags = 0
						integer-kind? left-kind
					][
						tracked?: true
					]
					all [
						operation >= 4
						operation <= 6
						left-flags = 0
						left-kind = 'i32
					][tracked?: true]
					all [
						operation = 7
						left-flags = 0
						integer-kind? left-kind
					][
						right-literal: integer-literal-since instructions right-start
						if integer? right-literal [
							shift-limit: either find [i64 u64] left-kind [63][31]
							if all [right-literal > 0 right-literal <= shift-limit][
								tracked?: true
								overflow-data: right-literal
							]
						]
					]
					true [0]
				]
				if tracked? [
					anchor: scope-state/1
					scope-state/3: scope-state/3 + 1
				]
			]
		]
		emit instructions reduce [binary-op operation anchor overflow-data]
		either comparison? [
			last-type: -11
			last-flags: 0
		][
			if all [float-kind? left-kind float-kind? right-kind][
				left: either any [left-kind = 'f32 right-kind = 'f32][-9][-10]
			]
			last-type: left
			last-flags: left-flags
		]
	]

	register-storage: func [
		name [word!]
		slot [integer!]
		record [block!]
	][
		put function-storage name reduce [slot record]
	]

	prepare-function-storage: func [
		params locals [block!]
		/local position slot
	][
		clear function-storage
		slot: 1
		position: params
		while [not tail? position][
			if word? position/1 [register-storage position/1 slot position]
			position: skip position 3
			slot: slot + 1
		]
		position: locals
		while [not tail? position][
			if word? position/1 [register-storage position/1 slot position]
			if storage-local? position [slot: slot + 1]
			position: skip position 3
		]
	]

	stack-storage-info: func [
		name [word!]
		return: [block! none!]
	][
		select function-storage name
	]

	storage-record: func [
		storage [block!]
		return: [block!]
	][
		storage/2
	]

	collect-subroutines: func [
		body [block!]
		params locals [block!]
		/local position name storage record
	][
		position: body
		while [not tail? position][
			name: none
			storage: none
			either all [
				set-word? position/1
				(length? position) >= 2
				block? position/2
				name: to word! position/1
				storage: stack-storage-info name
				block? storage
				record: storage-record storage
				(ref-kind record/2) = 'subroutine
			][
				if select subroutines name [
					fail ERROR-DUPLICATE ["duplicate subroutine name: " mold name]
				]
				put subroutines name reduce [copy/deep position/2 0 0 false 0]
				; A definition is data for this function. Its body is compiled by
				; the function-level pass, not recursively collected here.
				position: skip position 2
			][
				if block? position/1 [
					collect-subroutines position/1 params locals
				]
				position: next position
			]
		]
	]

	order-subroutine: func [
		name [word!]
		/local record
	][
		record: select subroutines name
		unless block? record [fail ERROR-REFERENCE ["undefined subroutine " mold name]]
		case [
			record/5 = 3 [exit]
			record/5 = 2 [exit]
			record/5 = 1 [fail ERROR-CONTEXT ["recursive subroutine " mold name]]
			true [0]
		]
		record/5: 1
		order-subroutine-body record/1
		record/5: 2
		append subroutine-order name
	]

	order-subroutine-body: func [
		body [block!]
		/local position name record
	][
		position: body
		while [not tail? position][
			name: none
			either all [
				set-word? position/1
				(length? position) >= 2
				block? position/2
				name: to word! position/1
				select subroutines name
			][
				position: skip position 2
			][
				if all [word? position/1 record: select subroutines position/1][
					order-subroutine position/1
				]
				if block? position/1 [order-subroutine-body position/1]
				position: next position
			]
		]
	]

	stack-use: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local spec body cursor names-start name ref flags record-index record
			active-records stopped? saved slot
	][
		unless function-active? [
			fail ERROR-CONTEXT "USE is only allowed inside a function"
		]
		unless all [
			(length? position) >= 3
			block? position/2
			block? position/3
		][fail ERROR-UNSUPPORTED "USE requires a local specification and body"]
		spec: position/2
		body: position/3
		active-records: make block! 8
		cursor: spec
		while [not tail? cursor][
			unless word? cursor/1 [
				fail ERROR-UNSUPPORTED ["invalid USE local " mold cursor/1]
			]
			names-start: cursor
			while [all [not tail? cursor word? cursor/1]][
				if refinement? cursor/1 [
					fail ERROR-UNSUPPORTED "USE does not accept refinements"
				]
				cursor: next cursor
			]
			unless all [not tail? cursor block? cursor/1][
				fail ERROR-UNSUPPORTED "USE local is missing its type"
			]
			ref: type-ref cursor/1 scope uses
			flags: type-flags cursor/1 scope uses
			if (ref-kind ref) = 'subroutine [
				fail ERROR-UNSUPPORTED "subroutines cannot be defined by USE"
			]
			while [names-start <> cursor][
				name: names-start/1
				if stack-storage-info name [
					fail ERROR-DUPLICATE ["duplicate USE local " mold name]
				]
				saved: select use-local-slots name
				either block? saved [
					record-index: saved/1
					slot: saved/2
					record: skip locals ((record-index - 1) * 3)
					unless all [
						stack-type-compatible? record/2 ref
						record/3 = flags
					][
						fail ERROR-REFERENCE [
							"conflicting USE local type " mold name
						]
					]
					record/1: name
				][
					record-index: 1 + ((length? locals) / 3)
					slot: 1 + ((length? params) / 3) + storage-local-count locals
					append locals name
					append locals ref
					append locals flags
					record: skip locals ((record-index - 1) * 3)
					put use-local-slots name reduce [record-index slot]
				]
				register-storage name slot record
				append active-records record-index
				names-start: next names-start
			]
			cursor: next cursor
		]
		stack-block body scope uses instructions params locals statement-value
		stopped?: last-stopped?
		; The slots remain available for a later same-name USE, but their source
		; names leave the active lexical environment with this body.
		foreach record-index active-records [
			record: skip locals ((record-index - 1) * 3)
			remove/key function-storage record/1
			record/1: none
		]
		last-type: 0
		last-flags: 0
		last-stopped?: stopped?
		skip position 3
	]

	stack-with: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local target body child next-uses stopped?
	][
		unless all [
			(length? position) >= 3
			any [word? position/2 path? position/2 block? position/2]
			block? position/3
		][fail ERROR-CONTEXT "WITH requires a context and body block"]
		target: position/2
		body: position/3
		child: resolve-with target scope uses
		next-uses: copy/deep uses
		append next-uses child
		stack-block body scope next-uses instructions params locals statement-value
		stopped?: last-stopped?
		last-type: 0
		last-flags: 0
		last-stopped?: stopped?
		skip position 3
	]

	stack-subroutine: func [
		position [block!]
		name [word!]
		instructions [binary!]
		return: [block!]
		/local record
	][
		record: select subroutines name
		unless block? record [
			fail ERROR-REFERENCE ["undefined subroutine " mold name]
		]
		unless record/5 = 3 [
			if name = active-subroutine [
				fail ERROR-CONTEXT ["recursive subroutine " mold name]
			]
			fail ERROR-REFERENCE ["subroutine is used before its definition " mold name]
		]
		emit instructions reduce [
			subroutine-call-op record/2 record/3 (either record/4 [1][0])
		]
		last-type: record/3
		last-flags: 0
		last-stopped?: record/4
		next position
	]

	stack-read-type: func [
		position [block!]
		scope uses [block!]
		return: [block!]
		/local type token
	][
		if tail? position [
			fail ERROR-UNSUPPORTED "missing logical type"
		]
		token: position/1
		either block? token [
			type: token
			position: next position
		][
			unless any [word? token path? token][
				fail ERROR-UNSUPPORTED "missing logical type"
			]
			type: reduce [token]
			position: next position
			if all [
				word? token
				find [pointer! struct! union! function! subroutine!] token
				not tail? position
				block? position/1
			][
				append/only type position/1
				position: next position
			]
		]
		last-type: type-ref type scope uses
		last-flags: type-flags type scope uses
		reduce [position last-type last-flags]
	]

	stack-cast: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local type-info target-position target-spec target-ref target-flags
			target-kind source keep? value
			literal-end bits next-position source-ref source-flags
			stored-function? id
	][
		target-position: next position
		if all [
			not tail? target-position
			word? target-position/1
			find [pointer! struct! union! function! subroutine!] target-position/1
			any [
				tail? next target-position
				not block? target-position/2
			]
		][
			target-spec: copy/part target-position 2
			fail ERROR-UNSUPPORTED [
				"invalid target type casting:" mold target-spec
			]
		]
		type-info: stack-read-type next position scope uses
		target-ref: type-info/2
		target-flags: type-info/3
		target-kind: ref-kind target-ref
		source: type-info/1
		keep?: false
		if all [not tail? source source/1 = 'keep][
			keep?: true
			source: next source
		]
		if tail? source [fail ERROR-UNSUPPORTED "cast is missing its value"]
		value: source/1
		literal-end: next source
		if all [
			binary? value
			target-flags = 0
			find [c-string pointer] target-kind
		][
			check-cast -13 0 target-ref target-flags keep?
			id: add-static-bytes value false false
			emit instructions reduce [address-op global-address id 0]
			emit instructions reduce [reference-op target-ref 0 0]
			last-type: target-ref
			last-flags: 0
			last-stopped?: false
			return literal-end
		]
		if all [
			target-flags = 0
			float-kind? target-kind
			any [
				all [not keep? float-literal? value]
				all [target-kind = 'f32 integer? value]
			]
			any [tail? literal-end none? select binary-operations literal-end/1]
		][
			source-ref: either integer? value [-5][-10]
			check-cast source-ref 0 target-ref target-flags keep?
			bits: either keep? [
				reduce [value 0]
			][
				float-bits either integer? value [to float! value][value] target-kind
			]
			unless block? bits [fail ERROR-UNSUPPORTED "invalid floating-point literal"]
			emit instructions reduce [literal-op target-ref bits/1 bits/2]
			last-type: target-ref
			last-flags: 0
			return literal-end
		]

		stored-function?: false
		if all [
			target-kind = 'function
			any [word? source/1 path? source/1]
			not any [get-word? source/1 get-path? source/1]
			(resolve-value-kind source/1 scope uses) <> 2
		][
			stored-function?: stack-address source/1 scope uses instructions params locals
			if stored-function? [
				emit instructions reduce [load-op 0 0 0]
				next-position: next source
			]
		]
		unless stored-function? [
			next-position: stack-value source scope uses instructions params locals
				expression-value
			if last-stopped? [return next-position]
		]
		source-ref: last-type
		source-flags: last-flags
		if all [source-ref = -14 null-literal? value][
			fail ERROR-REFERENCE "null cannot be explicitly cast"
		]
		check-cast source-ref source-flags target-ref target-flags keep?
		unless all [
			target-flags = source-flags
			stack-type-compatible? target-ref source-ref
			any [
				(canonical-ref target-ref) = canonical-ref source-ref
				all [
					(ref-kind target-ref) <> 'function
					(ref-kind source-ref) <> 'function
					(canonical-ref target-ref) <> -12
					(canonical-ref source-ref) <> -12
					(canonical-ref source-ref) <> -14
				]
			]
		][
			emit instructions reduce [cast-op target-ref target-flags either keep? [1][0]]
		]
		last-type: target-ref
		last-flags: target-flags
		next-position
	]

	stack-symbol-address: func [
		target [word! path!]
		scope uses [block!]
		instructions [binary!]
		return: [logic!]
		/local id position
	][
		id: resolve-name target scope uses globals
		if integer? id [
			emit instructions reduce [address-op global-address id 0]
			position: skip global-data ((id - 1) * 5)
			last-type: any [position/2 0]
			last-flags: position/3 and inline-flag
			return true
		]
		id: import-variable-id target scope uses
		if integer? id [
			emit instructions reduce [address-op import-address id 0]
			position: skip imports ((id - 1) * 10)
			last-type: position/8
			last-flags: 0
			return true
		]
		false
	]

	stack-address: func [
		target [word! path!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		/write
		return: [logic!]
		/local position part parts index prefix base candidate current flags info
			storage kind element bits place? owner
	][
		parts: either path? target [to block! target][none]
		base: either block? parts [parts/1][target]
		if all [
			block? parts
			word? base
			resolve-name base scope uses enum-values
		][fail ERROR-REFERENCE ["enumeration cannot be used as path root:" base]]
		place?: false
		if all [word? base not root-qualified? target][
			storage: stack-storage-info base
			if block? storage [
				position: storage-record storage
				if (ref-kind position/2) = 'subroutine [
					fail ERROR-REFERENCE ["subroutine has no address " mold target]
				]
				owner: select subroutine-inferred base
				if all [
					not write
					word? active-subroutine
					any [
						position/2 = 0
						all [word? owner owner <> active-subroutine]
					]
				][
					fail ERROR-REFERENCE [
						"type declaration missing for variable " mold base
						" used in subroutine " mold active-subroutine
					]
				]
				emit instructions reduce [address-op local-address storage/1 0]
				last-type: position/2
				last-flags: position/3
				if word? target [return true]
				current: last-type
				flags: last-flags
				place?: true
				index: 2
			]
		]
		unless place? [
			if stack-symbol-address target scope uses instructions [return true]
			if word? target [return false]
			if (length? parts) < 2 [return false]
			prefix: (length? parts) - 1
			while [prefix >= 2][
				candidate: to path! copy/part parts prefix
				if stack-symbol-address candidate scope uses instructions [
					current: last-type
					flags: last-flags
					place?: true
					index: prefix + 1
					break
				]
				prefix: prefix - 1
			]
			unless place? [
				stack-value reduce [base] scope uses instructions params locals
					expression-value
				current: last-type
				flags: last-flags
				index: 2
			]
		]
		while [index <= length? parts][
			part: parts/:index
			kind: ref-kind current
			case [
				find [struct union] kind [
					unless word? part [
						fail ERROR-REFERENCE ["aggregate member must be a word: " mold part]
					]
					if all [place? flags = 0][
						emit instructions reduce [load-op 0 0 0]
						place?: false
					]
					info: member-info current part
					unless block? info [
						fail ERROR-REFERENCE ["unknown member " mold part]
					]
					emit instructions reduce [
						member-op info/1 either all [
							write tagged-union-ref? current
						][info/1 + 1][0] 0
					]
					current: info/2
					flags: info/3
					place?: true
				]
				find [pointer c-string array] kind [
					if place? [
						emit instructions reduce [load-op 0 0 0]
						flags: 0
						place?: false
					]
					element: pointee-ref current
					unless integer? element [
						fail ERROR-REFERENCE ["pointer has no indexable pointee: " mold part]
					]
					case [
						all [kind = 'pointer word? part part = 'value][
							emit instructions reduce [index-op 0 0 0]
						]
						integer? part [
							bits: one-based-index-bits part
							emit instructions reduce [index-op bits/1 0 bits/2]
						]
						word? part [
							stack-value reduce [part] scope uses instructions params locals
								expression-value
							unless all [
								last-flags = 0
								stack-type-compatible? -5 last-type
							][fail ERROR-REFERENCE "pointer index must be an integer!"]
							emit instructions reduce [index-op 0 1 0]
						]
						true [
							fail ERROR-REFERENCE ["invalid pointer index " mold part]
						]
					]
					current: element
					flags: 0
					place?: true
				]
				true [fail ERROR-REFERENCE ["value cannot be selected by path: " mold target]]
			]
			index: index + 1
		]
		last-type: current
		last-flags: flags
		true
	]

	stack-thrown-address: func [
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		/local id storage
	][
		storage: stack-storage-info 'system
		id: resolve-name 'system scope uses globals
		if all [not block? storage not integer? id][
			id: resolve-name 'system scope uses import-ids
		]
		if all [not block? storage not integer? id][
			id: resolve-name 'system scope uses function-ids
		]
		either any [block? storage integer? id][
			unless stack-address/write first [system/thrown]
				scope uses instructions params locals [
				fail ERROR-REFERENCE "system/thrown requires an aggregate variable"
			]
			unless all [last-flags = 0 (ref-kind last-type) = 'i32][
				fail ERROR-REFERENCE "system/thrown must be an integer! member"
			]
		][
			id: ensure-thrown-global
			emit instructions reduce [address-op global-address id 0]
			last-type: -5
			last-flags: 0
		]
	]

	stack-custom-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return-ref signature-ref [integer!]
		return: [block!]
		/local position-after
	][
		position-after: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [
			finish-stopped-expression instructions
			return position-after
		]
		unless last-type <> 0 [
			fail ERROR-REFERENCE ["custom call count is missing: " mold value]
		]
		emit instructions reduce [
			call-op target 1 either target = 0 [signature-ref][return-ref]
		]
		last-type: return-ref
		last-flags: 0
		last-stopped?: direct-no-return? target
		if last-stopped? [last-type: 0]
		position-after
	]

	direct-no-return?: func [target [integer!] return: [logic!]][
		to logic! all [
			target > 0
			(function-flags and catch-flag) = 0
			select no-return-functions target
		]
	]

	finish-stopped-expression: func [instructions [binary!]][
		; Syntax after a terminating subexpression is still parsed. Terminate any
		; disconnected postfix suffix which can otherwise fall through.
		unless last-stopped? [emit instructions reduce [fail-op 102 0 0]]
		last-type: 0
		last-flags: 0
		last-stopped?: true
	]

	stack-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local record return-ref parameters flags mode
			parameter count position-after stopped?
	][
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			return-ref: record/6
			parameters: record/7
			flags: record/9
		][
			record: skip imports (((0 - target) - 1) * 10)
			return-ref: record/8
			parameters: record/9
			flags: record/10
		]
		mode: flags and (variadic-flag + typed-flag + custom-flag)
		if mode <> 0 [
			case [
				mode = variadic-flag [
					return stack-variadic-call target value position scope uses instructions
						params locals return-ref parameters flags 0
				]
				mode = typed-flag [
					return stack-typed-call target value position scope uses instructions
						params locals return-ref parameters flags
						(call-signature-ref target)
				]
				mode = custom-flag [
					return stack-custom-call target value position scope uses instructions
						params locals return-ref 0
				]
				true [fail ERROR-UNSUPPORTED "unsupported call attributes"]
			]
		]
		count: 0
		stopped?: false
		parameter: parameters
		position-after: next position
		while [not tail? parameter][
			if all [not tail? position-after block? position-after/1][
				fail ERROR-UNSUPPORTED "literal arrays cannot be passed as argument"
			]
			position-after: stack-value position-after scope uses instructions params locals
				expression-value
			if last-stopped? [stopped?: true]
			unless any [last-stopped? last-type <> 0][
				fail ERROR-REFERENCE rejoin [
					"argument is missing a value on calling: " source-name value
				]
			]
			count: count + 1
			parameter: skip parameter 3
		]
		if stopped? [
			finish-stopped-expression instructions
			return position-after
		]
		emit instructions reduce [call-op target count return-ref]
		last-type: return-ref
		last-flags: 0
		last-stopped?: direct-no-return? target
		if last-stopped? [last-type: 0]
		position-after
	]

	stack-infix-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local record return-ref position-after stopped?
	][
		if path? value [
			fail ERROR-UNSUPPORTED "infix functions cannot be called using a path"
		]
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			return-ref: record/6
		][
			record: skip imports (((0 - target) - 1) * 10)
			return-ref: record/8
		]
		stopped?: last-stopped?
		unless any [stopped? last-type <> 0][
			fail ERROR-REFERENCE ["infix function is missing its left argument " mold value]
		]
		position-after: stack-primary next position scope uses instructions params locals
			expression-value
		if last-stopped? [stopped?: true]
		unless any [last-stopped? last-type <> 0][
			fail ERROR-REFERENCE ["infix function is missing its right argument " mold value]
		]
		if stopped? [
			finish-stopped-expression instructions
			return position-after
		]
		emit instructions reduce [call-op target 2 return-ref]
		last-type: return-ref
		last-flags: 0
		last-stopped?: direct-no-return? target
		if last-stopped? [last-type: 0]
		position-after
	]

	packed-variadic-signature?: func [
		parameters [block!]
		return: [logic!]
		/local count tail-parameter
	][
		count: (length? parameters) / 3
		unless any [count = 2 count = 3][return false]
		unless all [
			parameters/3 = 0
			(ref-kind parameters/2) = 'i32
			parameters/6 = 0
			find [pointer struct union] ref-kind parameters/5
		][return false]
		if count = 3 [
			tail-parameter: skip parameters 6
			unless all [
				tail-parameter/3 = 0
				(ref-kind tail-parameter/2) = 'i32
			][return false]
		]
		true
	]

	typed-list-signature?: func [
		parameters [block!]
		return: [logic!]
		/local target base record spec scope uses field-spec field-count field-ref
	][
		unless (length? parameters) = 6 [return false]
		unless all [
			parameters/3 = 0
			(ref-kind parameters/2) = 'i32
			parameters/6 = 0
		][return false]
		unless target: pointee-ref parameters/5 [return false]
		base: canonical-ref target
		unless all [base > 0 base <= type-count][return false]
		record: skip types ((base - 1) * 5)
		unless record/2 = 'struct [return false]
		spec: aggregate-members record/2 record/3
		scope: record/4
		uses: record/5
		field-count: (length? spec) / 2
		unless any [field-count = 3 field-count = 4 field-count = 5][
			return false
		]
		field-ref: type-ref spec/2 scope uses
		unless (ref-kind field-ref) = 'i32 [return false]
		if field-count >= 4 [
			field-spec: skip spec 2
			field-ref: type-ref field-spec/2 scope uses
			unless (ref-kind field-ref) = 'i32 [return false]
		]
		true
	]

	stack-typed-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return-ref [integer!]
		parameters [block!]
		flags signature-ref [integer!]
		return: [block!]
		/local cursor next-value arguments count type-id block-arguments? position-after
			stopped?
	][
		unless (length? position) >= 2 [
			fail ERROR-REFERENCE ["typed call is missing its argument: " mold value]
		]
		unless typed-list-signature? parameters [
			fail ERROR-UNSUPPORTED [
				"typed function must declare count and typed-value list: " mold value
			]
		]
		arguments: reduce [signature-ref]
		block-arguments?: block? position/2
		cursor: either block-arguments? [position/2][next position]
		count: 0
		stopped?: false
		while [all [not tail? cursor any [block-arguments? count = 0]]][
			if block? cursor/1 [
				fail ERROR-UNSUPPORTED "literal arrays cannot be passed as argument"
			]
			next-value: stack-value cursor scope uses instructions params locals
				expression-value
			either last-stopped? [
				stopped?: true
			][
				unless all [last-type <> 0 last-flags = 0][
					fail ERROR-UNSUPPORTED [
						"typed argument must be a scalar or reference value: " mold value
					]
				]
				type-id: typed-type-id last-type
				unless type-id > 0 [
					fail ERROR-UNSUPPORTED [
						"typed argument has no runtime type ID: " mold value
					]
				]
				append arguments last-type
				append arguments type-id
			]
			count: count + 1
			cursor: next-value
		]
		position-after: either block-arguments? [skip position 2][cursor]
		if stopped? [
			finish-stopped-expression instructions
			return position-after
		]
		emit instructions reduce [
			call-op target count intern-typed-call signature-ref arguments
		]
		last-type: return-ref
		last-flags: 0
		last-stopped?: direct-no-return? target
		if last-stopped? [last-type: 0]
		position-after
	]

	stack-variadic-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return-ref [integer!]
		parameters [block!]
		flags signature-ref [integer!]
		return: [block!]
		/local cursor next-value parameter count cdecl? stopped?
			block-arguments? position-after
	][
		unless (length? position) >= 2 [
			fail ERROR-REFERENCE ["variadic call is missing its argument: " mold value]
		]
		cdecl?: (flags and 3) = 1
		unless any [
			cdecl?
			all [
				target < 0
				empty? parameters
				(flags and red-internal-flag) = 0
			]
			all [
				packed-variadic-signature? parameters
				any [target >= 0 (flags and red-internal-flag) <> 0]
			]
		][
			fail ERROR-UNSUPPORTED [
				"variadic function must declare count, list, and optional size: "
				mold value
			]
		]
		block-arguments?: block? position/2
		cursor: either block-arguments? [position/2][next position]
		parameter: parameters
		count: 0
		stopped?: false
		while [all [not tail? cursor any [block-arguments? count = 0]]][
			next-value: stack-value cursor scope uses instructions params locals
				expression-value
			if last-stopped? [stopped?: true]
			unless any [last-stopped? last-type <> 0][
				fail ERROR-REFERENCE ["variadic argument has no value: " mold value]
			]
			count: count + 1
			if all [cdecl? not tail? parameter][
				parameter: skip parameter 3
			]
			cursor: next-value
		]
		if all [cdecl? not tail? parameter][
			fail ERROR-REFERENCE ["not enough arguments for function " mold value]
		]
		position-after: either block-arguments? [skip position 2][cursor]
		if stopped? [
			finish-stopped-expression instructions
			return position-after
		]
		emit instructions reduce [
			call-op target count either target = 0 [signature-ref][return-ref]
		]
		last-type: return-ref
		last-flags: 0
		last-stopped?: direct-no-return? target
		if last-stopped? [last-type: 0]
		position-after
	]

	stack-indirect-call: func [
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local signature signature-ref return-ref parameters mode parameter
			count position-after stopped?
	][
		signature-ref: canonical-ref last-type
		signature: function-signature signature-ref
		unless block? signature [
			fail ERROR-REFERENCE ["value is not callable " mold value]
		]
		emit instructions reduce [load-op 0 0 0]
		return-ref: signature/1
		parameters: signature/2
		mode: signature/4 and (variadic-flag + typed-flag + custom-flag)
		if mode <> 0 [
			case [
				mode = variadic-flag [
					return stack-variadic-call 0 value position scope uses instructions
						params locals return-ref parameters signature/4 signature-ref
				]
				mode = typed-flag [
					return stack-typed-call 0 value position scope uses instructions params
						locals return-ref parameters signature/4 signature-ref
				]
				mode = custom-flag [
					return stack-custom-call 0 value position scope uses instructions params
						locals return-ref signature-ref
				]
				true [fail ERROR-UNSUPPORTED "unsupported call attributes"]
			]
		]
		count: 0
		stopped?: false
		parameter: parameters
		position-after: next position
		while [not tail? parameter][
			if all [not tail? position-after block? position-after/1][
				fail ERROR-UNSUPPORTED "literal arrays cannot be passed as argument"
			]
			position-after: stack-value position-after scope uses instructions params locals
				expression-value
			if last-stopped? [stopped?: true]
			unless any [last-stopped? last-type <> 0][
				fail ERROR-REFERENCE rejoin [
					"argument is missing a value on calling: " source-name value
				]
			]
			count: count + 1
			parameter: skip parameter 3
		]
		if stopped? [
			finish-stopped-expression instructions
			return position-after
		]
		emit instructions reduce [call-op 0 count signature-ref]
		last-type: return-ref
		last-flags: 0
		last-stopped?: false
		position-after
	]

	stack-block: func [
		body scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		/local position next-position keep? stopped?
	][
		position: body
		last-type: 0
		last-flags: 0
		last-stopped?: false
		while [not tail? position][
			last-stopped?: false
			if position/1 = 'comment [
				unless (length? position) >= 2 [
					fail ERROR-UNSUPPORTED "COMMENT is missing its value"
				]
				position: skip position 2
				continue
			]
			either any [set-word? position/1 set-path? position/1][
				next-position: stack-assignment position scope uses instructions
					params locals false
			][
				next-position: stack-value position scope uses instructions params locals
					value-context
			]
			stopped?: last-stopped?
			keep?: all [
				tail? next-position
				any [
					value-context = tail-value
					value-context = inferred-value
				]
			]
			unless keep? [
				if all [not stopped? last-type <> 0][
					emit instructions reduce [drop-op 0 0 0]
				]
				last-type: 0
				last-flags: 0
			]
			position: next-position
			last-stopped?: all [tail? position stopped?]
		]
	]

	stack-overflow: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local scope-state stopped? jump-patch target
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "OVERFLOW? requires a body block"
		]
		scope-state: reduce [
			instruction-here instructions
			(length? instructions) + 5
			0
		]
		append/only overflows scope-state
		emit instructions reduce [overflow-op 0 0 0]
		stack-block position/2 scope uses instructions params locals statement-value
		stopped?: last-stopped?
		remove back tail overflows

		either scope-state/3 = 0 [
			unless stopped? [
				emit instructions reduce [literal-op -11 0 0]
			]
		][
			either stopped? [
				target: instruction-here instructions
				patch-control instructions scope-state/2 target
				emit instructions reduce [literal-op -11 1 0]
			][
				emit instructions reduce [literal-op -11 0 0]
				jump-patch: emit-control instructions jump-op 0
				target: instruction-here instructions
				patch-control instructions scope-state/2 target
				emit instructions reduce [literal-op -11 1 0]
				patch-control instructions jump-patch instruction-here instructions
			]
		]

		either all [scope-state/3 = 0 stopped?][
			last-type: 0
			last-flags: 0
			last-stopped?: true
		][
			last-type: -11
			last-flags: 0
			last-stopped?: false
		]
		skip position 2
	]

	stack-catch: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local body anchor patch level target
	][
		body: stack-value next position scope uses instructions params locals
			expression-value
		unless all [
			not last-stopped?
			last-flags = 0
			(ref-kind last-type) = 'i32
		][fail ERROR-REFERENCE "CATCH expects an integer! filter"]
		unless all [not tail? body block? body/1][
			fail ERROR-UNSUPPORTED "CATCH requires a body block"
		]

		anchor: instruction-here instructions
		level: 1 + length? catches
		patch: (length? instructions) + 5
		emit instructions reduce [catch-op 0 level 0]
		append/only catches reduce [anchor level]
		stack-block body/1 scope uses instructions params locals statement-value
		remove back tail catches

		target: instruction-here instructions
		patch-control instructions patch target
		emit instructions reduce [end-catch-op anchor level 0]
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next body
	]

	stack-throw: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after
	][
		after: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return after]
		unless all [last-flags = 0 (ref-kind last-type) = 'i32][
			fail ERROR-REFERENCE "THROW expects an integer! ID"
		]
		stack-thrown-address scope uses instructions params locals
		emit instructions reduce [set-op 0 0 0]
		emit instructions reduce [throw-op 0 0 0]
		last-type: 0
		last-flags: 0
		last-stopped?: true
		after
	]

	stack-assert: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local after before patch never?
	][
		never?: all [
			any [
				value-context = tail-value
				value-context = inferred-value
			]
			(length? position) >= 2
			any [
				position/2 = false
				all [word? position/2 find [false no] position/2]
			]
		]
		before: length? instructions
		after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [not last-stopped? logical-value? last-type last-flags][
			fail ERROR-REFERENCE "ASSERT requires a logic value"
		]
		if never? [
			clear at instructions (before + 1)
			emit instructions reduce [fail-op 98 0 0]
			last-type: 0
			last-flags: 0
			last-stopped?: true
			return after
		]
		either debug? [
			patch: emit-control instructions branch-op 1
			emit instructions reduce [fail-op 98 0 0]
			patch-control instructions patch instruction-here instructions
		][
			clear at instructions (before + 1)
		]
		last-type: 0
		last-flags: 0
		last-stopped?: false
		after
	]

	stack-u16: func [
		position [block!]
		instructions [binary!]
		return: [block!]
		/local data id
	][
		unless all [(length? position) >= 2 string? position/2][
			fail ERROR-UNSUPPORTED "#u16 can only be applied to a literal string"
		]
		data: unicode/to-utf16le position/2
		append data #{0000}
		id: add-static-bytes data false false
		emit instructions reduce [address-op global-address id 0]
		emit instructions reduce [reference-op -13 0 0]
		last-type: -13
		last-flags: 0
		last-stopped?: false
		skip position 2
	]

	expand-red-directive: func [
		position [block!]
		return: [logic!]
		/local directive checks expanded resolved?
	][
		directive: position/1
		case [
			directive = #get [
				unless (length? position) >= 2 [
					fail ERROR-ARGUMENTS "#get is missing its argument"
				]
				resolved?: red-compiler-process-get position/2 position
				unless resolved? [
					fail ERROR-REFERENCE ["cannot resolve #get path " mold position/2]
				]
				true
			]
			directive = #in [
				unless (length? position) >= 3 [
					fail ERROR-ARGUMENTS "#in is missing its path or word"
				]
				resolved?: red-compiler-process-in position/2 position/3 position
				unless resolved? [
					fail ERROR-REFERENCE ["cannot resolve #in path " mold position/2]
				]
				true
			]
			directive = #typecheck [
				unless (length? position) >= 2 [
					fail ERROR-ARGUMENTS "#typecheck is missing its argument"
				]
				checks: red-compiler-process-typecheck position/2
				remove/part position 2
				if block? checks [insert position checks]
				false
			]
			directive = #call [
				unless all [
					(length? position) >= 2
					block? position/2
				][fail ERROR-ARGUMENTS "#call requires a call block"]
				expanded: red-compiler-expand-call position/2 true
				unless block? expanded [
					fail ERROR-REFERENCE "Red compiler could not expand #call"
				]
				remove/part position 2
				insert position expanded
				false
			]
			true [fail ERROR-UNSUPPORTED ["unsupported Red directive " mold directive]]
		]
	]

	stack-if: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local body patch
	][
		body: stack-value next position scope uses instructions params locals
			expression-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "IF requires a conditional expression"
		]
		unless all [not tail? body block? body/1][
			fail ERROR-UNSUPPORTED "IF is missing its body block"
		]
		patch: emit-control instructions branch-op 0
		stack-block body/1 scope uses instructions params locals statement-value
		patch-control instructions patch instruction-here instructions
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next body
	]

	finish-selection: func [
		name [word!]
		arms [block!]
		instructions [binary!]
		after [block!]
		value-context [integer!]
		return: [block!]
		/local arm result-type result-flags common-ref flow? common? drop? target
	][
		result-type: 0
		result-flags: 0
		flow?: false
		common?: true
		arm: arms
		while [not tail? arm][
			unless arm/4 [
				either flow? [
					common-ref: either all [result-type <> 0 arm/2 <> 0][
						common-stack-ref result-type result-flags arm/2 arm/3
					][0]
					either common-ref = 0 [common?: false][
						result-type: common-ref
						result-flags: arm/3
					]
				][
					flow?: true
					result-type: arm/2
					result-flags: arm/3
				]
			]
			arm: skip arm 4
		]
		unless common? [
			result-type: 0
			result-flags: 0
		]

		arm: arms
		while [not tail? arm][
			drop?: all [not arm/4 arm/2 <> 0 result-type = 0]
			if integer? arm/1 [
				patch-control-drop instructions arm/1 either drop? [1][0]
			]
			if all [none? arm/1 drop?][
				emit instructions reduce [drop-op 0 0 0]
			]
			arm: skip arm 4
		]
		target: instruction-here instructions
		arm: arms
		while [not tail? arm][
			if integer? arm/1 [patch-control instructions arm/1 target]
			arm: skip arm 4
		]

		last-type: result-type
		last-flags: result-flags
		last-stopped?: not flow?
		if all [
			any [
				value-context = expression-value
				all [value-context = tail-value tail? after]
			]
			result-type = 0
			not last-stopped?
		][
			fail ERROR-REFERENCE [uppercase form name " bodies do not have a common value"]
		]
		after
	]

	stack-either: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local arms after arm-context branch-patch jump-patch drop-count
			true-type true-flags false-type false-flags
			result-type result-flags common-ref
			true-value? false-value? true-stopped? false-stopped?
	][
		arms: stack-value next position scope uses instructions params locals
			expression-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "EITHER requires a conditional expression"
		]
		unless all [
			(length? arms) >= 2 block? arms/1 block? arms/2
		][fail ERROR-UNSUPPORTED "EITHER requires two body blocks"]
		after: skip arms 2
		arm-context: case [
			value-context = expression-value [tail-value]
			tail? after [value-context]
			true [statement-value]
		]

		branch-patch: emit-control instructions branch-op 0
		stack-block arms/1 scope uses instructions params locals arm-context
		true-type: last-type
		true-flags: last-flags
		true-stopped?: last-stopped?
		true-value?: all [not true-stopped? true-type <> 0]
		jump-patch: none
		unless true-stopped? [
			jump-patch: emit-control instructions jump-op 0
		]

		patch-control instructions branch-patch instruction-here instructions
		stack-block arms/2 scope uses instructions params locals arm-context
		false-type: last-type
		false-flags: last-flags
		false-stopped?: last-stopped?
		false-value?: all [not false-stopped? false-type <> 0]

		result-type: 0
		result-flags: 0
		common-ref: either all [true-value? false-value?][
			common-stack-ref true-type true-flags false-type false-flags
		][0]
		case [
			all [true-value? false-stopped?][
				result-type: true-type
				result-flags: true-flags
			]
			all [false-value? true-stopped?][
				result-type: false-type
				result-flags: false-flags
			]
			common-ref <> 0 [
				result-type: common-ref
				result-flags: true-flags
			]
			true [0]
		]

		if integer? jump-patch [
			drop-count: either all [true-value? result-type = 0][1][0]
			patch-control-drop instructions jump-patch drop-count
		]
		if all [false-value? result-type = 0][
			emit instructions reduce [drop-op 0 0 0]
		]
		if integer? jump-patch [
			patch-control instructions jump-patch instruction-here instructions
		]

		last-type: result-type
		last-flags: result-flags
		last-stopped?: all [true-stopped? false-stopped?]
		if all [
			any [
				value-context = expression-value
				all [value-context = tail-value tail? after]
			]
			result-type = 0
			not last-stopped?
		][fail ERROR-REFERENCE [
			"EITHER blocks do not have a common value"
			any [
				all [active-function rejoin [" in " to string! active-function]]
				""
			]
			rejoin [" (" true-type "/" true-flags ", " false-type "/" false-flags ")"]
		]]
		after
	]

	stack-case: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local body after arm-context cursor action branch-patch jump-patch arms
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "CASE requires a condition/body block"
		]
		body: position/2
		after: skip position 2
		if empty? body [fail ERROR-UNSUPPORTED "CASE body is empty"]
		arm-context: case [
			value-context = expression-value [tail-value]
			tail? after [value-context]
			true [statement-value]
		]
		arms: make block! 16
		cursor: body
		while [not tail? cursor][
			action: stack-value cursor scope uses instructions params locals
				expression-value
			unless logical-value? last-type last-flags [
				fail ERROR-REFERENCE "CASE requires logic conditions"
			]
			unless all [not tail? action block? action/1][
				fail ERROR-UNSUPPORTED "CASE condition is missing its body block"
			]
			branch-patch: emit-control instructions branch-op 0
			stack-block action/1 scope uses instructions params locals arm-context
			jump-patch: none
			unless last-stopped? [
				jump-patch: emit-control instructions jump-op 0
			]
			repend arms [jump-patch last-type last-flags last-stopped?]
			patch-control instructions branch-patch instruction-here instructions
			cursor: next action
		]
		emit instructions reduce [fail-op 100 0 0]
		finish-selection 'case arms instructions after value-context
	]

	switch-bits: func [
		value scope uses [block!]
		return: [block! none!]
		/local number wide
	][
		case [
			integer? value [
				reduce [value either value < 0 [-1][0]]
			]
			char? value [reduce [to integer! value 0]]
			issue? value [
				wide: wide-literal value
				either block? wide [reduce [wide/2 wide/3]][none]
			]
			any [word? value path? value][
				number: resolve-name value scope uses literal-values
				either integer? number [
					reduce [number either number < 0 [-1][0]]
				][none]
			]
			true [none]
		]
	]

	stack-variant: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after ref name info
	][
		after: stack-value next position scope uses instructions params locals
			expression-value
		ref: last-type
		unless all [last-flags = 0 tagged-union-ref? ref][
			fail ERROR-REFERENCE "VARIANT? requires a tagged union value"
		]
		unless all [not tail? after lit-word? after/1][
			fail ERROR-UNSUPPORTED "VARIANT? requires a literal variant name"
		]
		name: to word! after/1
		info: member-info ref name
		unless block? info [
			fail ERROR-REFERENCE ["unknown union variant " mold name]
		]
		emit instructions reduce [tag-op 0 0 0]
		emit instructions reduce [literal-op -5 (info/1 + 1) 0]
		emit instructions reduce [binary-op 13 0 0]
		last-type: -11
		last-flags: 0
		last-stopped?: false
		next after
	]

	stack-switch: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local spec-position spec after arm-context selector-ref selector-kind cursor arms default-body
			patches bits first-case case-count case-patch switch-patch default-target
			arm-position arm target jump-patch missing-jump results last-arm? info
			tagged-selector?
	][
		spec-position: stack-value next position scope uses instructions params locals
			expression-value
		selector-ref: last-type
		selector-kind: ref-kind last-type
		tagged-selector?: all [last-flags = 0 tagged-union-ref? selector-ref]
		either tagged-selector? [
			emit instructions reduce [tag-op 0 0 0]
			last-type: -5
			last-flags: 0
		][unless all [integer-kind? selector-kind last-flags = 0][
			fail ERROR-REFERENCE "SWITCH requires an integer or tagged union value"
		]]
		unless all [not tail? spec-position block? spec-position/1][
			fail ERROR-UNSUPPORTED "SWITCH is missing its body block"
		]
		spec: spec-position/1
		after: next spec-position
		if empty? spec [fail ERROR-UNSUPPORTED "SWITCH body is empty"]
		arm-context: case [
			value-context = expression-value [tail-value]
			tail? after [value-context]
			true [statement-value]
		]
		first-case: (length? switches) / 12
		case-count: 0
		arms: make block! 8
		default-body: none
		cursor: spec
		while [not tail? cursor][
			if all [word? cursor/1 cursor/1 = 'default][
				unless all [(length? cursor) = 2 block? cursor/2][
					fail ERROR-UNSUPPORTED "DEFAULT must be the final SWITCH body"
				]
				default-body: cursor/2
				cursor: tail cursor
				break
			]
			patches: make block! 4
			while [all [not tail? cursor not block? cursor/1]][
				if all [word? cursor/1 cursor/1 = 'default][break]
				bits: either tagged-selector? [
					info: all [word? cursor/1 member-info selector-ref cursor/1]
					either block? info [reduce [info/1 + 1 0]][none]
				][switch-bits cursor/1 scope uses]
				unless block? bits [
					fail ERROR-UNSUPPORTED [
						"invalid SWITCH value: " mold cursor/1
					]
				]
				case-patch: emit-switch-case bits/1 bits/2
				append patches case-patch
				case-count: case-count + 1
				cursor: next cursor
			]
			unless all [not empty? patches not tail? cursor block? cursor/1][
				fail ERROR-UNSUPPORTED "invalid SWITCH value/body group"
			]
			append/only arms reduce [patches cursor/1]
			cursor: next cursor
		]
		if empty? arms [fail ERROR-UNSUPPORTED "SWITCH requires at least one value"]

		switch-patch: (length? instructions) + 13
		emit instructions reduce [switch-op first-case case-count 0]
		missing-jump: none
		if none? default-body [
			default-target: instruction-here instructions
			patch-control instructions switch-patch default-target
			either tagged-selector? [
				missing-jump: emit-control instructions jump-op 0
			][emit instructions reduce [fail-op 101 0 0]]
		]

		results: make block! ((length? arms) * 4) + 4
		if integer? missing-jump [
			repend results [missing-jump 0 0 false]
		]
		arm-position: arms
		while [not tail? arm-position][
			arm: arm-position/1
			target: instruction-here instructions
			foreach case-patch arm/1 [patch-switch-case case-patch target]
			stack-block arm/2 scope uses instructions params locals arm-context
			last-arm?: all [tail? next arm-position none? default-body]
			jump-patch: none
			if all [not last-stopped? not last-arm?][
				jump-patch: emit-control instructions jump-op 0
			]
			repend results [jump-patch last-type last-flags last-stopped?]
			arm-position: next arm-position
		]
		if block? default-body [
			default-target: instruction-here instructions
			patch-control instructions switch-patch default-target
			stack-block default-body scope uses instructions params locals arm-context
			repend results [none last-type last-flags last-stopped?]
		]
		finish-selection 'switch results instructions after value-context
	]

	stack-conditions: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		any? [logic!]
		return: [block!]
		/local body after cursor patches patch decided jump-patch
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "ANY/ALL requires a condition block"
		]
		body: position/2
		after: skip position 2
		if empty? body [
			emit instructions reduce [literal-op -11 either any? [0][1] 0]
			last-type: -11
			last-flags: 0
			last-stopped?: false
			return after
		]
		patches: make block! 4
		cursor: body
		while [not tail? cursor][
			cursor: stack-value cursor scope uses instructions params locals
				expression-value
			either logical-value? last-type last-flags [
				unless tail? cursor [
					patch: emit-control instructions branch-op either any? [1][0]
					append patches patch
				]
			][
				unless all [last-type = 0 not last-stopped?][
					fail ERROR-REFERENCE rejoin [
						either any? ["ANY"]["ALL"]
						" requires a conditional expression"
					]
				]
				; A statement contributes the identity without short-circuiting.
				if tail? cursor [
					emit instructions reduce [
						literal-op -11 either any? [0][1] 0
					]
					last-type: -11
					last-flags: 0
				]
			]
		]
		if empty? patches [
			last-stopped?: false
			return after
		]

		decided: either any? [1][0]
		jump-patch: emit-control instructions jump-op 0
		foreach patch patches [
			patch-control instructions patch instruction-here instructions
		]
		emit instructions reduce [literal-op -11 decided 0]
		patch-control instructions jump-patch instruction-here instructions
		last-type: -11
		last-flags: 0
		last-stopped?: false
		after
	]

	stack-return: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after
	][
		unless function-active? [
			fail ERROR-CONTEXT "return is not allowed outside of a function"
		]
		if function-return = 0 [
			fail ERROR-UNSUPPORTED rejoin [
				"RETURN keyword used without return: declaration in "
				source-name active-function
			]
		]
		if tail? next position [fail ERROR-ARGUMENTS "return is missing an argument"]
		after: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return after]
		unless last-type <> 0 [fail ERROR-REFERENCE rejoin [
			"return value is missing in function: " source-name active-function
		]]
		emit instructions reduce [return-op function-return 0 0]
		function-returns?: true
		last-type: 0
		last-flags: 0
		last-stopped?: true
		after
	]

	stack-exit: func [position [block!] instructions [binary!] return: [block!]][
		unless function-active? [
			fail ERROR-CONTEXT "exit is not allowed outside of a function"
		]
		if function-return <> 0 [
			fail ERROR-REFERENCE "EXIT is incompatible with a function result"
		]
		emit instructions reduce [return-op 0 0 0]
		function-returns?: true
		last-type: 0
		last-flags: 0
		last-stopped?: true
		next position
	]

	open-loop: func [
		continue-target [integer!]
		condition? [logic!]
		return: [block!]
		/local record
	][
		record: reduce [
			continue-target make block! 2 make block! 2 condition? length? catches
		]
		append/only loops record
		record
	]

	close-loop: func [][
		remove back tail loops
	]

	patch-controls: func [
		instructions [binary!]
		patches [block!]
		target [integer!]
		/local patch
	][
		foreach patch patches [patch-control instructions patch target]
	]

	stack-break: func [
		position [block!]
		instructions [binary!]
		return: [block!]
		/local loop-state patch
	][
		if empty? loops [fail ERROR-CONTEXT "BREAK used outside a loop"]
		loop-state: last loops
		if loop-state/4 [fail ERROR-CONTEXT "BREAK used in a WHILE condition block"]
		patch: emit-control instructions jump-op 0
		patch-control-catches instructions patch ((length? catches) - loop-state/5)
		append loop-state/3 patch
		last-type: 0
		last-flags: 0
		last-stopped?: true
		next position
	]

	stack-continue: func [
		position [block!]
		instructions [binary!]
		return: [block!]
		/local loop-state patch
	][
		if empty? loops [fail ERROR-CONTEXT "CONTINUE used outside a loop"]
		loop-state: last loops
		if loop-state/4 [fail ERROR-CONTEXT "CONTINUE used in a WHILE condition block"]
		patch: emit-control instructions jump-op 0
		patch-control-catches instructions patch ((length? catches) - loop-state/5)
		either loop-state/1 > 0 [
			patch-control instructions patch loop-state/1
		][append loop-state/2 patch]
		last-type: 0
		last-flags: 0
		last-stopped?: true
		next position
	]

	stack-loop: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after slot test-target exit-patch loop-state jump-patch
	][
		slot: add-hidden-local params locals -5 0
		after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [(ref-kind last-type) = 'i32 last-flags = 0][
			fail ERROR-REFERENCE "LOOP requires an integer value"
		]
		emit-local-address instructions slot
		unless all [not tail? after block? after/1][
			fail ERROR-UNSUPPORTED "LOOP is missing its body block"
		]
		emit instructions reduce [set-op 0 0 0]
		emit instructions reduce [drop-op 0 0 0]

		test-target: instruction-here instructions
		emit-local-address instructions slot
		emit instructions reduce [load-op 0 0 0]
		emit instructions reduce [literal-op -5 0 0]
		emit instructions reduce [binary-op 15 0 0]
		exit-patch: emit-control instructions branch-op 0

		loop-state: open-loop 0 false
		stack-block after/1 scope uses instructions params locals statement-value
		loop-state/1: instruction-here instructions
		patch-controls instructions loop-state/2 loop-state/1

		emit-local-address instructions slot
		emit instructions reduce [load-op 0 0 0]
		emit instructions reduce [literal-op -5 1 0]
		emit instructions reduce [binary-op 2 0 0]
		emit-local-address instructions slot
		emit instructions reduce [set-op 0 0 0]
		emit instructions reduce [drop-op 0 0 0]
		jump-patch: emit-control instructions jump-op 0
		patch-control instructions jump-patch test-target

		patch-control instructions exit-patch instruction-here instructions
		patch-controls instructions loop-state/3 instruction-here instructions
		close-loop
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next after
	]

	stack-while: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local condition body test-target exit-patch loop-state jump-patch target
	][
		unless all [
			(length? position) >= 3 block? position/2 block? position/3
		][fail ERROR-UNSUPPORTED "WHILE requires condition and body blocks"]
		condition: position/2
		body: position/3
		test-target: instruction-here instructions
		open-loop 0 true
		stack-block condition scope uses instructions params locals tail-value
		close-loop
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE
				"WHILE requires a conditional expression as last expression"
		]
		exit-patch: emit-control instructions branch-op 0

		loop-state: open-loop test-target false
		stack-block body scope uses instructions params locals statement-value
		patch-controls instructions loop-state/2 test-target
		jump-patch: emit-control instructions jump-op 0
		patch-control instructions jump-patch test-target
		target: instruction-here instructions
		patch-control instructions exit-patch target
		patch-controls instructions loop-state/3 target
		close-loop
		last-type: 0
		last-flags: 0
		last-stopped?: false
		skip position 3
	]

	stack-until: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local body start loop-state patch target
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "UNTIL requires a body block"
		]
		body: position/2
		if empty? body [fail ERROR-UNSUPPORTED "UNTIL body is empty"]
		start: instruction-here instructions
		loop-state: open-loop start false
		stack-block body scope uses instructions params locals tail-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE
				"UNTIL requires a conditional expression as last expression"
		]
		patch-controls instructions loop-state/2 start
		patch: emit-control instructions branch-op 0
		patch-control instructions patch start
		target: instruction-here instructions
		patch-controls instructions loop-state/3 target
		close-loop
		last-type: 0
		last-flags: 0
		last-stopped?: false
		skip position 2
	]

	stack-size: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local value storage id record ref info type-info kind bytes wide count
			scratch next-position
	][
		if tail? position [fail ERROR-UNSUPPORTED "SIZE? requires a type or value"]
		value: position/1
		if all [
			any [word? value path? value]
			integer? count: count-enum value scope uses
		][
			emit instructions reduce [literal-op -5 count 0]
			last-type: -5
			last-flags: 0
			last-stopped?: false
			return next position
		]
		kind: either any [word? value path? value][
			type-kind reduce [value] scope uses
		][none]
		if kind [
			type-info: stack-read-type position scope uses
			emit instructions reduce [size-op type-info/2 0 0]
			last-type: -5
			last-flags: 0
			last-stopped?: false
			return type-info/1
		]
		if string? value [
			bytes: to binary! value
			emit instructions reduce [literal-op -5 ((length? bytes) + 1) 0]
			last-type: -5
			last-flags: 0
			last-stopped?: false
			return next position
		]
		ref: none
		case [
			integer? value [ref: -5]
			char? value [
				if (to integer! value) > 255 [
					fail ERROR-UNSUPPORTED "byte literal is out of range"
				]
				ref: -15
			]
			float? value [ref: -10]
			logic? value [ref: -11]
			issue? value [
				wide: wide-literal value
				either block? wide [ref: wide/1][
					if float-literal? value [ref: -10]
				]
			]
			all [word? value find [true false yes no] value][ref: -11]
			value = 'null [ref: -14]
			any [block? value binary? value][
				info: array-literal-info value scope uses false
				ref: info/1
			]
		]
		if word? value [
			storage: stack-storage-info value
			if block? storage [
				record: storage-record storage
				if integer? record/2 [ref: record/2]
			]
		]
		if all [none? ref any [word? value path? value]][
			id: resolve-name value scope uses globals
			if integer? id [
				record: skip global-data ((id - 1) * 5)
				if integer? record/2 [ref: record/2]
			]
		]
		if all [none? ref word? value][
			if integer? resolve-name value scope uses literal-values [ref: -5]
		]
		if all [none? ref path? value][
			scratch: make binary! 64
			if stack-address value scope uses scratch params locals [
				ref: last-type
			]
		]
		if all [integer? ref (ref-kind ref) <> 'c-string][
			emit instructions reduce [size-op ref 0 0]
			last-type: -5
			last-flags: 0
			last-stopped?: false
			return next position
		]
		next-position: stack-primary position scope uses instructions params locals
			expression-value
		unless all [not last-stopped? last-type <> 0][
			fail ERROR-REFERENCE "SIZE? requires a value"
		]
		emit instructions reduce [size-op last-type 1 last-flags]
		last-type: -5
		last-flags: 0
		last-stopped?: false
		next-position
	]

	integer-pointer-value?: func [
		ref flags [integer!]
		return: [logic!]
		/local pointee
	][
		if any [flags <> 0 (ref-kind ref) <> 'pointer][return false]
		pointee: pointee-ref ref
		all [integer? pointee (canonical-ref pointee) = -5]
	]

	stack-atomic: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local path count operation next-position old?
	][
		path: position/1
		count: length? path
		if all [count = 3 path/3 = 'fence][
			emit instructions reduce [native-op atomic-fence-native 0 0]
			last-type: 0
			last-flags: 0
			last-stopped?: false
			return next position
		]
		if all [count = 3 path/3 = 'load][
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				integer-pointer-value? last-type last-flags
			][
				fail ERROR-REFERENCE
					"system/atomic/load expects pointer! [integer!]"
			]
			emit instructions reduce [native-op atomic-load-native 0 -5]
			last-type: -5
			last-flags: 0
			last-stopped?: false
			return next-position
		]
		if all [count = 3 path/3 = 'store][
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				integer-pointer-value? last-type last-flags
			][
				fail ERROR-REFERENCE
					"system/atomic/store expects pointer! [integer!]"
			]
			next-position: stack-value next-position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				last-flags = 0
				(canonical-ref last-type) = -5
			][
				fail ERROR-REFERENCE
					"system/atomic/store expects an integer! value"
			]
			emit instructions reduce [native-op atomic-store-native 0 0]
			last-type: 0
			last-flags: 0
			last-stopped?: false
			return next-position
		]
		if all [count = 3 path/3 = 'cas][
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				integer-pointer-value? last-type last-flags
			][
				fail ERROR-REFERENCE
					"system/atomic/cas expects pointer! [integer!]"
			]
			next-position: stack-value next-position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				last-flags = 0
				(canonical-ref last-type) = -5
			][
				fail ERROR-REFERENCE
					"system/atomic/cas expects an integer! check value"
			]
			next-position: stack-value next-position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				last-flags = 0
				(canonical-ref last-type) = -5
			][
				fail ERROR-REFERENCE
					"system/atomic/cas expects an integer! new value"
			]
			emit instructions reduce [native-op atomic-cas-native 0 -11]
			last-type: -11
			last-flags: 0
			last-stopped?: false
			return next-position
		]
		operation: either count >= 3 [select atomic-operations path/3][none]
		old?: all [count = 4 path/4 = 'old]
		unless all [
			integer? operation
			any [count = 3 old?]
		][fail ERROR-REFERENCE "invalid system/atomic access"]
		next-position: stack-value next position scope uses instructions
			params locals expression-value
		unless all [
			not last-stopped?
			integer-pointer-value? last-type last-flags
		][
			fail ERROR-REFERENCE [
				"system/atomic/" path/3 " expects pointer! [integer!]"
			]
		]
		next-position: stack-value next-position scope uses instructions
			params locals expression-value
		unless all [
			not last-stopped?
			last-flags = 0
			(canonical-ref last-type) = -5
		][
			fail ERROR-REFERENCE [
				"system/atomic/" path/3 " expects an integer! value"
			]
		]
		emit instructions reduce [
			native-op atomic-math-native
			operation + (either old? [atomic-old-flag][0])
			-5
		]
		last-type: -5
		last-flags: 0
		last-stopped?: false
		next-position
	]

	stack-system-path: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block! none!]
		/local path count next-position pointer-ref id
	][
		unless path? position/1 [return none]
		path: position/1
		unless all [
			(length? path) >= 2
			path/1 = 'system
		][return none]
		count: length? path
		if path/2 = 'alias [
			unless all [count = 3 word? path/3][
				fail ERROR-REFERENCE "invalid system/alias access"
			]
			id: resolve-name path/3 scope uses alias-type-ids
			unless integer? id [
				fail ERROR-REFERENCE ["undefined alias name " mold path/3]
			]
			emit instructions reduce [literal-op -5 id 0]
			last-type: -5
			last-flags: 0
			last-stopped?: false
			return next position
		]
		if path/2 = 'thrown [
			unless count = 2 [fail ERROR-REFERENCE "invalid system/thrown access"]
			stack-thrown-address scope uses instructions params locals
			emit instructions reduce [load-op 0 0 0]
			last-stopped?: false
			return next position
		]
		if path/2 = 'pc [
			unless count = 2 [fail ERROR-REFERENCE "invalid system/pc access"]
			pointer-ref: intern-pointer -15
			emit instructions reduce [
				native-op program-counter-native 0 pointer-ref
			]
			last-type: pointer-ref
			last-flags: 0
			last-stopped?: false
			return next position
		]
		if path/2 = 'cpu [
			unless all [count = 3 word? path/3][
				fail ERROR-REFERENCE "invalid system/cpu access"
			]
			either path/3 = 'overflow? [
				emit instructions reduce [native-op cpu-overflow-native 0 -11]
				last-type: -11
			][
				pointer-ref: intern-pointer -5
				emit-native-register instructions cpu-register-native path/3
				last-type: pointer-ref
			]
			last-flags: 0
			last-stopped?: false
			return next position
		]
		if path/2 = 'atomic [
			return stack-atomic position scope uses instructions params locals
		]
		unless path/2 = 'stack [return none]
		case [
			all [count = 3 path/3 = 'top][
				pointer-ref: intern-pointer -5
				emit instructions reduce [native-op stack-top-native 0 pointer-ref]
				last-type: pointer-ref
				last-flags: 0
				last-stopped?: false
				next position
			]
			all [count = 3 path/3 = 'frame][
				pointer-ref: intern-pointer -5
				emit instructions reduce [native-op stack-frame-native 0 pointer-ref]
				last-type: pointer-ref
				last-flags: 0
				last-stopped?: false
				next position
			]
			all [count = 3 path/3 = 'align][
				pointer-ref: intern-pointer -5
				emit instructions reduce [native-op stack-align-native 0 pointer-ref]
				last-type: pointer-ref
				last-flags: 0
				last-stopped?: false
				next position
			]
			all [
				any [
					all [count = 3 path/3 = 'allocate]
					all [
						count = 4
						path/3 = 'allocate
						path/4 = 'zero
					]
				]
			][
				next-position: stack-value next position scope uses instructions
					params locals expression-value
				unless all [
					not last-stopped?
					last-flags = 0
					(ref-kind last-type) = 'i32
				][
					fail ERROR-REFERENCE
						"system/stack/allocate expects an integer! argument"
				]
				pointer-ref: intern-pointer -5
				emit instructions reduce [
					native-op either count = 4 [
						stack-allocate-zero-native
					][stack-allocate-native]
					0 pointer-ref
				]
				last-type: pointer-ref
				last-flags: 0
				last-stopped?: false
				next-position
			]
			all [count = 3 path/3 = 'free][
				next-position: stack-value next position scope uses instructions
					params locals expression-value
				unless all [
					not last-stopped?
					last-flags = 0
					(ref-kind last-type) = 'i32
				][
					fail ERROR-REFERENCE
						"system/stack/free expects an integer! argument"
				]
				emit instructions reduce [native-op stack-free-native 0 0]
				last-type: 0
				last-flags: 0
				last-stopped?: false
				next-position
			]
			all [count = 3 path/3 = 'push-all][
				emit instructions reduce [native-op stack-push-all-native 0 0]
				last-type: 0
				last-flags: 0
				last-stopped?: false
				next position
			]
			all [count = 3 path/3 = 'pop-all][
				emit instructions reduce [native-op stack-pop-all-native 0 0]
				last-type: 0
				last-flags: 0
				last-stopped?: false
				next position
			]
			true [fail ERROR-REFERENCE "invalid system/stack access"]
		]
	]

	stack-system-assignment: func [
		position [block!]
		target [word! path!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block! none!]
		/local pointer-ref next-position id
	][
		unless all [
			path? target
			(length? target) >= 2
			target/1 = 'system
		][return none]
		if target/2 = 'thrown [
			unless (length? target) = 2 [
				fail ERROR-REFERENCE "invalid system/thrown assignment"
			]
			next-position: stack-value next position scope uses instructions params locals
				expression-value
			if last-stopped? [return next-position]
			unless all [last-flags = 0 (ref-kind last-type) = 'i32][
				fail ERROR-REFERENCE "system/thrown expects an integer! value"
			]
			stack-thrown-address scope uses instructions params locals
			emit instructions reduce [set-op 0 0 0]
			last-stopped?: false
			return next-position
		]
		if target/2 = 'pc [
			fail ERROR-REFERENCE "cannot modify system/pc"
		]
		if target/2 = 'cpu [
			unless all [(length? target) = 3 word? target/3][
				fail ERROR-REFERENCE "invalid system/cpu assignment"
			]
			if target/3 = 'overflow? [
				fail ERROR-REFERENCE "cannot modify system/cpu/overflow?"
			]
			pointer-ref: intern-pointer -5
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			if last-stopped? [return next-position]
			emit-native-register instructions cpu-register-set-native target/3
			last-type: pointer-ref
			last-flags: 0
			last-stopped?: false
			return next-position
		]
		unless target/2 = 'stack [return none]
		unless all [
			(length? target) = 3
			any [target/3 = 'top target/3 = 'frame]
		][fail ERROR-REFERENCE "invalid system/stack assignment"]
		pointer-ref: intern-pointer -5
		next-position: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return next-position]
		unless last-type <> 0 [
			fail ERROR-REFERENCE "system/stack assignment requires a value"
		]
		emit instructions reduce [
			native-op either target/3 = 'top [
				stack-top-set-native
			][stack-frame-set-native]
			0 pointer-ref
		]
		last-type: pointer-ref
		last-flags: 0
		last-stopped?: false
		next-position
	]

	stack-push: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local position-after
	][
		position-after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [not last-stopped? last-type <> 0][
			fail ERROR-REFERENCE "PUSH requires a value"
		]
		emit instructions reduce [native-op stack-push-native 0 0]
		last-type: 0
		last-flags: 0
		last-stopped?: false
		position-after
	]

	stack-log-b: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local position-after
	][
		position-after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [
			not last-stopped?
			last-flags = 0
			integer-kind? ref-kind last-type
		][fail ERROR-REFERENCE "LOG-B expects an integer value"]
		emit instructions reduce [native-op log-b-native 0 -5]
		last-type: -5
		last-flags: 0
		last-stopped?: false
		position-after
	]

	stack-named-value: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local value storage literal value-kind next-position target
	][
		value: position/1
		storage: either word? value [stack-storage-info value][none]
		if block? storage [
			unless stack-address value scope uses instructions params locals [
				fail ERROR-REFERENCE ["unknown local value " mold value]
			]
			if last-type = 0 [
				fail ERROR-REFERENCE [
					"local variable" value "used before being initialized!"
				]
			]
			either (ref-kind last-type) = 'function [
				return stack-indirect-call value position scope uses
					instructions params locals
			][
				emit instructions reduce [load-op 0 0 0]
				last-flags: 0
				return next position
			]
		]
		value-kind: resolve-value-kind value scope uses
		literal: either value-kind = 1 [resolved-value-id][none]
		if block? literal [
			emit instructions reduce [
				literal-op literal/1 literal/3 literal/4
			]
			last-type: literal/1
			last-flags: 0
			return next position
		]
		next-position: either all [value-kind = 1 integer? literal][
			emit instructions reduce [
				literal-op -5 literal either literal < 0 [-1][0]
			]
			last-type: -5
			last-flags: 0
			next position
		][
			target: either value-kind = 2 [resolved-value-id][none]
			either integer? target [
				stack-call target value position scope uses instructions params locals
			][
				unless stack-address value scope uses instructions params locals [
					fail ERROR-REFERENCE ["undefined symbol:" mold value]
				]
				if last-type = 0 [
					fail ERROR-REFERENCE [
						"local variable" value "used before being initialized!"
					]
				]
				either (ref-kind last-type) = 'function [
					stack-indirect-call value position scope uses instructions params locals
				][
					emit instructions reduce [load-op 0 0 0]
					last-flags: 0
					next position
				]
			]
		]
		next-position
	]

	stack-primary: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		value-context [integer!]
		return: [block!]
		/local value type-info next-position target id
			inner wide bits storage record bound? expression?
	][
		unless not tail? position [
			fail ERROR-UNSUPPORTED "missing expression"
		]
		error-position: position
		if all [issue? position/1 position/1 = #script][
			position: skip-script position
			if tail? position [
				last-type: 0
				last-flags: 0
				last-stopped?: false
				return position
			]
			error-position: position
		]
		value: position/1
		last-stopped?: false
		if all [issue? value value = #build-date][
			change position mold now/utc
			return stack-primary position scope uses instructions params locals value-context
		]
		if all [
			red-pass?
			issue? value
			find [#get #in #typecheck #call] value
		][
			expression?: expand-red-directive position
			unless expression? [
				last-type: 0
				last-flags: 0
				last-stopped?: false
				return position
			]
			if tail? position [
				last-type: 0
				last-flags: 0
				return position
			]
			return stack-primary position scope uses instructions params locals value-context
		]
		if all [
			word? value
			block? storage: stack-storage-info value
			record: storage-record storage
			(ref-kind record/2) = 'subroutine
		][
			return stack-subroutine position value instructions
		]
		bound?: to logic! all [
			word? value
			any [
				block? storage
				(resolve-value-kind value scope uses) <> 0
			]
		]
		case [
			all [issue? value value = #u16][stack-u16 position instructions]
			all [bound? word? value][
				stack-named-value position scope uses instructions params locals
			]
			value = 'assert [
				stack-assert position scope uses instructions params locals value-context
			]
			value = 'catch [
				stack-catch position scope uses instructions params locals
			]
			value = 'throw [
				stack-throw position scope uses instructions params locals
			]
			value = 'overflow? [
				stack-overflow position scope uses instructions params locals
			]
			value = 'if [
				next-position: stack-if position scope uses instructions params locals
				next-position
			]
			value = 'either [
				next-position: stack-either position scope uses instructions params locals
					value-context
				next-position
			]
			value = 'case [
				next-position: stack-case position scope uses instructions params locals
					value-context
				next-position
			]
			value = 'switch [
				next-position: stack-switch position scope uses instructions params locals
					value-context
				next-position
			]
			value = 'variant? [
				next-position: stack-variant position scope uses instructions params locals
				next-position
			]
			value = 'any [
				next-position: stack-conditions position scope uses instructions params locals true
				next-position
			]
			value = 'all [
				next-position: stack-conditions position scope uses instructions params locals false
				next-position
			]
			value = 'return [
				stack-return position scope uses instructions params locals
			]
			value = 'exit [stack-exit position instructions]
			value = 'loop [
				stack-loop position scope uses instructions params locals
			]
			value = 'while [
				stack-while position scope uses instructions params locals
			]
			value = 'until [
				stack-until position scope uses instructions params locals
			]
			value = 'break [stack-break position instructions]
			value = 'continue [stack-continue position instructions]
			value = 'use [
				stack-use position scope uses instructions params locals
			]
			value = 'with [
				stack-with position scope uses instructions params locals
			]
			paren? value [
				inner: to block! value
				if empty? inner [fail ERROR-UNSUPPORTED "empty expression"]
				next-position: stack-value inner scope uses instructions params locals
					expression-value
				unless tail? next-position [
					fail ERROR-UNSUPPORTED "parenthesized expression is incomplete"
				]
				next position
			]
			value = 'not [
				next-position: stack-value next position scope uses instructions params locals
					expression-value
				unless last-stopped? [
					emit instructions reduce [unary-op not-operation 0 0]
				]
				next-position
			]
			value = 'as [
				stack-cast position scope uses instructions params locals
			]
			value = 'size? [
				stack-size next position scope uses instructions params locals
			]
			value = 'push [
				stack-push position scope uses instructions params locals
			]
			value = 'pop [
				emit instructions reduce [native-op stack-pop-native 0 0]
				last-type: -5
				last-flags: 0
				last-stopped?: false
				next position
			]
			value = 'log-b [
				stack-log-b position scope uses instructions params locals
			]
			value = 'declare [
				fail ERROR-CONTEXT "DECLARE requires an assignment target"
			]
			any [get-word? value get-path? value][
				target: either get-word? value [to word! value][to path! value]
				if stack-call-address target scope uses instructions [
					return next position
				]
				unless stack-address target scope uses instructions params locals [
					fail ERROR-REFERENCE ["undefined symbol:" mold target]
				]
				if all [get-word? value (ref-kind last-type) = 'function][
					emit instructions reduce [load-op 0 0 0]
					last-flags: 0
					return next position
				]
				id: either get-path? value [
					intern-pointer -5
				][address-reference-ref last-type last-flags]
				unless integer? id [
					fail ERROR-REFERENCE ["value cannot be addressed " mold value]
				]
				emit instructions reduce [reference-op id 0 0]
				last-type: id
				last-flags: 0
				next position
			]
			issue? value [
				wide: wide-literal value
				either block? wide [
					emit instructions reduce [literal-op wide/1 wide/2 wide/3]
					last-type: wide/1
				][
					bits: either float-literal? value [float-bits value 'f64][none]
					unless block? bits [
						fail ERROR-UNSUPPORTED ["unsupported issue literal " mold value]
					]
					emit instructions reduce [literal-op -10 bits/1 bits/2]
					last-type: -10
				]
				last-flags: 0
				next position
			]
			float? value [
				bits: float-bits value 'f64
				unless block? bits [fail ERROR-UNSUPPORTED "invalid floating-point literal"]
				emit instructions reduce [literal-op -10 bits/1 bits/2]
				last-type: -10
				last-flags: 0
				next position
			]
			integer? value [
				emit instructions reduce [
					literal-op -5 value either value < 0 [-1][0]
				]
				last-type: -5
				last-flags: 0
				next position
			]
			char? value [
				id: to integer! value
				if id > 255 [fail ERROR-UNSUPPORTED "byte literal is out of range"]
				emit instructions reduce [literal-op -15 id 0]
				last-type: -15
				last-flags: 0
				next position
			]
			logic? value [
				emit instructions reduce [literal-op -11 either value [1][0] 0]
				last-type: -11
				last-flags: 0
				next position
			]
			all [word? value find [true false yes no] value][
				emit instructions reduce [
					literal-op -11 either find [true yes] value [1][0] 0
				]
				last-type: -11
				last-flags: 0
				next position
			]
			value = 'null [
				emit instructions reduce [literal-op -14 0 0]
				last-type: -14
				last-flags: 0
				next position
			]
			string? value [
				id: add-static-bytes to binary! value true false
				emit instructions reduce [address-op global-address id 0]
				emit instructions reduce [reference-op -13 0 0]
				last-type: -13
				last-flags: 0
				next position
			]
			all [
				path? value
				next-position: stack-system-path position scope uses instructions
					params locals
			][next-position]
			any [word? value path? value] [
				stack-named-value position scope uses instructions params locals
			]
			true [
				fail ERROR-UNSUPPORTED ["unsupported expression " mold value]
			]
		]
	]

	stack-value: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		value-context [integer!]
		return: [block!]
		/local operation left left-flags infix-target right-start stopped?
	][
		position: stack-primary position scope uses instructions params locals value-context
		stopped?: last-stopped?
		while [not tail? position][
			if all [issue? position/1 position/1 = #script][
				position: skip-script position
				if tail? position [break]
			]
			operation: select binary-operations position/1
			either integer? operation [
				left: last-type
				left-flags: last-flags
				right-start: length? instructions
				position: stack-primary next position scope uses instructions params locals
					expression-value
				either any [stopped? last-stopped?][
					stopped?: true
				][stack-binary operation left left-flags right-start instructions]
			][
				infix-target: none
				if any [word? position/1 path? position/1][
					infix-target: resolve-stack-call position/1 scope uses
				]
				unless all [integer? infix-target find infix-targets infix-target][break]
				if stopped? [last-stopped?: true]
				position: stack-infix-call infix-target position/1 position
					scope uses instructions params locals
				if last-stopped? [stopped?: true]
			]
		]
		if stopped? [finish-stopped-expression instructions]
		position
	]

	stack-static: func [
		position [block!]
		scope uses [block!]
		protected? [logic!]
		return: [logic!]
		/local value type-info next-position wide bits kind source-ref
			keep? info id
	][
		static?: false
		static-ref: 0
		static-low: 0
		static-high: 0
		static-flags: 0
		static-initializer: none
		static-next: position
		value: position/2
		case [
			any [block? value binary? value][
				info: array-literal-info value scope uses protected?
				static?: true
				static-ref: info/1
				static-flags: inline-flag
				static-initializer: info/2
				static-next: skip position 2
			]
			string? value [
				info: static-literal-info value scope uses protected?
				static?: true
				static-ref: info/1
				static-initializer: reduce [info/2 info/3 info/4 info/5]
				static-next: skip position 2
			]
			any [get-word? value get-path? value][
				info: static-literal-info value scope uses protected?
				if block? info [
					static?: true
					static-ref: info/1
					static-initializer: reduce [info/2 info/3 info/4 info/5]
					static-next: skip position 2
				]
			]
			issue? value [
				wide: wide-literal value
				either block? wide [
					static?: true
					static-ref: wide/1
					static-low: wide/2
					static-high: wide/3
					static-next: skip position 2
				][
					bits: either float-literal? value [float-bits value 'f64][none]
					if block? bits [
						static?: true
						static-ref: -10
						static-low: bits/1
						static-high: bits/2
						static-next: skip position 2
					]
				]
			]
			float? value [
				bits: float-bits value 'f64
				if block? bits [
					static?: true
					static-ref: -10
					static-low: bits/1
					static-high: bits/2
					static-next: skip position 2
				]
			]
			integer? value [
				static?: true
				static-ref: -5
				static-low: value
				static-high: either value < 0 [-1][0]
				static-next: skip position 2
			]
			char? value [
				static-low: to integer! value
				if static-low > 255 [
					fail ERROR-UNSUPPORTED "byte literal is out of range"
				]
				static?: true
				static-ref: -15
				static-high: 0
				static-next: skip position 2
			]
			logic? value [
				static?: true
				static-ref: -11
				static-low: either value [1][0]
				static-next: skip position 2
			]
			all [word? value find [true false yes no] value][
				static?: true
				static-ref: -11
				static-low: either find [true yes] value [1][0]
				static-next: skip position 2
			]
			value = 'as [
				type-info: stack-read-type skip position 2 scope uses
				next-position: type-info/1
				keep?: false
				if all [not tail? next-position next-position/1 = 'keep][
					keep?: true
					next-position: next next-position
				]
				if not tail? next-position [
					value: next-position/1
					kind: ref-kind type-info/2
					bits: none
					if all [
						float-kind? kind
						any [
							all [not keep? any [float-literal? value integer? value]]
							all [keep? kind = 'f32 integer? value]
						]
					][
						source-ref: either integer? value [-5][-10]
						check-cast source-ref 0 type-info/2 type-info/3 keep?
						bits: either keep? [
							reduce [value 0]
						][float-bits either integer? value [to float! value][value] kind]
					]
					either block? bits [
						static?: true
						static-ref: type-info/2
						static-low: bits/1
						static-high: bits/2
						static-next: next next-position
					][if integer? value [
						check-cast -5 0 type-info/2 type-info/3 keep?
						static?: true
						static-ref: type-info/2
						static-low: value
						static-high: either value < 0 [-1][0]
						static-next: next next-position
					]]
					if all [not static?
						any [logic? value all [word? value find [true false yes no] value]]
						kind = 'logic
					][
						check-cast -11 0 type-info/2 type-info/3 keep?
						static?: true
						static-ref: type-info/2
						static-low: either any [
							value = true
							all [word? value find [true yes] value]
						][1][0]
						static-next: next next-position
					]
					if all [
						not static?
						string? value
						find [pointer c-string] kind
					][
						check-cast -13 0 type-info/2 type-info/3 keep?
						id: add-static-bytes to binary! value true protected?
						static?: true
						static-ref: type-info/2
						static-initializer: reduce [
							address-initializer global-address id 0
						]
						static-next: next next-position
					]
					if all [
						not static?
						any [get-word? value get-path? value]
						info: static-literal-info value scope uses protected?
					][
						check-cast info/1 0 type-info/2 type-info/3 keep?
						static?: true
						static-ref: type-info/2
						static-initializer: reduce [info/2 info/3 info/4 info/1]
						static-next: next next-position
					]
				]
			]
		]
		if all [static? none? static-initializer][
			static-initializer: reduce [
				scalar-initializer static-low static-high 0
			]
		]
		static?
	]

	stack-declaration: func [
		position [block!]
		target [word! path!]
		storage [block! none!]
		id [integer! none!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		fold? [logic!]
		return: [block!]
		/local type-info type-position type-token type-spec next-position ref kind
			aggregate? pointer? storage-ref storage-flags
			record hidden target-ref
	][
		type-position: skip position 2
		if tail? type-position [
			fail ERROR-UNSUPPORTED "DECLARE argument type is missing"
		]
		type-token: type-position/1
		type-spec: either block? type-token [type-token][reduce [type-token]]
		unless type-kind type-spec scope uses [
			fail ERROR-UNSUPPORTED [
				"DECLARE argument type" source-name type-token "not found or not supported"
			]
		]
		type-info: stack-read-type skip position 2 scope uses
		next-position: type-info/1
		ref: type-info/2
		if type-info/3 <> 0 [
			fail ERROR-UNSUPPORTED "DECLARE requires a reference type"
		]
		kind: ref-kind ref
		aggregate?: not none? find [struct union] kind
		pointer?: kind = 'pointer

		unless any [aggregate? pointer?] [
			unless word? target [
				fail ERROR-CONTEXT "scalar DECLARE requires a variable target"
			]
			either block? storage [
				record: storage-record storage
				either record/2 = 0 [
					record/2: ref
					record/3: 0
				][unless all [
					record/3 = 0
					stack-type-compatible? record/2 ref
				][fail ERROR-REFERENCE ["declaration changes type " mold target]]]
			][
				unless integer? id [
					fail ERROR-REFERENCE ["unknown declaration target " mold target]
				]
				record: skip global-data ((id - 1) * 5)
				either integer? record/2 [
					unless stack-type-compatible? record/2 ref [
						fail ERROR-REFERENCE ["declaration changes type " mold target]
					]
				][
					record/2: ref
					record/3: 0
					record/4: 0
					record/5: 0
				]
			]
			last-type: 0
			last-flags: 0
			last-stopped?: false
			return next-position
		]

		storage-ref: either pointer? [pointee-ref ref][ref]
		unless integer? storage-ref [
			fail ERROR-UNSUPPORTED ["DECLARE pointer has no storable pointee: " mold target]
		]
		storage-flags: either find [struct union] ref-kind storage-ref [inline-flag][0]

		if all [fold? integer? id][
			record: skip global-data ((id - 1) * 5)
			unless integer? record/2 [
				hidden: add-hidden-global storage-ref storage-flags
				record: skip global-data ((id - 1) * 5)
				record/2: ref
				record/3: 0
				set-global-initializer record reduce [
					address-initializer global-address hidden 0
				]
				last-type: 0
				last-flags: 0
				last-stopped?: false
				return next-position
			]
		]

		either function-active? [
			hidden: add-hidden-local params locals storage-ref storage-flags
			emit-local-address instructions hidden
		][
			hidden: add-hidden-global storage-ref storage-flags
			emit instructions reduce [address-op global-address hidden 0]
		]
		emit instructions reduce [reference-op ref 0 0]
		last-type: ref
		last-flags: 0
		unless stack-address/write target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type

		if block? storage [
			record: storage-record storage
			if record/2 = 0 [
				record/2: ref
				record/3: 0
			]
			target-ref: record/2
		]
		if integer? id [
			record: skip global-data ((id - 1) * 5)
			unless integer? record/2 [
				record/2: ref
				record/3: 0
			]
			target-ref: record/2
		]
		emit instructions reduce [set-op 0 0 0]
		last-type: target-ref
		last-flags: 0
		next-position
	]

	protected-target?: func [
		target [word! path!]
		scope uses params locals [block!]
		return: [logic!]
		/local parts count candidate
	][
		parts: either word? target [reduce [target]][to block! target]
		if block? stack-storage-info parts/1 [return false]
		count: length? parts
		while [count > 0][
			candidate: either count = 1 [
				parts/1
			][to path! copy/part parts count]
			if integer? resolve-name candidate scope uses protected [return true]
			count: count - 1
		]
		false
	]

	stack-protect: func [
		position [block!]
		target [word! path!]
		scope uses [block!]
		fold? [logic!]
		return: [block!]
		/local key info id record next-position
	][
		unless all [fold? word? target (length? position) >= 3][
			fail ERROR-CONTEXT "PROTECT is only allowed on a new global value"
		]
		key: qualified scope target
		id: resolve-name target scope uses protected
		unless integer? id [
			fail ERROR-CONTEXT "PROTECT must immediately follow a new global name"
		]
		either id = 0 [
			info: static-literal-info position/3 scope uses true
			unless all [block? info info/2 = scalar-initializer][
				fail ERROR-UNSUPPORTED "PROTECT expects a literal value"
			]
			put literal-values key copy info
			next-position: skip position 3
		][
			unless stack-static next position scope uses true [
				fail ERROR-UNSUPPORTED "PROTECT expects a literal value"
			]
			record: skip global-data ((id - 1) * 5)
			record/2: static-ref
			record/3: static-flags or protected-flag
			set-global-initializer record static-initializer
			next-position: static-next
		]
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next-position
	]

	expand-assignments: func [
		position [block!]
		/local targets last-target value output
	][
		targets: make block! 4
		last-target: position
		while [all [
			(length? last-target) >= 2
			set-word? last-target/2
		]][
			append targets last-target/1
			last-target: next last-target
		]
		value: either any [
			find [integer! float! char! logic!] type?/word last-target/2
			find [true false] last-target/2
		][last-target/2][to word! last-target/1]

		remove/part position last-target
		last-target: skip position 2
		output: make block! ((length? targets) * 2)
		foreach target targets [repend output [target value]]
		insert last-target output
	]

	stack-assignment: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		fold? [logic!]
		return: [block!]
		/local target id record target-ref target-flags next-position storage
			source-ref source-flags owner
			continues? infix-target
	][
		if (length? position) < 2 [fail ERROR-UNSUPPORTED "assignment value is missing"]
		if all [set-word? position/1 set-word? position/2][
			expand-assignments position
		]
		target: either set-word? position/1 [
			to word! position/1
		][to path! position/1]
		next-position: stack-system-assignment position target scope uses instructions
			params locals
		if block? next-position [return next-position]
		storage: either word? target [stack-storage-info target][none]
		id: either block? storage [none][resolve-name target scope uses globals]
		if all [
			block? storage
			record: storage-record storage
			(ref-kind record/2) = 'subroutine
		][
			unless block? position/2 [
				fail ERROR-REFERENCE ["subroutine requires a body block " mold target]
			]
			unless select subroutines target [
				fail ERROR-REFERENCE ["undefined subroutine " mold target]
			]
			last-type: 0
			last-flags: 0
			last-stopped?: false
			return skip position 2
		]
		if position/2 = 'protect [
			return stack-protect position target scope uses fold?
		]
		if position/2 = 'context [
			fail ERROR-CONTEXT "context has to be declared at root level"
		]
		if protected-target? target scope uses params locals [
			fail ERROR-REFERENCE ["cannot modify protected data " mold target]
		]
		if all [
			none? id
			path? target
			word? target/1
			none? stack-storage-info target/1
		][id: add-context-global target scope uses]
		if position/2 = 'declare [
			return stack-declaration position target storage id scope uses instructions
				params locals fold?
		]
		if all [fold? integer? id][
			record: skip global-data ((id - 1) * 5)
			if all [
				not integer? record/2
				stack-static position scope uses false
				static?
			][
				continues?: false
				unless tail? static-next [
					continues?: integer? select binary-operations static-next/1
					if all [
						not continues?
						any [word? static-next/1 path? static-next/1]
					][
						infix-target: resolve-stack-call static-next/1 scope uses
						continues?: to logic! all [
							integer? infix-target
							find infix-targets infix-target
						]
					]
				]
				unless continues? [
					record: skip global-data ((id - 1) * 5)
					record/2: static-ref
					record/3: static-flags
					set-global-initializer record static-initializer
					last-type: 0
					last-flags: 0
					return static-next
				]
			]
		]
		next-position: either any [block? position/2 binary? position/2][
			stack-array-literal next position scope uses instructions
		][
			stack-value next position scope uses instructions params locals
				expression-value
		]
		if last-stopped? [return next-position]
		unless last-type <> 0 [
			fail ERROR-REFERENCE ["assignment has no value for " mold target]
		]
		source-ref: last-type
		source-flags: last-flags
		unless stack-address/write target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type
		target-flags: last-flags
		if all [
			(ref-kind target-ref) = 'array
			target-flags = inline-flag
		][
			fail ERROR-REFERENCE "a literal array pointer cannot be reassigned"
		]
		if block? storage [
			record: storage-record storage
			if record/2 = 0 [
				if source-ref = -14 [
					fail ERROR-REFERENCE "null needs an explicit target type"
				]
				if all [word? target word? active-subroutine][
					owner: active-subroutine
					put subroutine-inferred target owner
				]
				record/2: source-ref
				record/3: source-flags
			]
			target-ref: record/2
		]
		if integer? id [
			record: skip global-data ((id - 1) * 5)
			unless integer? record/2 [
				if source-ref = -14 [
					fail ERROR-REFERENCE "null needs an explicit target type"
				]
				record/2: source-ref
			]
			target-ref: record/2
		]
		emit instructions reduce [set-op 0 0 0]
		last-type: target-ref
		last-flags: source-flags
		next-position
	]

	stack-module: func [
		values scope uses [block!]
		/local position child target next-uses
	][
		position: values
		while [not tail? position][
			error-position: position
			case [
				all [position/1 = 'comment (length? position) >= 2][
					position: skip position 2
				]
				all [issue? position/1 position/1 = #script][
					position: skip-script position
				]
				all [
					issue? position/1
					find [#script #include] position/1
					(length? position) >= 2
				][position: skip position 2]
				all [issue? position/1 position/1 = #user-code][
					if split-module? [
						user-code?: true
						active-module-code: module-code
						active-module-locals: module-locals
					]
					either all [(length? position) >= 2 block? position/2][
						stack-module position/2 scope uses
						position: skip position 2
					][position: next position]
				]
				all [issue? position/1 position/1 = #export][
					position: next position
					if all [not tail? position word? position/1][position: next position]
					position: next position
				]
				all [
					issue? position/1
					position/1 = #enum
					(length? position) >= 3
				][position: skip position 3]
				all [
					issue? position/1
					position/1 = #import
					(length? position) >= 2
				][position: skip position 2]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'alias
				][position: skip position either find [
					pointer! struct! union! function! subroutine!
				] position/3 [4][3]]
				all [
					set-word? position/1
					(length? position) >= 4
					find [func function] position/2
					block? position/3
					block? position/4
				][position: skip position 4]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'context
					block? position/3
				][
					child: append copy scope to word! position/1
					stack-module position/3 child uses
					position: skip position 3
				]
				all [
					position/1 = 'with
					(length? position) >= 3
					any [word? position/2 path? position/2 block? position/2]
					block? position/3
				][
					target: position/2
					child: resolve-with target scope uses
					next-uses: copy/deep uses
					append next-uses child
					stack-module position/3 scope next-uses
					position: skip position 3
				]
				any [set-word? position/1 set-path? position/1][
					position: stack-assignment position scope uses active-module-code
						[] active-module-locals true
					if last-type <> 0 [emit active-module-code reduce [drop-op 0 0 0]]
				]
				true [
					position: stack-value position scope uses active-module-code
						[] active-module-locals
						statement-value
					if last-type <> 0 [
						emit active-module-code reduce [drop-op 0 0 0]
					]
				]
			]
		]
	]

	compile-subroutines: func [
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		/local jump-patch main-entry record marker result stopped? name
	][
		if empty? subroutines [exit]
		clear subroutine-order
		foreach [name record] subroutines [order-subroutine name]
		jump-patch: emit-control instructions jump-op 0
		foreach name subroutine-order [
			record: select subroutines name
			record/2: instruction-here instructions
			marker: length? instructions
			emit instructions reduce [entry-op 1 0 0]
			clear loops
			clear overflows
			clear catches
			active-subroutine: name
			stack-block record/1 scope uses instructions params locals inferred-value
			stopped?: last-stopped?
			result: either stopped? [0][last-type]
			if all [result <> 0 last-flags <> 0][
				fail ERROR-UNSUPPORTED "cannot return an aggregate value from a subroutine"
			]
			record/3: result
			record/4: stopped?
			record/5: 3
			change/part at instructions (marker + 9)
				int-to-bin/to-bin32 result 4
			change/part at instructions (marker + 13)
				int-to-bin/to-bin32 (either stopped? [1][0]) 4
			emit instructions reduce [subroutine-return-op result 0 0]
			active-subroutine: none
		]
		main-entry: instruction-here instructions
		emit instructions reduce [entry-op 0 0 0]
		patch-control instructions jump-patch main-entry
		clear loops
		clear overflows
		clear catches
	]

	stack-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		flags [integer!]
		return: [integer!]
		/local before count
	][
		before: length? instructions
		function-base: to integer! (before / 16)
		function-return: return-ref
		function-flags: flags
		function-active?: true
		function-returns?: false
		function-scope: scope
		function-uses: uses
		clear-resolved-names
		clear loops
		clear overflows
		clear catches
		clear use-local-slots
		prepare-function-storage params locals
		clear subroutines
		clear subroutine-order
		active-subroutine: none
		clear subroutine-inferred
		collect-subroutines body params locals
		compile-subroutines scope uses instructions params locals
		last-type: 0
		last-flags: 0
		last-stopped?: false
		either return-ref = 0 [
			stack-block body scope uses instructions params locals statement-value
			unless last-stopped? [
				emit instructions reduce [return-op 0 0 0]
				function-returns?: true
			]
		][
			stack-block body scope uses instructions params locals tail-value
			unless last-stopped? [
				if last-type = 0 [
					fail ERROR-UNSUPPORTED "function result is missing"
				]
				emit instructions reduce [return-op return-ref 0 0]
				function-returns?: true
			]
		]
		count: to integer! (((length? instructions) - before) / 16)
		function-active?: false
		function-flags: 0
		function-scope: none
		function-uses: none
		clear-resolved-names
		clear overflows
		clear catches
		clear use-local-slots
		clear function-storage
		clear subroutines
		clear subroutine-order
		active-subroutine: none
		clear subroutine-inferred
		count
	]

	set-global: func [
		position scope uses [block!]
	][
		stack-assignment position scope uses module-code [] [] true
	]

	compile-import-set: func [
		position scope uses [block!]
		instructions [binary!]
		module? [logic!]
	][
		stack-assignment position scope uses instructions [] [] module?
	]

	compile-module: func [
		values scope uses [block!]
	][
		function-base: 0
		function-return: 0
		function-flags: 0
		function-active?: false
		clear loops
		clear overflows
		clear catches
		stack-module values scope uses
	]

	compile-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		flags [integer!]
	][
		stack-body return-ref body scope uses instructions params locals flags
	]

	compile: func [
		source [block!]
		kind [word!]
		/runtime runtime-exports [block!]
		/red
		/debug
		/limit max-bytes [integer!]
		/local result
	][
		last-error: none
		error-position: none
		clear warnings
		debug?: to logic! debug
		runtime-library?: to logic! runtime
		red-pass?: to logic! red
		result: catch/name [
			function-active?: false
			function-scope: none
			function-uses: none
			active-function: none
			clear-resolved-names
			module-kind: case [
				kind = 'user [1]
				kind = 'support [2]
				kind = 'glue [3]
				kind = 'library [4]
				true [0]
			]
			if module-kind = 0 [
				fail ERROR-KIND "unsupported RSIR module kind"
			]
			if all [runtime-library? module-kind <> 4][
				fail ERROR-KIND "runtime exports require a shared library module"
			]

			clear runtime-functions
			clear runtime-specs
			clear functions
			clear function-ids
			clear call-ids
			clear infix-targets
			clear contexts
			clear context-members
			clear types
			clear type-ids
			clear enum-types
			clear enum-values
			clear pointer-types
			clear array-types
			clear aggregate-types
			clear canonical-refs
			clear ref-kinds
			clear function-types
			clear function-call-types
			clear import-call-types
			clear subroutine-types
			clear typed-call-types
			clear alias-type-ids
			clear literal-values
			clear protected
			clear imports
			clear import-ids
			clear libraries
			clear exports
			clear export-names
			clear globals
			clear global-data
			clear boot-code
			clear boot-locals
			clear module-code
			clear module-locals
			active-module-code: module-code
			active-module-locals: module-locals
			split-module?: false
			user-code?: false
			clear function-code
			clear function-states
			clear no-return-functions
			clear overflows
			clear catches
			clear initializers
			clear switches
			clear strings
			clear native-names
			clear native-name-patches
			clear use-local-slots
			clear function-storage
			clear subroutines
			clear subroutine-order
			active-subroutine: none
			clear subroutine-inferred
			function-count: 0
			context-count: 0
			type-count: 0
			import-count: 0
			global-count: 0
			thrown-global: 0
			alias-count: 0
			compile-source source either runtime-library? [runtime-exports][none]
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
