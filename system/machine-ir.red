Red [
	Title: "Red/System per-function machine IR"
	File:  %machine-ir.red
]

; Keep the active graph and statistics as script-global GC roots. The compiler
; creates many short-lived IR blocks while compiling itself.
rs-o2-ir-current-root: none
rs-o2-ir-stats-root: make block! 8

rs-o2-ir: context [
	add-op:      '+
	subtract-op: '-
	multiply-op: '*
	divide-op:               first [/]
	modulo-op:               to word! "//"
	remainder-op:            to word! "%"
	left-shift-op:           '<<
	right-shift-op:          '>>
	unsigned-right-shift-op: '-**
	equal-op:            to word! "="
	not-equal-op:        to word! "<>"
	less-op:             to word! "<"
	greater-op:          to word! ">"
	less-or-equal-op:    to word! "<="
	greater-or-equal-op: to word! ">="

	; Function record slots.
	fn-name:              1
	fn-abi:               2
	fn-return-type:       3
	fn-blocks:            4
	fn-current-block:     5
	fn-vreg-count:        6
	fn-flag-count:        7
	fn-next-memory:       8
	fn-memory-state:      9
	fn-stack-version:    10
	fn-stack-objects:    11
	fn-relocations:      12
	fn-safepoints:       13
	fn-source-seq:       14
	fn-source-file:      15
	fn-source-line:      16
	fn-eligible?:        17
	fn-fallback-reasons: 18
	fn-last-result:      19
	fn-last-type:        20
	fn-direct-bytes:     21
	fn-verifier-errors:  22
	fn-instruction-count: 23
	fn-vreg-types:       24
	fn-last-flags:       25
	fn-pass-log:         26
	fn-body-start:       27
	fn-body-end:         28
	fn-selected?:        29
	fn-allocation:       30
	fn-selected-bytes:   31
	fn-frame-bitmap-offset: 32


	; Basic block record slots.
	bb-id:           1
	bb-label:        2
	bb-instructions: 3
	bb-predecessors: 4
	bb-successors:   5
	bb-sealed?:      6
	bb-memory-in:    7
	bb-memory-out:   8
	bb-stack-in:     9
	bb-stack-out:   10

	; Instruction record slots.
	ins-id:         1
	ins-opcode:     2
	ins-result:     3
	ins-type:       4
	ins-operands:   5
	ins-effect:     6
	ins-alias:      7
	ins-memory-in:  8
	ins-memory-out: 9
	ins-flags-in:  10
	ins-flags-out: 11
	ins-stack-in:  12
	ins-stack-out: 13
	ins-source-seq: 14
	ins-source-file: 15
	ins-source-line: 16
	ins-metadata:   17

	; Stack object record slots.
	stack-id:       1
	stack-name:     2
	stack-kind:     3
	stack-type:     4
	stack-size:     5
	stack-align:    6
	stack-gc-kind:  7
	stack-escaped?: 8
	stack-frame-offset: 9

	; Session statistics slots.
	stats-functions: 1
	stats-verified:  2
	stats-eligible:  3
	stats-selected:  4
	stats-fallback:  5
	stats-bytes:     6

	current: none
	stats: rs-o2-ir-stats-root
	session?: no
	function-active?: no
	dump-path: none
	verbose: 0
	debug?: no
	switch-depth: 0
	loop-control-stack: make block! 4
	overflow-control-stack: make block! 4

	make-type: func [
		kind [word!]
		width [integer!]
		reg-class [word!]
		signed? [logic!]
		pointer-scale [integer!]
		gc-kind [word!]
	][
		reduce [kind width reg-class signed? pointer-scale gc-kind]
	]

	valid-type?: func [type][
		all [
			block? type
			(length? type) = 6
			word? type/1
			integer? type/2
			word? type/3
			logic? type/4
			integer? type/5
			word? type/6
			find [none pointer handle] type/6
		]
	]

	same-representation?: func [source target][
		all [
			valid-type? source
			valid-type? target
			source/2 = target/2
			source/3 = target/3
			source/5 = target/5
			any [
				source/1 = target/1
				all [source/1 = 'logic target/1 = 'i32]
				all [source/1 = 'i32 target/1 = 'logic]
				all [source/1 = 'ptr target/1 = 'ptr]
			]
		]
	]

	integer-division-op?: func [opcode [word!]][
		any [
			opcode = divide-op
			opcode = remainder-op
			opcode = modulo-op
		]
	]

	modulus-op?: func [opcode [word!]][
		opcode = modulo-op
	]

	remainder-result-op?: func [opcode [word!]][
		any [opcode = modulo-op opcode = remainder-op]
	]

	make-operand: func [kind [word!] value][
		reduce [kind :value]
	]

	vreg-operand: func [id [integer!]][make-operand 'vreg id]
	immediate-operand: func [value][make-operand 'imm :value]
	local-operand: func [name [word!]][make-operand 'local name]
	global-operand: func [name [word!]][make-operand 'global name]
	symbol-operand: func [name [word!]][make-operand 'symbol name]
	block-operand: func [id [integer!]][make-operand 'block id]

	make-block: func [id [integer!] label [word!]][
		reduce [
			id
			label
			make block! 16
			make block! 4
			make block! 4
			no
			none
			none
			none
			none
		]
	]

	start-session: func [
		opt-level [integer!]
		target [word!]
		path [file! string! none!]
		verbosity [integer!]
		debug-mode [logic!]
	][
		abort-function
		clear rs-o2-ir-stats-root
		append rs-o2-ir-stats-root [0 0 0 0 0 0]
		stats: rs-o2-ir-stats-root
		verbose: verbosity
		debug?: debug-mode
		dump-path: either path [to file! path][none]
		session?: all [opt-level >= 2 target = 'X86-64]
		if dump-path [
			write dump-path rejoin [
				"; Red/System x64 O2 machine IR" newline
				"; target: " form target " opt-level: " opt-level newline newline
			]
		]
		session?
	]

	end-session: does [
		if function-active? [abort-function]
		if dump-path [
			write/append dump-path rejoin [
				"; summary functions=" pick stats stats-functions
				" verified=" pick stats stats-verified
				" eligible=" pick stats stats-eligible
				" selected=" pick stats stats-selected
				" fallback=" pick stats stats-fallback
				" direct-bytes=" pick stats stats-bytes
				newline
			]
		]
		session?: no
	]

	begin-function: func [
		name [word!]
		abi [word!]
		return-type [block! none!]
		source-file [file! string! none!]
		/local entry blocks memory-state
	][
		unless session? [return no]
		if function-active? [abort-function]
		blocks: make block! 4
		memory-state: reduce ['universal 0]
		entry: make-block 1 'entry
		poke entry bb-memory-in copy memory-state
		poke entry bb-memory-out copy memory-state
		append/only blocks entry
		current: rs-o2-ir-current-root: reduce [
			name
			abi
			either return-type [copy/deep return-type][none]
			blocks
			entry
			0
			0
			0
			memory-state
			0
			make block! 8
			make block! 4
			make block! 4
			0
			source-file
			0
			yes
			make block! 4
			none
			none
			0
			make block! 4
			0
			make block! 16
			none
			make block! 8
			0
			0
			no
			make block! 16
			0
			none
		]
		function-active?: yes
		 switch-depth: 0
		 clear loop-control-stack
		 clear overflow-control-stack
		 yes
	]

	abort-function: does [
		current: rs-o2-ir-current-root: none
		function-active?: no
		switch-depth: 0
		clear loop-control-stack
		clear overflow-control-stack
	]

	set-source: func [source-file [file! string! none!] line [integer!]][
		if function-active? [
			poke current fn-source-file source-file
			poke current fn-source-line line
		]
	]

	set-last-result: func [value [integer! none!] type [block! none!]][
		if function-active? [
			poke current fn-last-result value
			poke current fn-last-type either type [copy/deep type][none]
		]
		value
	]

	mark-unsupported: func [reason [word! string!] /local reasons][
		unless function-active? [return none]
		reasons: pick current fn-fallback-reasons
		unless find reasons reason [append reasons reason]
		poke current fn-eligible? no
		none
	]

	sync-current-block-memory: does [
		if function-active? [
			poke pick current fn-current-block bb-memory-out
				copy pick current fn-memory-state
		]
	]

	add-block: func [label [word!] /local blocks block memory-state version][
		unless function-active? [return none]
		sync-current-block-memory
		blocks: pick current fn-blocks
		block: make-block (length? blocks) + 1 label
		version: next-memory-version
		memory-state: reduce ['universal version]
		poke block bb-memory-in copy memory-state
		poke block bb-memory-out copy memory-state
		append/only blocks block
		poke current fn-current-block block
		poke current fn-memory-state copy memory-state
		block
	]

	set-current-block: func [id [integer!] /local blocks block][
		unless function-active? [return no]
		blocks: pick current fn-blocks
		unless all [id >= 1 id <= length? blocks][return no]
		sync-current-block-memory
		block: pick blocks id
		poke current fn-current-block block
		poke current fn-memory-state copy pick block bb-memory-out
		yes
	]

	add-edge: func [from-id [integer!] to-id [integer!] /local blocks from to][
		blocks: pick current fn-blocks
		unless all [
			from-id >= 1
			from-id <= length? blocks
			to-id >= 1
			to-id <= length? blocks
		][
			mark-unsupported 'invalid-cfg-edge
			return no
		]
		from: pick blocks from-id
		to: pick blocks to-id
		unless find pick from bb-successors to-id [append pick from bb-successors to-id]
		unless find pick to bb-predecessors from-id [append pick to bb-predecessors from-id]
		yes
	]

	seal-current-block: does [
		if function-active? [poke pick current fn-current-block bb-sealed? yes]
	]

	current-block-id: does [
		all [function-active? pick pick current fn-current-block bb-id]
	]

	terminator-opcode?: func [opcode [word!]][
		to logic! find [return jump branch switch throw unreachable] opcode
	]

	block-terminated?: func [block [block!] /local instructions][
		instructions: pick block bb-instructions
		all [
			not empty? instructions
			terminator-opcode? pick last instructions ins-opcode
		]
	]

	current-block-terminated?: does [
		all [function-active? block-terminated? pick current fn-current-block]
	]

	block-reachable?: func [target-id [integer!] /local blocks reachable position block successor][
		unless function-active? [return no]
		blocks: pick current fn-blocks
		unless all [target-id >= 1 target-id <= length? blocks][return no]
		reachable: make block! length? blocks
		append reachable 1
		position: reachable
		while [not tail? position][
			block: pick blocks position/1
			foreach successor pick block bb-successors [
				unless find reachable successor [append reachable successor]
			]
			position: next position
		]
		to logic! find reachable target-id
	]

	; Open a detached continuation when source lowering continues after a
	; terminator. Structured CFG hooks can still inspect the terminated block
	; before the next ordinary instruction is materialized.
	ensure-open-block: does [
		if current-block-terminated? [
			add-block 'unreachable-continuation
			set-last-result none none
		]
	]

	new-vreg: func [type [block!] /local id types][
		id: (pick current fn-vreg-count) + 1
		poke current fn-vreg-count id
		types: pick current fn-vreg-types
		repend types [id copy/deep type]
		id
	]

	new-flags: has [id][
		id: (pick current fn-flag-count) + 1
		poke current fn-flag-count id
		poke current fn-last-flags id
		id
	]

	memory-version: func [alias [word!] /local pos][
		pos: find/skip pick current fn-memory-state alias 2
		either pos [pos/2][0]
	]

	set-memory-version: func [alias [word!] version [integer!] /local state pos][
		state: pick current fn-memory-state
		either pos: find/skip state alias 2 [
			pos/2: version
		][
			repend state [alias version]
		]
	]

	next-memory-version: func [/local version][
		version: (pick current fn-next-memory) + 1
		poke current fn-next-memory version
		version
	]

	alias-memory-state: func [alias [word!] /local universal alias-version][
		universal: memory-version 'universal
		alias-version: memory-version alias
		either alias = 'universal [
			reduce ['universal universal]
		][
			reduce ['universal universal alias alias-version]
		]
	]

	memory-dependencies: func [
		effect [word!]
		alias [word!]
		/local before after version
	][
		before: copy alias-memory-state alias
		after: copy before
		case [
			effect = 'read []
			effect = 'write [
				version: next-memory-version
				set-memory-version alias version
				after: alias-memory-state alias
			]
			find [call opaque volatile atomic safepoint throw may-trap] effect [
				before: copy pick current fn-memory-state
				version: next-memory-version
				set-memory-version 'universal version
				after: reduce ['universal version]
			]
			true [before: after: copy []]
		]
		reduce [before after]
	]

	memory-state-value: func [state [block!] alias [word!] /local pos][
		all [pos: find/skip state alias 2 integer? pos/2 pos/2]
	]

	memory-state-projection: func [state [block!] alias [word!] /local universal value][
		universal: any [memory-state-value state 'universal 0]
		either alias = 'universal [
			reduce ['universal universal]
		][
			value: any [memory-state-value state alias 0]
			reduce ['universal universal alias value]
		]
	]

	set-memory-state-value: func [state [block!] alias [word!] version [integer!] /local pos][
		either pos: find/skip state alias 2 [
			pos/2: version
		][
			repend state [alias version]
		]
		version
	]

	rebuild-current-memory-dependencies: func [
		/local version block state instruction effect alias before after
	][
		version: 0
		foreach block pick current fn-blocks [
			state: either (pick block bb-id) = 1 [
				reduce ['universal 0]
			][
				version: version + 1
				reduce ['universal version]
			]
			poke block bb-memory-in copy state
			foreach instruction pick block bb-instructions [
				effect: pick instruction ins-effect
				alias: pick instruction ins-alias
				case [
					effect = 'read [
						before: memory-state-projection state alias
						after: copy before
					]
					effect = 'write [
						before: memory-state-projection state alias
						version: version + 1
						set-memory-state-value state alias version
						after: memory-state-projection state alias
					]
					find [call opaque volatile atomic safepoint throw may-trap] effect [
						before: copy state
						version: version + 1
						set-memory-state-value state 'universal version
						after: reduce ['universal version]
					]
					true [before: after: copy []]
				]
				poke instruction ins-memory-in before
				poke instruction ins-memory-out after
			]
			poke block bb-memory-out copy state
		]
		poke current fn-next-memory version
		poke current fn-memory-state copy pick pick current fn-current-block bb-memory-out
	]

	dynamic-stack-state?: func [state][
		to logic! all [block? state (length? state) = 3 state/1 = 'dynamic-stack]
	]

	valid-stack-state?: func [state /local terms coefficient id type][
		if integer? state [return state >= 0]
		unless all [
			dynamic-stack-state? state
			integer? state/2
			state/2 >= 0
			block? state/3
			even? length? state/3
		][return no]
		terms: state/3
		foreach [coefficient id] terms [
			type: all [integer? id vreg-type id]
			unless all [
				coefficient = -1
				integer? id
				type
				type/1 = 'i32
				type/2 = 4
			][return no]
		]
		yes
	]

	adjust-stack-state: func [state delta [integer!] /local result][
		if integer? state [return state + delta]
		unless dynamic-stack-state? state [return none]
		result: copy/deep state
		result/2: result/2 + delta
		result
	]

	copy-stack-state: func [state][
		either block? state [copy/deep state][state]
	]

	subtract-dynamic-stack-count: func [state id [integer!] /local result][
		result: either integer? state [
			reduce ['dynamic-stack state make block! 2]
		][
			either dynamic-stack-state? state [copy/deep state][return none]
		]
		repend result/3 [-1 id]
		result
	]

	instruction-stack-delta: func [instruction [block!] /local opcode metadata count count-kind][
		opcode: pick instruction ins-opcode
		case [
			opcode = 'stack-push [1]
			opcode = 'stack-pop [-1]
			opcode = 'custom-call [
				metadata: pick instruction ins-metadata
				count: all [block? metadata select metadata 'stack-count]
				count-kind: all [block? metadata select metadata 'count-kind]
				either all [count-kind = 'static integer? count count >= 0][negate count][none]
			]
			true [0]
		]
	]

	instruction-stack-output: func [
		instruction [block!]
		input
		/local opcode metadata count count-kind operands delta
	][
		opcode: pick instruction ins-opcode
		if opcode = 'custom-call [
			metadata: pick instruction ins-metadata
			count: all [block? metadata select metadata 'stack-count]
			count-kind: all [block? metadata select metadata 'count-kind]
			return case [
				all [count-kind = 'static integer? count count >= 0][
					adjust-stack-state input negate count
				]
				count-kind = 'dynamic [
					operands: pick instruction ins-operands
					either all [
						(length? operands) = 2
						operands/2/1 = 'vreg
					][subtract-dynamic-stack-count input operands/2/2][none]
				]
				true [none]
			]
		]
		delta: instruction-stack-delta instruction
		either integer? delta [adjust-stack-state input delta][none]
	]

	rebuild-block-stack-dependencies: func [block [block!] input /local depth instruction][
		depth: input
		poke block bb-stack-in copy-stack-state input
		foreach instruction pick block bb-instructions [
			poke instruction ins-stack-in copy-stack-state depth
			depth: instruction-stack-output instruction depth
			poke instruction ins-stack-out copy-stack-state depth
		]
		poke block bb-stack-out copy-stack-state depth
		depth
	]

	rebuild-current-stack-dependencies: func [
		/local blocks pending position id block input output successor target target-input
	][
		blocks: pick current fn-blocks
		foreach block blocks [
			poke block bb-stack-in none
			poke block bb-stack-out none
		]
		if empty? blocks [exit]
		pending: reduce [1]
		position: pending
		while [not tail? position][
			id: position/1
			position: next position
			block: pick blocks id
			input: pick block bb-stack-in
			if none? input [input: either id = 1 [0][none]]
			if not none? input [
				output: rebuild-block-stack-dependencies block input
				if not none? output [foreach successor pick block bb-successors [
					if all [integer? successor successor >= 1 successor <= length? blocks][
						target: pick blocks successor
						target-input: pick target bb-stack-in
						if none? target-input [
							poke target bb-stack-in copy-stack-state output
							unless find pending successor [append pending successor]
						]
					]
				]]
			]
		]
		; Unreachable cycles have no entry edge. Give them a deterministic zero
		; entry so malformed stack operations are still checked by the verifier.
		foreach block blocks [
			if none? pick block bb-stack-in [rebuild-block-stack-dependencies block 0]
		]
	]

	append-op: func [
		opcode [word!]
		operands [block!]
		result-type [block! none!]
		effect [word!]
		alias [word!]
		flags-in [integer! none!]
		define-flags? [logic!]
		metadata [block! none!]
		/local result flags-out memory stack-in stack-out id seq instruction block
	][
		unless function-active? [return none]
		ensure-open-block
		result: either result-type [new-vreg result-type][none]
		flags-out: either define-flags? [new-flags][none]
		memory: memory-dependencies effect alias
		stack-in: pick current fn-stack-version
		stack-out: stack-in
		if any [effect = 'stack find [stack-push stack-pop custom-call] opcode] [
			stack-out: stack-in + 1
			poke current fn-stack-version stack-out
		]
		id: (pick current fn-instruction-count) + 1
		poke current fn-instruction-count id
		seq: (pick current fn-source-seq) + 1
		poke current fn-source-seq seq
		instruction: reduce [
			id
			opcode
			result
			either result-type [copy/deep result-type][none]
			copy/deep operands
			effect
			alias
			memory/1
			memory/2
			flags-in
			flags-out
			stack-in
			stack-out
			seq
			pick current fn-source-file
			pick current fn-source-line
			either metadata [copy/deep metadata][copy []]
		]
		block: pick current fn-current-block
		append/only pick block bb-instructions instruction
		poke block bb-memory-out copy pick current fn-memory-state
		if result [
			poke current fn-last-result result
			poke current fn-last-type copy/deep result-type
		]
		result
	]

	emit-constant: func [value type [block!]][
		append-op 'const reduce [immediate-operand :value] type 'pure 'none none no none
	]

	emit-bitcast: func [value [integer!] type [block!]][
		append-op 'bitcast reduce [vreg-operand value] type 'pure 'none none no none
	]

	coerce-value-type: func [value [integer!] type [block!] /local source][
		source: vreg-type value
		case [
			source = type [value]
			same-representation? source type [emit-bitcast value type]
			true [
				mark-unsupported 'value-type-mismatch
				value
			]
		]
	]

	emit-convert: func [value [integer!] type [block!]][
		append-op 'convert reduce [vreg-operand value] type 'pure 'none none no none
	]

	emit-log-b: func [value [integer!] type [block!]][
		append-op 'log-b reduce [vreg-operand value] type 'pure 'none none yes none
	]

	emit-load-local: func [name [word!] type [block!]][
		append-op 'load-local reduce [local-operand name] type 'read name none no none
	]

	emit-address-local: func [name [word!] type [block!]][
		append-op 'address-local reduce [local-operand name] type 'pure 'none none no none
	]

	emit-store-local: func [name [word!] value [integer!] type [block!]][
		value: coerce-value-type value type
		append-op 'store-local reduce [local-operand name vreg-operand value] none 'write name none no reduce ['value-type copy/deep type]
		poke current fn-last-result value
		poke current fn-last-type copy/deep type
		value
	]

	emit-load-global: func [name [word!] type [block!] /local result][
		result: append-op 'load-global reduce [global-operand name] type 'read 'universal none no none
		add-relocation pick current fn-instruction-count 'rip-rel32 name 0
		result
	]

	emit-symbol-address: func [name [word!] type [block!] /local result][
		result: append-op 'address-symbol reduce [symbol-operand name] type 'pure 'none none no none
		add-relocation pick current fn-instruction-count 'rip-rel32 name 0
		result
	]

	emit-address-global: func [name [word!] type [block!] /local result][
		result: append-op 'address-global reduce [global-operand name] type 'pure 'none none no none
		add-relocation pick current fn-instruction-count 'rip-rel32 name 0
		result
	]

	emit-store-global: func [name [word!] value [integer!] type [block!]][
		value: coerce-value-type value type
		append-op 'store-global reduce [global-operand name vreg-operand value] none 'write 'universal none no reduce ['value-type copy/deep type]
		add-relocation pick current fn-instruction-count 'rip-rel32 name 0
		poke current fn-last-result value
		poke current fn-last-type copy/deep type
		value
	]

	emit-load-indirect: func [base [integer!] offset [integer!] type [block!]][
		append-op
			'load-indirect
			reduce [vreg-operand base immediate-operand offset]
			type
			'read
			'universal
			none
			no
				none
	]

	emit-address-indirect: func [base [integer!] offset [integer!] type [block!]][
		append-op
			'address-indirect
			reduce [vreg-operand base immediate-operand offset]
			type
			'pure
			'none
			none
			no
			none
	]

	emit-load-aggregate-slot: func [
		base [integer!]
		offset [integer!]
		width [integer!]
		/abi-class class [word!]
		/local type value-class
	][
		value-class: either abi-class [class]['integer]
		type: either value-class = 'sse [
			make-type either width <= 4 ['f32]['f64]
				either width <= 4 [4][8]
				'xmm yes 0 'none
		][make-type 'i64 8 'gpr no 0 'none]
		append-op
			'load-aggregate-slot
			reduce [vreg-operand base immediate-operand offset]
			type
			'read
			'universal
			none
			none? find [1 2 4 8] width
			reduce ['width width 'class value-class]
	]

	emit-pack-aggregate: func [
		base [integer!]
		size [integer!]
		/local type
	][
		type: make-type 'ptr 8 'gpr no 1 'none
		append-op
			'pack-aggregate
			reduce [vreg-operand base]
			type
			'write
			'universal
			none
			no
			reduce ['size size]
	]

	emit-aggregate-temp: func [size [integer!] /local type][
		type: make-type 'agg 8 'gpr no size 'none
		append-op
			'aggregate-temp
			copy []
			type
			'pure
			'none
			none
			no
			reduce ['size size]
	]

	emit-typed-list: func [
		values [block!]
		type-ids [block!]
		/local operands value type size
	][
		operands: make block! length? values
		foreach value values [append/only operands vreg-operand value]
		size: max 8 ((length? values) * 24)
		type: make-type 'ptr 8 'gpr no 24 'none
		append-op
			'typed-list
			operands
			type
			'write
			'universal
			none
			no
			reduce [
				'count length? values
				'size size
				'type-ids copy type-ids
			]
	]

	emit-keepalive: func [values [block!] /local operands value][
		operands: make block! length? values
		foreach value values [append/only operands vreg-operand value]
		append-op 'keepalive operands none 'pure 'none none no none
	]

	emit-copy-aggregate: func [
		destination [integer!]
		source [integer!]
		type [block!]
	][
		append-op
			'copy-aggregate
			reduce [vreg-operand destination vreg-operand source]
			type
			'write
			'universal
			none
			no
			reduce ['size type/5]
	]

	emit-store-indirect: func [
		base [integer!]
		offset [integer!]
		value [integer!]
		type [block!]
	][
		value: coerce-value-type value type
		append-op
			'store-indirect
			reduce [vreg-operand base immediate-operand offset vreg-operand value]
			none
			'write
			'universal
			none
			no
			reduce ['value-type copy/deep type]
		poke current fn-last-result value
		poke current fn-last-type copy/deep type
		value
	]

	atomic-metadata: func [
		operation [word!]
		old? [logic!]
		returns? [logic!]
		value-type [block! none!]
	][
		reduce [
			'order 'seq-cst
			'operation operation
			'old? old?
			'returns? returns?
			'value-type either value-type [copy/deep value-type][none]
		]
	]

	emit-atomic-load: func [pointer [integer!] type [block!]][
		append-op
			'atomic-load
			reduce [vreg-operand pointer]
			type
			'atomic
			'universal
			none
			no
			atomic-metadata 'load no yes type
	]

	emit-atomic-store: func [pointer [integer!] value [integer!] type [block!]][
		value: coerce-value-type value type
		append-op
			'atomic-store
			reduce [vreg-operand pointer vreg-operand value]
			none
			'atomic
			'universal
			none
			no
			atomic-metadata 'store no no type
		set-last-result none none
	]

	emit-atomic-math: func [
		operation [word!]
		pointer [integer!]
		value [integer!]
		old? [logic!]
		returns? [logic!]
		type [block!]
		/local result
	][
		value: coerce-value-type value type
		result: append-op
			'atomic-math
			reduce [vreg-operand pointer vreg-operand value]
			either returns? [type][none]
			'atomic
			'universal
			none
			yes
			atomic-metadata operation old? returns? type
		unless returns? [set-last-result none none]
		result
	]

	emit-atomic-cas: func [
		pointer [integer!]
		check [integer!]
		value [integer!]
		returns? [logic!]
		type [block!]
		/local integer-type result
	][
		integer-type: make-type 'i32 4 'gpr yes 0 'none
		check: coerce-value-type check integer-type
		value: coerce-value-type value integer-type
		result: append-op
			'atomic-cas
			reduce [vreg-operand pointer vreg-operand check vreg-operand value]
			either returns? [type][none]
			'atomic
			'universal
			none
			yes
			atomic-metadata 'cas no returns? integer-type
		unless returns? [set-last-result none none]
		result
	]

	emit-atomic-fence: does [
		append-op
			'atomic-fence
			copy []
			none
			'atomic
			'universal
			none
			no
			atomic-metadata 'fence no no none
		set-last-result none none
	]

	emit-binary: func [
		opcode [word!]
		left [integer!]
		right [integer!]
		type [block!]
		effect [word!]
	][
		append-op opcode reduce [vreg-operand left vreg-operand right] type effect
			either effect = 'may-trap ['universal]['none]
			none yes none
	]

	; A source OVERFLOW? body has a lexical, early-exit edge.  Keep the edge
	; explicit in the graph, but defer its slow target until the body is closed.
	; This lets every non-overflow continuation remain the next laid-out block.
	constant-vreg-value: func [id [integer!] /local definition operands opcode seen][
		seen: make block! 4
		while [not find seen id][
			append seen id
			definition: find-vreg-definition id
			unless definition [return none]
			opcode: pick definition ins-opcode
			operands: pick definition ins-operands
			case [
				all [
					opcode = 'const
					(length? operands) = 1
					operands/1/1 = 'imm
					integer? operands/1/2
				][return operands/1/2]
				all [
					opcode = 'copy
					(length? operands) = 1
					operands/1/1 = 'vreg
				][id: operands/1/2]
				true [return none]
			]
		]
		none
	]

	flags-for-vreg: func [id [integer!] /local definition][
		definition: find-vreg-definition id
		all [definition pick definition ins-flags-out]
	]

	begin-overflow: func [/local state][
		unless function-active? [return none]
		ensure-open-block
		state: reduce [make block! 4]
		append/only overflow-control-stack state
		state
	]

	append-deferred-overflow-branch: func [
		state [block!]
		condition [integer!]
		condition-kind [word!]
		flags [integer! none!]
		target-id [integer!]
		continue-id [integer!]
		/local from-id instruction operands
	][
		from-id: current-block-id
		unless all [from-id continue-id][return none]
		instruction: append-op
			'branch
			reduce [
				vreg-operand condition
				block-operand target-id
				block-operand continue-id
			]
			none
			'control
			'none
			flags
			no
			reduce ['condition condition-kind 'overflow-edge yes]
		add-edge from-id continue-id
		seal-current-block
		instruction: last pick pick current fn-current-block bb-instructions
		append/only state/1 reduce [instruction from-id]
		set-current-block continue-id
		set-last-result condition vreg-type condition
		condition
	]

	emit-overflow-branch: func [
		state [block!]
		condition [integer!]
		condition-kind [word!]
		flags [integer! none!]
		/local from-id continue-id
	][
		from-id: current-block-id
		continue-id: either function-active? [
			pick add-block 'overflow-continue bb-id
		][none]
		unless continue-id [return none]
		set-current-block from-id
		append-deferred-overflow-branch
			state condition condition-kind flags 0 continue-id
	]

	emit-overflow-branch-to: func [
		state [block!]
		condition [integer!]
		condition-kind [word!]
		flags [integer! none!]
		target-id [integer!]
	][
		unless all [function-active? target-id][return none]
		append-deferred-overflow-branch
			state condition condition-kind flags target-id target-id
	]

	emit-shift-overflow-guard: func [
		state [block!]
		left [integer!]
		type [block!]
		count [integer!]
		/local logic-type lower upper limit value flags
	][
		unless all [count >= 1 count <= 31][return none]
		logic-type: make-type 'logic 4 'gpr no 0 'none
		if type/4 [
			; For signed 32-bit values, x << n is defined only when the
			; original value lies in [-2^(31-n), 2^(31-n)-1].
			lower: 0 - (shift/left 1 (31 - count))
			upper: (shift/left 1 (31 - count)) - 1
			value: emit-constant lower type
			value: emit-binary less-op left value logic-type 'pure
			flags: flags-for-vreg value
			emit-overflow-branch state value less-op flags
			value: emit-constant upper type
			value: emit-binary greater-op left value logic-type 'pure
			flags: flags-for-vreg value
			emit-overflow-branch state value greater-op flags
		][
			; The direct emitter has separate narrow/unsigned rules.  Do not
			; silently substitute signed OF for those rules while they remain
			; outside the scalar IR type matrix.
			mark-unsupported 'overflow-shift-type
		]
	]

	emit-division-overflow-guard: func [
		state [block!]
		left [integer!]
		right [integer!]
		/local logic-type minimum minus-one not-minimum divisor-bad flags
			from-id normal-id check-id
	][
		logic-type: make-type 'logic 4 'gpr no 0 'none
		minimum: emit-constant -2147483648 make-type 'i32 4 'gpr yes 0 'none
		not-minimum: emit-binary not-equal-op left minimum logic-type 'pure
		from-id: current-block-id
		normal-id: pick add-block 'division-normal bb-id
		check-id: pick add-block 'division-overflow-check bb-id
		set-current-block from-id
		emit-branch not-minimum normal-id check-id
		set-current-block check-id
		minus-one: emit-constant -1 make-type 'i32 4 'gpr yes 0 'none
		divisor-bad: emit-binary equal-op right minus-one logic-type 'pure
		flags: flags-for-vreg divisor-bad
		emit-overflow-branch-to state divisor-bad equal-op flags normal-id
		set-current-block normal-id
	]

	emit-narrow-overflow-range-guard: func [
		state [block!]
		result [integer!]
		type [block!]
		/local wide-type logic-type lower upper limit condition flags
	][
		wide-type: vreg-type result
		logic-type: make-type 'logic 4 'gpr no 0 'none
		upper: either type/2 = 1 [
			either type/4 [127][255]
		][either type/4 [32767][65535]]
		limit: emit-constant upper wide-type
		condition: emit-binary greater-op result limit logic-type 'pure
		flags: flags-for-vreg condition
		emit-overflow-branch state condition greater-op flags
		if type/4 [
			lower: either type/2 = 1 [-128][-32768]
			limit: emit-constant lower wide-type
			condition: emit-binary less-op result limit logic-type 'pure
			flags: flags-for-vreg condition
			emit-overflow-branch state condition less-op flags
		]
	]

	emit-narrow-shift-overflow-guard: func [
		state [block!]
		left [integer!]
		wide-type [block!]
		narrow-type [block!]
		count [integer!]
		/local bits maximum limit value logic-type flags
	][
		bits: narrow-type/2 * 8
		unless all [not narrow-type/4 count >= 1 count <= bits][
			mark-unsupported 'overflow-shift-type
			return none
		]
		maximum: either narrow-type/2 = 1 [255][65535]
		limit: shift/logical maximum count
		value: emit-constant limit wide-type
		logic-type: make-type 'logic 4 'gpr no 0 'none
		value: emit-binary greater-op left value logic-type 'pure
		flags: flags-for-vreg value
		emit-overflow-branch state value greater-op flags
	]

	emit-narrow-source-binary: func [
		opcode [word!]
		left [integer!]
		right [integer!]
		type [block!]
		effect [word!]
		state [block! none!]
		/local left-type right-type wide-type right-wide-type wide-left wide-right
			result count arithmetic? shift? division?
	][
		left-type: vreg-type left
		right-type: vreg-type right
		arithmetic?: any [opcode = add-op opcode = subtract-op opcode = multiply-op]
		shift?: any [
			opcode = left-shift-op
			opcode = right-shift-op
			opcode = unsigned-right-shift-op
		]
		division?: integer-division-op? opcode
		unless all [
			valid-type? left-type
			left-type = type
			valid-type? right-type
			any [right-type = type all [right-type/1 = 'i32 right-type/2 = 4]]
			any [arithmetic? shift? division? find [and or xor] opcode]
		][
			mark-unsupported 'narrow-binary-type
			return emit-binary opcode left right type effect
		]
		wide-type: make-type 'i32 4 'gpr type/4 0 'none
		wide-left: emit-convert left wide-type
		right-wide-type: either right-type/1 = 'i32 [
			right-type
		][make-type 'i32 4 'gpr right-type/4 0 'none]
		wide-right: either right-type/1 = 'i32 [right][emit-convert right right-wide-type]
		if all [division? any [not wide-type/4 not right-wide-type/4]][
			mark-unsupported 'narrow-division-type
		]
		if all [state opcode = left-shift-op][
			count: constant-vreg-value right
			either all [integer? count zero? count][
				; A zero shift cannot overflow.
			][either integer? count [
				emit-narrow-shift-overflow-guard
					state wide-left wide-type type count
			][mark-unsupported 'overflow-shift-type]]
		]
		result: emit-binary opcode wide-left wide-right wide-type effect
		if all [state arithmetic?][
			emit-narrow-overflow-range-guard state result type
		]
		emit-convert result type
	]

	end-overflow: func [state [block!] /local pending normal-id normal-open?
			blocks overflow-block done-block overflow-id done-id item instruction operands
			incoming result logic-type predecessor normal-value overflow-value][
		unless all [function-active? (length? state) = 1][return none]
		unless all [not empty? overflow-control-stack same? state last overflow-control-stack][
			mark-unsupported 'overflow-context-stack
			return none
		]
		remove back tail overflow-control-stack
		pending: state/1
		logic-type: make-type 'logic 4 'gpr no 0 'none
		if empty? pending [
			if all [not current-block-terminated? block-reachable? current-block-id][
				return emit-constant 0 logic-type
			]
			set-last-result none none
			return none
		]

		normal-id: current-block-id
		normal-open?: all [not current-block-terminated? block-reachable? normal-id]
		; These blocks are appended after all normal continuations.  Patch the
		; deferred true edges now that their common slow target is known.
		overflow-block: add-block 'overflow-true
		overflow-id: pick overflow-block bb-id
		done-block: add-block 'overflow-exit
		done-id: pick done-block bb-id
		foreach item pending [
			instruction: item/1
			operands: pick instruction ins-operands
			operands/2/2: overflow-id
			add-edge item/2 overflow-id
		]

		incoming: make block! 4
		if normal-open? [
			set-current-block normal-id
			normal-value: emit-constant 0 logic-type
			predecessor: current-block-id
			append/only incoming reduce [predecessor normal-value copy/deep logic-type]
			emit-jump done-id
		]
		set-current-block overflow-id
		either block-reachable? overflow-id [
			overflow-value: emit-constant 1 logic-type
			predecessor: current-block-id
			append/only incoming reduce [predecessor overflow-value copy/deep logic-type]
			emit-jump done-id
		][
			emit-unreachable
		]
		set-current-block done-id
		either (length? incoming) = 2 [
			emit-phi incoming logic-type
		][either (length? incoming) = 1 [
			item: first incoming
			set-last-result item/2 item/3
		][
			emit-unreachable
			set-last-result none none
		]]
		pick current fn-last-result
	]

	emit-source-binary: func [
		opcode [word!]
		left [integer!]
		right [integer!]
		type [block!]
		effect [word!]
		/local state result flags count left-type right-type
	][
		if type/6 = 'handle [
			type: copy/deep type
			poke type 6 'none
		]
		state: either empty? overflow-control-stack [none][last overflow-control-stack]
		if all [valid-type? type find [i8 i16] type/1][
			return emit-narrow-source-binary opcode left right type effect state
		]
		unless state [return emit-binary opcode left right type effect]
		case [
			any [opcode = add-op opcode = subtract-op opcode = multiply-op][
				result: emit-binary opcode left right type effect
				if all [valid-type? type type/1 = 'i32 type/2 = 4][
					flags: flags-for-vreg result
					either all [flags any [type/4 opcode = multiply-op]][
						emit-overflow-branch state result 'overflow flags
					][either all [flags not type/4 any [opcode = add-op opcode = subtract-op]][
						emit-overflow-branch state result 'carry flags
					][mark-unsupported 'overflow-binary-type]]
					set-last-result result type
				][mark-unsupported 'overflow-binary-type]
				result
			]
			integer-division-op? opcode [
				left-type: vreg-type left
				right-type: vreg-type right
				if all [
					valid-type? type type/1 = 'i32 type/2 = 4 type/4
					valid-type? left-type left-type/1 = 'i32 left-type/2 = 4 left-type/4
					valid-type? right-type right-type/1 = 'i32 right-type/2 = 4 right-type/4
				][
					emit-division-overflow-guard state left right
				][mark-unsupported 'overflow-division-type]
				emit-binary opcode left right type effect
			]
			opcode = left-shift-op [
				count: constant-vreg-value right
				left-type: vreg-type left
				right-type: vreg-type right
				if all [
					integer? count count >= 1 count <= 31
					valid-type? type type/1 = 'i32 type/2 = 4 type/4
					valid-type? left-type left-type/1 = 'i32 left-type/2 = 4 left-type/4
					valid-type? right-type right-type/1 = 'i32 right-type/2 = 4
				][
					emit-shift-overflow-guard state left type count
				][either all [integer? count zero? count][
					; A zero shift cannot overflow and needs no guard.
				][mark-unsupported 'overflow-shift-type]]
				emit-binary opcode left right type effect
			]
			true [emit-binary opcode left right type effect]
		]
	]

	emit-call: func [
		name [word!]
		args [block!]
		type [block! none!]
		/variadic
		/aggregate-result mode [word!] size [integer!] temp [integer! none!]
		/argument-groups groups [block!]
		/result-classes classes [block! none!]
		/local operands value metadata
	][
		operands: make block! (length? args) + 1
		append/only operands symbol-operand name
		foreach value args [append/only operands vreg-operand value]
		metadata: reduce [
			'callee name
			'abi pick current fn-abi
			'clobbers 'abi-default
			'safepoint yes
			'may-throw yes
			'variadic to logic! variadic
			'aggregate-result to logic! aggregate-result
			'aggregate-groups either argument-groups [copy/deep groups][copy []]
			'aggregate-classes either block? classes [copy/deep classes][none]
		]
		if aggregate-result [
			repend metadata [
				'aggregate-mode mode
				'aggregate-size size
				'aggregate-temp temp
			]
		]
		value: append-op 'call operands type 'call 'universal none yes metadata
		add-relocation pick current fn-instruction-count 'call-rel32 name 0
		value
	]

	emit-stack-push: func [value [integer!] /local type][
		type: vreg-type value
		unless valid-type? type [return emit-opaque 'stack-push-type none]
		append-op
			'stack-push
			reduce [vreg-operand value]
			none
			'stack
			'none
			none
			no
			reduce ['value-type copy/deep type 'slots 1]
		none
	]

	emit-stack-pop: func [type [block!] /local result][
		result: append-op
			'stack-pop
			copy []
			type
			'stack
			'none
			none
			no
			reduce ['slots 1]
		result
	]

	emit-custom-call: func [
		target
		indirect? [logic!]
		count [integer! none!]
		count-value [integer!]
		type [block! none!]
		/local operands metadata result instruction-id
	][
		operands: make block! 2
		append/only operands either indirect? [vreg-operand target][symbol-operand target]
		append/only operands vreg-operand count-value
		metadata: reduce [
			'callee either indirect? [none][target]
			'target-kind either indirect? ['indirect]['direct]
			'abi pick current fn-abi
			'clobbers 'abi-default
			'safepoint yes
			'may-throw yes
			'count-kind either integer? count ['static]['dynamic]
			'stack-count count
		]
		result: append-op 'custom-call operands type 'call 'universal none yes metadata
		instruction-id: pick current fn-instruction-count
		unless indirect? [add-relocation instruction-id 'call-rel32 target 0]
		result
	]

	emit-resolver: func [
		name [word!]
		handle [integer!]
		type [block!]
		/local opcode effect result instruction-id
	][
		opcode: case [
			name = 'red>resolve-node ['resolve-node]
			name = 'red>resolve-series ['resolve-series]
			true [none]
		]
		unless opcode [return emit-opaque 'resolver-intrinsic type]
		effect: either opcode = 'resolve-series ['call]['read]
		result: append-op
			opcode
			reduce [symbol-operand name vreg-operand handle]
			type
			effect
			'universal
			none
			yes
			reduce [
				'registry 'red>node-registry
				'slow-call (opcode = 'resolve-series)
				'abi pick current fn-abi
				'clobbers either opcode = 'resolve-series ['abi-default]['none]
				'safepoint (opcode = 'resolve-series)
				'may-throw (opcode = 'resolve-series)
			]
		instruction-id: pick current fn-instruction-count
		add-relocation instruction-id 'rip-rel32 'red>node-registry 0
		if opcode = 'resolve-series [
			add-relocation instruction-id 'call-rel32 name 0
		]
		result
	]

	emit-copy-cell: func [source [integer!] destination [integer!] type [block!]][
		append-op
			'copy-cell
			reduce [
				symbol-operand 'red>copy-cell
				vreg-operand source
				vreg-operand destination
			]
			type
			'write
			'universal
			none
			no
			reduce ['bytes 16 'overlap 'load-before-store 'scratch-class 'xmm]
	]

	emit-phi: func [incoming [block!] type [block!] /local operands item][
		operands: make block! ((length? incoming) * 2)
		foreach item incoming [
			append/only operands block-operand item/1
			append/only operands vreg-operand item/2
		]
		append-op 'phi operands type 'pure 'none none no none
	]

	emit-opaque: func [reason [word!] type [block! none!] /local result][
		mark-unsupported reason
		result: append-op 'opaque reduce [symbol-operand reason] type 'opaque 'universal none yes reduce ['reason reason]
		result
	]

	emit-return: func [value [integer! none!] /local operands expected][
		operands: make block! 1
		if value [
			expected: pick current fn-return-type
			if expected [value: coerce-value-type value expected]
			append/only operands vreg-operand value
		]
		append-op 'return operands none 'control 'none none no none
		seal-current-block
	]

	emit-unreachable: does [
		append-op 'unreachable copy [] none 'control 'none none no none
		seal-current-block
	]

	emit-source-return: func [with-value? [logic!] /local value type expected][
		expected: pick current fn-return-type
		either with-value? [
			value: pick current fn-last-result
			type: pick current fn-last-type
			either all [
				value
				expected
				valid-type? type
				type = expected
			][
				emit-return value
			][
				mark-unsupported 'missing-return-value
				emit-unreachable
			]
		][
			either expected [
				mark-unsupported 'exit-return-value
				emit-unreachable
			][
				emit-return none
			]
		]
	]

	comparison-op?: func [opcode [word!]][
		to logic! any [
			opcode = equal-op
			opcode = not-equal-op
			opcode = less-op
			opcode = greater-op
			opcode = less-or-equal-op
			opcode = greater-or-equal-op
		]
	]

	find-vreg-definition: func [id [integer!] /local block instruction][
		foreach block pick current fn-blocks [
			foreach instruction pick block bb-instructions [
				if (pick instruction ins-result) = id [return instruction]
			]
		]
		none
	]

	find-instruction: func [id [integer!] /local block instruction][
		foreach block pick current fn-blocks [
			foreach instruction pick block bb-instructions [
				if (pick instruction ins-id) = id [return instruction]
			]
		]
		none
	]

	emit-jump: func [target-id [integer!] /local from-id block][
		from-id: current-block-id
		block: pick current fn-current-block
		unless block-terminated? block [
			append-op 'jump reduce [block-operand target-id] none 'control 'none none no none
			add-edge from-id target-id
			seal-current-block
		]
	]

	emit-branch: func [
		condition [integer!]
		true-id [integer!]
		false-id [integer!]
		/local definition opcode flags type from-id
	][
		if current-block-terminated? [return none]
		definition: find-vreg-definition condition
		opcode: all [definition pick definition ins-opcode]
		flags: all [definition pick definition ins-flags-out]
		unless all [opcode comparison-op? opcode flags][
			type: vreg-type condition
			opcode: 'truthy
			flags: none
			unless all [
				valid-type? type
				type/1 = 'logic
				type/2 = 4
				type/3 = 'gpr
			][mark-unsupported 'unsupported-branch-condition]
		]
		from-id: current-block-id
		append-op
			'branch
			reduce [vreg-operand condition block-operand true-id block-operand false-id]
			none
			'control
			'none
			flags
			no
			reduce ['condition any [opcode 'unknown]]
		add-edge from-id true-id
		add-edge from-id false-id
		seal-current-block
	]

	begin-while: func [/local from-id condition body done][
		unless function-active? [return none]
		ensure-open-block
		from-id: current-block-id
		condition: add-block 'while-condition
		body: add-block 'while-body
		done: add-block 'while-exit
		set-current-block from-id
		emit-jump pick condition bb-id
		set-current-block pick condition bb-id
		append/only loop-control-stack reduce ['while pick condition bb-id pick done bb-id none]
		reduce [pick condition bb-id pick body bb-id pick done bb-id]
	]

	while-condition: func [state [block!] /local condition][
		unless all [function-active? (length? state) = 3][return none]
		if current-block-terminated? [
			set-current-block state/2
			set-last-result none none
			return yes
		]
		condition: pick current fn-last-result
		either condition [
			emit-branch condition state/2 state/3
		][
			mark-unsupported 'missing-branch-condition
			emit-jump state/3
		]
		set-current-block state/2
	]

	end-while: func [state [block!]][
		unless all [function-active? (length? state) = 3][return none]
		emit-jump state/1
		set-current-block state/3
		unless empty? loop-control-stack [remove back tail loop-control-stack]
	]

	begin-loop: func [
		counter-name [word! none!]
		/local count type zero condition-value logic-type from-id condition body step done
	][
		unless function-active? [return none]
		unless counter-name [mark-unsupported 'counted-loop-counter return none]
		count: pick current fn-last-result
		type: pick current fn-last-type
		unless all [count valid-type? type type/1 = 'i32 type/2 = 4][
			mark-unsupported 'counted-loop-value
			return none
		]
		emit-store-local counter-name count type
		ensure-open-block
		from-id: current-block-id
		condition: add-block 'loop-condition
		body: add-block 'loop-body
		step: add-block 'loop-step
		done: add-block 'loop-exit
		set-current-block from-id
		emit-jump pick condition bb-id
		set-current-block pick condition bb-id
		count: emit-load-local counter-name type
		zero: emit-constant 0 type
		logic-type: make-type 'logic 4 'gpr no 0 'none
		condition-value: emit-binary greater-op count zero logic-type 'pure
		either condition-value [
			emit-branch condition-value pick body bb-id pick done bb-id
		][
			mark-unsupported 'counted-loop-condition
			emit-jump pick done bb-id
		]
		set-current-block pick body bb-id
		append/only loop-control-stack reduce ['loop pick step bb-id pick done bb-id counter-name]
		reduce [pick condition bb-id pick body bb-id pick step bb-id pick done bb-id]
	]

	end-loop: func [state [block!] /local control counter type value one][
		unless all [function-active? (length? state) = 4][return none]
		unless current-block-terminated? [emit-jump state/3]
		set-current-block state/3
		unless empty? loop-control-stack [control: last loop-control-stack]
		counter: all [control control/4]
		unless word? counter [
			mark-unsupported 'counted-loop-state
			counter: none
		]
		if counter [
			type: make-type 'i32 4 'gpr yes 0 'none
			value: emit-load-local counter type
			one: emit-constant 1 type
			value: emit-binary subtract-op value one type 'pure
			emit-store-local counter value type
			emit-jump state/1
		]
		set-current-block state/4
		unless empty? loop-control-stack [remove back tail loop-control-stack]
	]

	begin-until: func [/local from-id body done][
		unless function-active? [return none]
		ensure-open-block
		from-id: current-block-id
		body: add-block 'until-body
		done: add-block 'until-exit
		set-current-block from-id
		emit-jump pick body bb-id
		set-current-block pick body bb-id
		append/only loop-control-stack reduce ['until pick body bb-id pick done bb-id none]
		reduce [pick body bb-id pick done bb-id]
	]

	end-until: func [state [block!] /local condition type][
		unless all [function-active? (length? state) = 2][return none]
		condition: pick current fn-last-result
		type: pick current fn-last-type
		unless current-block-terminated? [
			either all [condition valid-type? type type/1 = 'logic type/2 = 4][
				emit-branch condition state/2 state/1
			][
				mark-unsupported 'until-condition
				emit-jump state/2
			]
		]
		set-current-block state/2
		unless empty? loop-control-stack [remove back tail loop-control-stack]
	]

	emit-loop-break: func [/local state][
		unless all [function-active? not empty? loop-control-stack][
			mark-unsupported 'break-control
			return none
		]
		state: last loop-control-stack
		emit-jump state/3
	]

	emit-loop-continue: func [/local state][
		unless all [function-active? not empty? loop-control-stack][
			mark-unsupported 'continue-control
			return none
		]
		state: last loop-control-stack
		emit-jump state/2
	]

	begin-if: func [/local condition-id true-block done-block][
		unless function-active? [return none]
		ensure-open-block
		condition-id: current-block-id
		true-block: add-block 'if-true
		done-block: add-block 'if-exit
		set-current-block condition-id
		reduce [condition-id pick true-block bb-id pick done-block bb-id]
	]

	if-condition: func [state [block!] /local condition][
		unless all [function-active? (length? state) = 3][return none]
		if current-block-terminated? [
			set-current-block state/2
			set-last-result none none
			return yes
		]
		condition: pick current fn-last-result
		either condition [
			emit-branch condition state/2 state/3
		][
			mark-unsupported 'missing-branch-condition
			emit-jump state/3
		]
		set-current-block state/2
	]

	end-if: func [state [block!]][
		unless all [function-active? (length? state) = 3][return none]
		emit-jump state/3
		set-current-block state/3
		; Red/System IF is a statement. Do not leak a value defined only on
		; the true edge into a surrounding expression merge.
		set-last-result none none
	]

	begin-either: func [/local condition-id true-block false-block done-block][
		unless function-active? [return none]
		ensure-open-block
		condition-id: current-block-id
		true-block: add-block 'either-true
		false-block: add-block 'either-false
		done-block: add-block 'either-exit
		set-current-block condition-id
		reduce [
			pick true-block bb-id
			pick false-block bb-id
			pick done-block bb-id
			make block! 2
		]
	]

	either-condition: func [state [block!] /local condition][
		unless all [function-active? (length? state) = 4][return none]
		if current-block-terminated? [
			set-current-block state/1
			set-last-result none none
			return yes
		]
		condition: pick current fn-last-result
		either condition [
			emit-branch condition state/1 state/2
		][
			mark-unsupported 'missing-branch-condition
			emit-jump state/2
		]
		set-current-block state/1
		set-last-result none none
		yes
	]

	end-either-true: func [state [block!] /local result type predecessor][
		unless all [function-active? (length? state) = 4][return none]
		unless current-block-terminated? [
			result: pick current fn-last-result
			type: pick current fn-last-type
			predecessor: current-block-id
			append/only state/4 reduce [
				predecessor result either type [copy/deep type][none]
			]
			emit-jump state/3
		]
		set-current-block state/2
		set-last-result none none
	]

	end-either: func [
		state [block!]
		/local result type predecessor incoming item result-type compatible?
	][
		unless all [function-active? (length? state) = 4][return none]
		unless current-block-terminated? [
			result: pick current fn-last-result
			type: pick current fn-last-type
			predecessor: current-block-id
			append/only state/4 reduce [
				predecessor result either type [copy/deep type][none]
			]
			emit-jump state/3
		]
		set-current-block state/3
		incoming: state/4
		result-type: none
		compatible?: not empty? incoming
		foreach item incoming [
			unless all [item/2 valid-type? item/3][compatible?: no]
			if all [compatible? none? result-type][result-type: copy/deep item/3]
			if all [compatible? result-type result-type <> item/3][compatible?: no]
		]
		either all [compatible? result-type][
			emit-phi incoming result-type
		][
			set-last-result none none
			none
		]
	]

	constant-true-vreg?: func [id [integer! none!] /local definition operands value][
		unless id [return no]
		definition: find-vreg-definition id
		unless all [definition (pick definition ins-opcode) = 'const][return no]
		operands: pick definition ins-operands
		unless all [(length? operands) = 1 operands/1/1 = 'imm][return no]
		value: operands/1/2
		to logic! all [integer? :value not zero? value]
	]

	begin-case: func [/local from-id done][
		unless function-active? [return none]
		ensure-open-block
		from-id: current-block-id
		done: add-block 'case-exit
		set-current-block from-id
		reduce [pick done bb-id make block! 4 no]
	]

	case-condition: func [
		state [block!]
		/local condition type from-id body next-condition
	][
		unless all [function-active? (length? state) = 3][return none]
		condition: pick current fn-last-result
		type: pick current fn-last-type
		poke state 3 to logic! all [
			condition
			valid-type? type
			type/1 = 'logic
			type/2 = 4
			constant-true-vreg? condition
		]
		from-id: current-block-id
		body: add-block 'case-body
		next-condition: add-block 'case-next
		set-current-block from-id
		unless current-block-terminated? [
			either all [condition valid-type? type type/1 = 'logic type/2 = 4][
				emit-branch condition pick body bb-id pick next-condition bb-id
			][
				mark-unsupported 'case-condition
				emit-jump pick next-condition bb-id
			]
		]
		set-current-block pick body bb-id
		set-last-result none none
		reduce [pick body bb-id pick next-condition bb-id]
	]

	end-case-body: func [
		state [block!]
		arm [block!]
		/local result type predecessor
	][
		unless all [
			function-active?
			(length? state) = 3
			(length? arm) = 2
		][return none]
		unless current-block-terminated? [
			result: pick current fn-last-result
			type: pick current fn-last-type
			predecessor: current-block-id
			append/only state/2 reduce [
				predecessor result either type [copy/deep type][none]
			]
			emit-jump state/1
		]
		set-current-block arm/2
		set-last-result none none
	]

	end-case: func [
		state [block!]
		/local incoming item result-type compatible?
	][
		unless all [function-active? (length? state) = 3][return none]
		unless state/3 [mark-unsupported 'case-without-catch-all]
		unless current-block-terminated? [emit-unreachable]
		set-current-block state/1
		incoming: state/2
		result-type: none
		compatible?: not empty? incoming
		foreach item incoming [
			unless all [item/2 valid-type? item/3][compatible?: no]
			if all [compatible? none? result-type][result-type: copy/deep item/3]
			if all [compatible? result-type result-type <> item/3][compatible?: no]
		]
		either all [compatible? result-type][
			emit-phi incoming result-type
		][
			set-last-result none none
			none
		]
	]

	begin-short-circuit: func [
		all? [logic!]
		/local start-id true-block false-block done-block
	][
		unless function-active? [return none]
		ensure-open-block
		start-id: current-block-id
		true-block: add-block 'short-circuit-true
		false-block: add-block 'short-circuit-false
		done-block: add-block 'short-circuit-exit
		set-current-block start-id
		reduce [
			all?
			pick true-block bb-id
			pick false-block bb-id
			pick done-block bb-id
		]
	]

	short-circuit-condition: func [
		state [block!]
		last? [logic!]
		/local condition type current-id next-block next-id true-id false-id
	][
		unless all [function-active? (length? state) = 4][return none]
		if current-block-terminated? [
			unless last? [add-block 'short-circuit-next]
			set-last-result none none
			return yes
		]
		condition: pick current fn-last-result
		type: pick current fn-last-type
		unless all [
			condition
			valid-type? type
			type/1 = 'logic
			type/2 = 4
		][
			mark-unsupported 'short-circuit-condition
			return none
		]
		next-id: none
		unless last? [
			current-id: current-block-id
			next-block: add-block 'short-circuit-next
			next-id: pick next-block bb-id
			set-current-block current-id
		]
		either state/1 [
			true-id: any [next-id state/2]
			false-id: state/3
		][
			true-id: state/2
			false-id: any [next-id state/3]
		]
		emit-branch condition true-id false-id
		if next-id [
			set-current-block next-id
			set-last-result none none
		]
		yes
	]

	end-short-circuit: func [
		state [block!]
		/local type true-value true-predecessor false-value false-predecessor incoming
	][
		unless all [function-active? (length? state) = 4][return none]
		type: make-type 'logic 4 'gpr no 0 'none
		set-current-block state/2
		true-value: emit-constant 1 type
		true-predecessor: current-block-id
		emit-jump state/4
		set-current-block state/3
		false-value: emit-constant 0 type
		false-predecessor: current-block-id
		emit-jump state/4
		set-current-block state/4
		incoming: reduce [
			reduce [true-predecessor true-value type]
			reduce [false-predecessor false-value type]
		]
		emit-phi incoming type
	]

	begin-switch: func [
		case-groups [block!]
		explicit-default? [logic!]
		/local selector selector-type seen values value case-ids block default-block done-block
			operands index from-id terminated?
	][
		unless function-active? [return none]
		if positive? switch-depth [
			mark-unsupported 'nested-switch
			return none
		]
		unless explicit-default? [
			mark-unsupported 'switch-without-default
			return none
		]
		terminated?: current-block-terminated?
		unless terminated? [
			selector: pick current fn-last-result
			selector-type: pick current fn-last-type
			unless all [
				selector
				valid-type? selector-type
				selector-type/1 = 'i32
				selector-type/2 = 4
			][
				mark-unsupported 'switch-selector-type
				return none
			]
		]
		seen: make block! 16
		foreach values case-groups [
			foreach value values [
				value: to integer! value
				if find seen value [
					mark-unsupported 'duplicate-switch-value
					return none
				]
				append seen value
			]
		]

		from-id: current-block-id
		case-ids: make block! length? case-groups
		foreach values case-groups [
			block: add-block 'switch-case
			append case-ids pick block bb-id
		]
		default-block: add-block 'switch-default
		done-block: add-block 'switch-exit
		set-current-block from-id

		unless terminated? [
			operands: make block! (((length? seen) * 2) + 2)
			append/only operands vreg-operand selector
			index: 0
			foreach values case-groups [
				index: index + 1
				foreach value values [
					append/only operands immediate-operand to integer! value
					append/only operands block-operand pick case-ids index
				]
			]
			append/only operands block-operand pick default-block bb-id
			append-op 'switch operands none 'control 'none none no reduce ['signed yes]
			foreach index case-ids [add-edge from-id index]
			add-edge from-id pick default-block bb-id
			seal-current-block
		]
		switch-depth: switch-depth + 1
		reduce [
			case-ids
			pick default-block bb-id
			pick done-block bb-id
			make block! ((length? case-ids) + 1)
			1
		]
	]

	begin-switch-case: func [state [block!] /local index][
		unless all [function-active? (length? state) = 5][return none]
		index: state/5
		unless all [index >= 1 index <= length? state/1][
			mark-unsupported 'switch-case-index
			return none
		]
		set-current-block pick state/1 index
		set-last-result none none
	]

	end-switch-case: func [state [block!] /local result type predecessor][
		unless all [function-active? (length? state) = 5][return none]
		unless current-block-terminated? [
			result: pick current fn-last-result
			type: pick current fn-last-type
			predecessor: current-block-id
			append/only state/4 reduce [predecessor result either type [copy/deep type][none]]
			emit-jump state/3
		]
		poke state 5 (state/5 + 1)
	]

	begin-switch-default: func [state [block!]][
		unless all [function-active? (length? state) = 5][return none]
		set-current-block state/2
		set-last-result none none
	]

	end-switch-default: func [state [block!] /local result type predecessor][
		unless all [function-active? (length? state) = 5][return none]
		unless current-block-terminated? [
			result: pick current fn-last-result
			type: pick current fn-last-type
			predecessor: current-block-id
			append/only state/4 reduce [predecessor result either type [copy/deep type][none]]
			emit-jump state/3
		]
	]

	end-switch: func [state [block!] /local incoming item result-type compatible? result][
		unless all [function-active? (length? state) = 5][return none]
		set-current-block state/3
		incoming: state/4
		result-type: none
		compatible?: not empty? incoming
		foreach item incoming [
			unless all [item/2 valid-type? item/3][compatible?: no]
			if all [compatible? none? result-type][result-type: copy/deep item/3]
			if all [compatible? result-type result-type <> item/3][compatible?: no]
		]
		result: either all [compatible? result-type][
			emit-phi incoming result-type
		][
			set-last-result none none
			none
		]
		switch-depth: max 0 (switch-depth - 1)
		result
	]

	find-stack-object: func [name [word!] /local stack-entry][
		foreach stack-entry pick current fn-stack-objects [
			if (pick stack-entry stack-name) = name [return stack-entry]
		]
		none
	]

	add-stack-object: func [
		name [word!]
		kind [word!]
		type [block!]
		size [integer!]
		align [integer!]
		gc-kind [word!]
		/local objects stack-entry id
	][
		unless function-active? [return none]
		objects: pick current fn-stack-objects
		if stack-entry: find-stack-object name [return pick stack-entry stack-id]
		id: (length? objects) + 1
		append/only objects reduce [id name kind copy/deep type size align gc-kind no none]
		id
	]

	ensure-stack-object: func [
		name [word!]
		kind [word!]
		type [block!]
		size [integer!]
		align [integer!]
		gc-kind [word!]
		offset [integer! none!]
		/local stack-entry id
	][
		stack-entry: find-stack-object name
		either stack-entry [
			if all [none? pick stack-entry stack-frame-offset integer? offset][
				poke stack-entry stack-frame-offset offset
			]
			pick stack-entry stack-id
		][
			id: add-stack-object name kind type size align gc-kind
			if integer? offset [set-stack-offset name offset]
			id
		]
	]

	set-stack-offset: func [name [word!] offset [integer! none!] /local object][
		foreach object pick current fn-stack-objects [
			if (pick object stack-name) = name [
				poke object stack-frame-offset offset
				return yes
			]
		]
		no
	]

	set-stack-offsets: func [offsets [block!] /local pos name offset][
		pos: offsets
		while [not tail? pos][
			name: pos/1
			offset: pos/2
			if all [word? name integer? offset][set-stack-offset name offset]
			pos: skip pos 2
		]
	]

	set-direct-body-range: func [start [integer!] ending [integer!]][
		if function-active? [
			poke current fn-body-start start
			poke current fn-body-end ending
		]
	]

	set-frame-bitmap-offset: func [offset [integer! none!]][
		if function-active? [poke current fn-frame-bitmap-offset offset]
	]

	mark-stack-object-escaped: func [name [word!] /local object][
		foreach object pick current fn-stack-objects [
			if (pick object stack-name) = name [
				poke object stack-escaped? yes
				return yes
			]
		]
		no
	]

	add-relocation: func [
		instruction-id [integer!]
		kind [word!]
		symbol [word!]
		addend [integer!]
		/local relocations
	][
		relocations: pick current fn-relocations
		append/only relocations reduce [
			instruction-id kind symbol addend (length? relocations) + 1
		]
	]

	add-safepoint: func [instruction-id [integer!] roots [block!]][
		append/only pick current fn-safepoints reduce [instruction-id copy/deep roots]
	]

	table-value: func [table [block!] key /local pos][
		all [pos: find/skip table :key 2 pos/2]
	]

	set-table-value: func [table [block!] key value /local pos][
		either pos: find/skip table :key 2 [
			pos/2: :value
		][
			repend table [:key :value]
		]
		:value
	]

	vreg-type: func [id [integer!]][select/skip pick current fn-vreg-types id 2]

	flags-used?: func [id [integer! none!] /local block instruction][
		unless id [return no]
		foreach block pick current fn-blocks [
			foreach instruction pick block bb-instructions [
				if (pick instruction ins-flags-in) = id [return yes]
			]
		]
		no
	]

	stack-object-escaped?: func [name [word!] /local object][
		foreach object pick current fn-stack-objects [
			if (pick object stack-name) = name [return pick object stack-escaped?]
		]
		yes
	]

	remove-instruction-relocations: func [instruction-id [integer!] /local relocations kept reloc][
		relocations: pick current fn-relocations
		kept: make block! length? relocations
		foreach reloc relocations [
			unless reloc/1 = instruction-id [append/only kept reloc]
		]
		poke current fn-relocations kept
	]

	make-copy-instruction: func [instruction [block!] source [integer!]][
		remove-instruction-relocations pick instruction ins-id
		poke instruction ins-opcode 'copy
		poke instruction ins-operands reduce [vreg-operand source]
		poke instruction ins-effect 'pure
		poke instruction ins-alias 'none
		poke instruction ins-memory-in copy []
		poke instruction ins-memory-out copy []
		poke instruction ins-flags-in none
		poke instruction ins-flags-out none
		poke instruction ins-metadata copy []
	]

	make-constant-instruction: func [instruction [block!] value][
		remove-instruction-relocations pick instruction ins-id
		poke instruction ins-opcode 'const
		poke instruction ins-operands reduce [immediate-operand :value]
		poke instruction ins-effect 'pure
		poke instruction ins-alias 'none
		poke instruction ins-memory-in copy []
		poke instruction ins-memory-out copy []
		poke instruction ins-flags-in none
		poke instruction ins-flags-out none
		poke instruction ins-metadata copy []
	]

	pass-store-to-load: func [/local block instruction opcode values name source effect alias][
		foreach block pick current fn-blocks [
			values: make block! 16
			foreach instruction pick block bb-instructions [
				opcode: pick instruction ins-opcode
				effect: pick instruction ins-effect
				alias: pick instruction ins-alias
				case [
					opcode = 'store-local [
						name: pick instruction ins-operands
						name: name/1/2
						source: pick instruction ins-operands
						source: source/2/2
						set-table-value values name source
					]
					opcode = 'load-local [
						name: pick instruction ins-operands
						name: name/1/2
						source: table-value values name
						if all [source not stack-object-escaped? name][
							make-copy-instruction instruction source
						]
					]
					any [
						find [call opaque volatile atomic safepoint throw stack] effect
						all [effect = 'write alias = 'universal]
					][clear values]
					true []
				]
			]
		]
	]

	resolve-copy: func [copies [block!] id [integer!] /local mapped seen][
		seen: make block! 4
		while [mapped: table-value copies id][
			if any [mapped = id find seen mapped][return id]
			append seen id
			id: mapped
		]
		id
	]

	pass-copy-propagation: func [/local block instruction operand copies source result][
		foreach block pick current fn-blocks [
			copies: make block! 16
			foreach instruction pick block bb-instructions [
				foreach operand pick instruction ins-operands [
					if all [block? operand operand/1 = 'vreg][
						operand/2: resolve-copy copies operand/2
					]
				]
				if all [
					(pick instruction ins-opcode) = 'copy
					result: pick instruction ins-result
				][
					source: pick instruction ins-operands
					if all [not empty? source source/1/1 = 'vreg][
						set-table-value copies result source/1/2
					]
				]
			]
		]
	]

	normalize-integer: func [value width [integer!] signed? [logic!] /local modulus result sign-bit][
		unless integer? :value [return none]
		if width = 4 [return value]
		if width = 1 [modulus: 256]
		if width = 2 [modulus: 65536]
		unless modulus [return value]
		result: value // modulus
		if negative? result [result: result + modulus]
		if signed? [
			sign-bit: modulus / 2
			if result >= sign-bit [result: result - modulus]
		]
		result
	]

	checked-integer-binary: func [
		opcode [word!]
		left [integer!]
		right [integer!]
		/local result
	][
		result: case [
			opcode = add-op [left + right]
			opcode = subtract-op [left - right]
			opcode = multiply-op [left * right]
			opcode = 'and [left and right]
			opcode = 'or [left or right]
			opcode = 'xor [left xor right]
			true [return none]
		]
		either integer? :result [:result][none]
	]

	fold-binary: func [
		opcode [word!]
		left [integer!]
		right [integer!]
		operand-type [block!]
		/local result comparison
	][
		unless find [i8 i16 i32 logic] operand-type/1 [return none]
		left: normalize-integer left operand-type/2 operand-type/4
		right: normalize-integer right operand-type/2 operand-type/4
		case [
			any [
				opcode = add-op
				opcode = subtract-op
				opcode = multiply-op
				opcode = 'and
				opcode = 'or
				opcode = 'xor
			][
				result: checked-integer-binary opcode left right
				unless integer? :result [return none]
			]
			opcode = to word! "=" [comparison: left = right return reduce [yes either comparison [1][0]]]
			opcode = to word! "<>" [comparison: left <> right return reduce [yes either comparison [1][0]]]
			opcode = to word! "<" [comparison: left < right return reduce [yes either comparison [1][0]]]
			opcode = to word! ">" [comparison: left > right return reduce [yes either comparison [1][0]]]
			opcode = to word! "<=" [comparison: left <= right return reduce [yes either comparison [1][0]]]
			opcode = to word! ">=" [comparison: left >= right return reduce [yes either comparison [1][0]]]
			true [return none]
		]
		reduce [yes normalize-integer result operand-type/2 operand-type/4]
	]

	simplify-binary: func [
		instruction [block!]
		opcode [word!]
		left
		right
		/local operands
	][
		operands: pick instruction ins-operands
		case [
			all [
			not none? right
			right = 0
				any [opcode = add-op opcode = subtract-op opcode = 'or opcode = 'xor]
			][make-copy-instruction instruction operands/1/2 yes]
			all [
				not none? left
				left = 0
				any [opcode = add-op opcode = 'or opcode = 'xor]
			][make-copy-instruction instruction operands/2/2 yes]
			all [not none? right right = 1 opcode = multiply-op][
				make-copy-instruction instruction operands/1/2
				yes
			]
			all [not none? left left = 1 opcode = multiply-op][
				make-copy-instruction instruction operands/2/2
				yes
			]
			all [
				any [all [not none? left left = 0] all [not none? right right = 0]]
				any [opcode = multiply-op opcode = 'and]
			][make-constant-instruction instruction 0 yes]
			all [not none? right right = -1 opcode = 'and][
				make-copy-instruction instruction operands/1/2
				yes
			]
			true [no]
		]
	]

	pass-constant-folding: func [
		/local block instruction opcode operands result constants left right folded operand-type source
	][
		foreach block pick current fn-blocks [
			constants: make block! 16
			foreach instruction pick block bb-instructions [
				opcode: pick instruction ins-opcode
				result: pick instruction ins-result
				operands: pick instruction ins-operands
				case [
					all [opcode = 'const result not empty? operands operands/1/1 = 'imm] [
						if integer? operands/1/2 [set-table-value constants result operands/1/2]
					]
					all [opcode = 'copy result not empty? operands operands/1/1 = 'vreg] [
						source: table-value constants operands/1/2
						if not none? source [
							make-constant-instruction instruction source
							set-table-value constants result source
						]
					]
					all [
						result
						(length? operands) = 2
						operands/1/1 = 'vreg
						operands/2/1 = 'vreg
						not flags-used? pick instruction ins-flags-out
					][
						left: table-value constants operands/1/2
						right: table-value constants operands/2/2
						folded: none
						if all [not none? left not none? right][
							operand-type: vreg-type operands/1/2
							folded: all [operand-type fold-binary opcode left right operand-type]
						]
						either folded [
							make-constant-instruction instruction folded/2
							set-table-value constants result folded/2
						][
							if simplify-binary instruction opcode left right [
								operands: pick instruction ins-operands
								either (pick instruction ins-opcode) = 'const [
									set-table-value constants result operands/1/2
								][
									source: operands/1/2
									left: table-value constants source
									if not none? left [set-table-value constants result left]
								]
							]
						]
					]
					true []
				]
			]
		]
	]

	rewrite-branch-as-jump: func [
		block [block!]
		instruction [block!]
		target [integer!]
		/local id successor other found
	][
		id: pick block bb-id
		foreach successor copy pick block bb-successors [
			if successor <> target [
				other: pick pick current fn-blocks successor
				if found: find pick other bb-predecessors id [remove found]
			]
		]
		poke block bb-successors reduce [target]
		poke instruction ins-opcode 'jump
		poke instruction ins-operands reduce [block-operand target]
		poke instruction ins-flags-in none
		poke instruction ins-metadata copy []
	]

	pass-branch-folding: func [
		/local block instruction operands true-id false-id condition definition opcode
			left-definition right-definition left right type folded target value
	][
		foreach block pick current fn-blocks [
			instruction: last pick block bb-instructions
			if (pick instruction ins-opcode) = 'branch [
				operands: pick instruction ins-operands
				true-id: operands/2/2
				false-id: operands/3/2
				target: none
				either true-id = false-id [
					target: true-id
				][
					condition: operands/1/2
					definition: find-vreg-definition condition
					opcode: all [definition pick definition ins-opcode]
					case [
						all [definition opcode = 'const][
							value: pick definition ins-operands
							value: value/1/2
							if integer? value [target: either zero? value [false-id][true-id]]
						]
						all [definition comparison-op? opcode][
							operands: pick definition ins-operands
							left-definition: find-vreg-definition operands/1/2
							right-definition: find-vreg-definition operands/2/2
							if all [
								left-definition
								right-definition
								(pick left-definition ins-opcode) = 'const
								(pick right-definition ins-opcode) = 'const
							][
								left: pick left-definition ins-operands
								right: pick right-definition ins-operands
								left: left/1/2
								right: right/1/2
								type: vreg-type operands/1/2
								folded: fold-binary opcode left right type
								if folded [target: either zero? folded/2 [false-id][true-id]]
							]
						]
					]
				]
				if target [rewrite-branch-as-jump block instruction target]
			]
		]
	]

	pass-unreachable-blocks: func [
		/local blocks reachable position id block successor mapping kept new-id
			predecessors successors mapped instruction operand opcode operands repaired
	][
		blocks: pick current fn-blocks
		reachable: make block! length? blocks
		append reachable 1
		position: reachable
		while [not tail? position][
			id: position/1
			block: pick blocks id
			foreach successor pick block bb-successors [
				unless find reachable successor [append reachable successor]
			]
			position: next position
		]
		if (length? reachable) = length? blocks [exit]
		mapping: make block! (length? reachable) * 2
		kept: make block! length? reachable
		new-id: 0
		foreach block blocks [
			id: pick block bb-id
			if find reachable id [
				new-id: new-id + 1
				set-table-value mapping id new-id
				append/only kept block
			]
		]
		foreach block kept [
			id: pick block bb-id
			poke block bb-id table-value mapping id
			predecessors: make block! 4
			foreach id pick block bb-predecessors [
				mapped: table-value mapping id
				if mapped [append predecessors mapped]
			]
			poke block bb-predecessors predecessors
			successors: make block! 4
			foreach id pick block bb-successors [
				mapped: table-value mapping id
				if mapped [append successors mapped]
			]
			poke block bb-successors successors
			foreach instruction pick block bb-instructions [
				opcode: pick instruction ins-opcode
				operands: pick instruction ins-operands
				either opcode = 'phi [
					repaired: make block! length? operands
					position: operands
					while [not tail? position][
						mapped: table-value mapping position/1/2
						if mapped [
							append/only repaired block-operand mapped
							append/only repaired copy position/2
						]
						position: skip position 2
					]
					poke instruction ins-operands repaired
				][
					foreach operand operands [
						if operand/1 = 'block [operand/2: table-value mapping operand/2]
					]
				]
			]
		]
		poke current fn-blocks kept
		poke current fn-current-block last kept
	]

	commutative-op?: func [opcode [word!]][
		any [
			opcode = add-op
			opcode = multiply-op
			opcode = 'and
			opcode = 'or
			opcode = 'xor
			opcode = to word! "="
			opcode = to word! "<>"
		]
	]

	pass-local-value-numbering: func [
		/local block instruction table opcode result operands key existing first-id second-id normalized
			effect
	][
		foreach block pick current fn-blocks [
			table: make block! 16
			foreach instruction pick block bb-instructions [
				opcode: pick instruction ins-opcode
				result: pick instruction ins-result
				operands: pick instruction ins-operands
				effect: pick instruction ins-effect
				if all [
					result
					any [
						effect = 'pure
						all [
							effect = 'read
							opcode = 'load-local
							not (stack-object-escaped? operands/1/2)
						]
					]
					opcode <> 'copy
					not flags-used? pick instruction ins-flags-out
				][
					normalized: copy/deep operands
					if all [
						commutative-op? opcode
						(length? normalized) = 2
						normalized/1/1 = 'vreg
						normalized/2/1 = 'vreg
					][
						first-id: normalized/1/2
						second-id: normalized/2/2
						if first-id > second-id [
							normalized/1/2: second-id
							normalized/2/2: first-id
						]
					]
					key: mold/flat reduce [
						opcode
						normalized
						pick instruction ins-type
						pick instruction ins-memory-in
					]
					existing: table-value table key
					either existing [
						make-copy-instruction instruction existing
					][set-table-value table key result]
				]
			]
		]
	]

	pass-dead-local-stores: func [
		/local block instructions position instruction kept needed opcode operands name found
			effect alias stack-entry
	][
		foreach block pick current fn-blocks [
			instructions: pick block bb-instructions
			position: tail instructions
			kept: make block! length? instructions
			needed: make block! 8
			while [not head? position][
				position: back position
				instruction: position/1
				opcode: pick instruction ins-opcode
				operands: pick instruction ins-operands
				effect: pick instruction ins-effect
				alias: pick instruction ins-alias
				case [
					opcode = 'load-local [
						name: operands/1/2
						unless find needed name [append needed name]
						insert/only kept instruction
					]
					opcode = 'store-local [
						name: operands/1/2
						found: find needed name
						either any [stack-object-escaped? name found][
							if found [remove found]
							insert/only kept instruction
						][]
					]
					any [
						find [call opaque volatile atomic safepoint throw] effect
						alias = 'universal
					][
						foreach stack-entry pick current fn-stack-objects [
							unless pick stack-entry stack-escaped? [
								name: pick stack-entry stack-name
								unless find needed name [append needed name]
							]
						]
						insert/only kept instruction
					]
					true [insert/only kept instruction]
				]
			]
			poke block bb-instructions kept
		]
	]

	pass-dead-code-elimination: func [
		/local block block-id instructions position instruction kept live result effect keep?
			operand found definitions cross-live definition-block
	][
		definitions: make block! 16
		cross-live: make block! 8
		foreach block pick current fn-blocks [
			block-id: pick block bb-id
			foreach instruction pick block bb-instructions [
				result: pick instruction ins-result
				if result [set-table-value definitions result block-id]
			]
		]
		foreach block pick current fn-blocks [
			block-id: pick block bb-id
			foreach instruction pick block bb-instructions [
				foreach operand pick instruction ins-operands [
					if operand/1 = 'vreg [
						definition-block: table-value definitions operand/2
						if all [definition-block definition-block <> block-id][
							live: table-value cross-live definition-block
							unless live [
								live: make block! 4
								set-table-value cross-live definition-block live
							]
							unless find live operand/2 [append live operand/2]
						]
					]
				]
			]
		]
		foreach block pick current fn-blocks [
			instructions: pick block bb-instructions
			position: tail instructions
			kept: make block! length? instructions
			live: table-value cross-live pick block bb-id
			live: either live [copy live][make block! 16]
			while [not head? position][
				position: back position
				instruction: position/1
				result: pick instruction ins-result
				effect: pick instruction ins-effect
				keep?: any [
					effect <> 'pure
					none? result
					to logic! find live result
					flags-used? pick instruction ins-flags-out
				]
				if keep? [
					if all [result found: find live result][remove found]
					foreach operand pick instruction ins-operands [
						if all [operand/1 = 'vreg not find live operand/2][append live operand/2]
					]
					insert/only kept instruction
				]
			]
			poke block bb-instructions kept
		]
	]

	renumber-current: func [
		/local block instruction id old-id id-map flag flag-map input output reloc safepoint mapped
			relocations safepoints
	][
		id: 0
		id-map: make block! 16
		flag: 0
		flag-map: make block! 8
		foreach block pick current fn-blocks [
			foreach instruction pick block bb-instructions [
				old-id: pick instruction ins-id
				id: id + 1
				set-table-value id-map old-id id
				poke instruction ins-id id
				output: pick instruction ins-flags-out
				if output [
					flag: flag + 1
					set-table-value flag-map output flag
					poke instruction ins-flags-out flag
				]
			]
		]
		foreach block pick current fn-blocks [
			foreach instruction pick block bb-instructions [
				input: pick instruction ins-flags-in
				if input [
					mapped: table-value flag-map input
					poke instruction ins-flags-in any [mapped 0]
				]
			]
		]
		relocations: make block! length? pick current fn-relocations
		foreach reloc pick current fn-relocations [
			mapped: table-value id-map reloc/1
			if mapped [
				reloc/1: mapped
				append/only relocations reloc
			]
		]
		poke current fn-relocations relocations
		safepoints: make block! length? pick current fn-safepoints
		foreach safepoint pick current fn-safepoints [
			mapped: table-value id-map safepoint/1
			if mapped [
				safepoint/1: mapped
				append/only safepoints safepoint
			]
		]
		poke current fn-safepoints safepoints
		poke current fn-instruction-count id
		poke current fn-flag-count flag
		poke current fn-last-flags either zero? flag [none][flag]
	]

	record-pass: func [name [word!] before [integer!] after [integer!]][
		repend pick current fn-pass-log [name before after]
	]

	run-pass: func [name [word!] body [block!] /local before after phase verified?][
		phase: none
		if phase-timer/active? [
			phase: rejoin ["o2-pass-" form name]
			phase-timer/begin phase
		]
		before: pick current fn-instruction-count
		phase-timer/begin 'o2-pass-body
		do body
		phase-timer/finish 'o2-pass-body
		phase-timer/begin 'o2-pass-memory-dependencies
		rebuild-current-memory-dependencies
		phase-timer/finish 'o2-pass-memory-dependencies
		phase-timer/begin 'o2-pass-renumber
		renumber-current
		phase-timer/finish 'o2-pass-renumber
		phase-timer/begin 'o2-pass-stack-dependencies
		rebuild-current-stack-dependencies
		phase-timer/finish 'o2-pass-stack-dependencies
		after: pick current fn-instruction-count
		record-pass name before after
		phase-timer/begin 'o2-pass-verify
		verified?: verify-current
		phase-timer/finish 'o2-pass-verify
		if phase [phase-timer/finish phase]
		verified?
	]

	optimize-current: does [
		unless run-pass 'store-forward [pass-store-to-load] [return no]
		unless run-pass 'copy-propagation [pass-copy-propagation] [return no]
		unless run-pass 'constant-folding [pass-constant-folding] [return no]
		unless run-pass 'branch-folding [pass-branch-folding] [return no]
		unless run-pass 'unreachable-blocks [pass-unreachable-blocks] [return no]
		unless run-pass 'local-value-numbering [pass-local-value-numbering] [return no]
		unless run-pass 'copy-propagation-2 [pass-copy-propagation] [return no]
		if (length? pick current fn-blocks) = 1 [
			unless run-pass 'dead-local-stores [pass-dead-local-stores] [return no]
		]
		unless run-pass 'dead-code-elimination [pass-dead-code-elimination] [return no]
		yes
	]

	verifier-error: func [errors [block!] message [string!]][append errors message]

	verify-memory-state: func [state next-version [integer!] /local pos][
		unless block? state [return no]
		if odd? length? state [return no]
		pos: state
		while [not tail? pos][
			unless all [word? pos/1 integer? pos/2 pos/2 >= 0 pos/2 <= next-version][return no]
			pos: skip pos 2
		]
		yes
	]

	valid-call-metadata?: func [
		instruction [block!]
		/local operands metadata callee abi clobbers safepoint? may-throw?
			variadic? aggregate-result? groups classes mode size temp result type
	][
		operands: pick instruction ins-operands
		metadata: pick instruction ins-metadata
		unless all [
			block? operands
			not empty? operands
			block? operands/1
			operands/1/1 = 'symbol
			word? operands/1/2
			block? metadata
			even? length? metadata
			find metadata 'callee
			find metadata 'abi
			find metadata 'clobbers
			find metadata 'safepoint
			find metadata 'may-throw
			find metadata 'variadic
			find metadata 'aggregate-result
			find metadata 'aggregate-groups
			find metadata 'aggregate-classes
			(pick instruction ins-effect) = 'call
			(pick instruction ins-alias) = 'universal
			none? pick instruction ins-flags-in
			integer? pick instruction ins-flags-out
		][return no]
		callee: select metadata 'callee
		abi: select metadata 'abi
		clobbers: select metadata 'clobbers
		safepoint?: select metadata 'safepoint
		may-throw?: select metadata 'may-throw
		variadic?: select metadata 'variadic
		aggregate-result?: select metadata 'aggregate-result
		groups: select metadata 'aggregate-groups
		classes: select metadata 'aggregate-classes
		unless all [
			word? callee
			callee = operands/1/2
			word? abi
			abi = pick current fn-abi
			clobbers = 'abi-default
			logic? safepoint?
			logic? may-throw?
			logic? variadic?
			logic? aggregate-result?
			block? groups
			any [none? classes block? classes]
		][return no]
		foreach operand next operands [
			unless all [block? operand operand/1 = 'vreg integer? operand/2][return no]
		]
		result: pick instruction ins-result
		type: pick instruction ins-type
		either aggregate-result? [
			mode: select metadata 'aggregate-mode
			size: select metadata 'aggregate-size
			temp: select metadata 'aggregate-temp
			unless all [
				result
				valid-type? type
				type/1 = 'agg
				integer? size
				size > 0
				type/5 = size
				find [register hidden sysv-register] mode
				either mode = 'hidden [integer? temp][none? temp]
			][return no]
		][
			if all [result valid-type? type type/1 = 'agg][return no]
		]
		yes
	]

	valid-custom-call-metadata?: func [
		instruction [block!]
		/local operands metadata target-kind callee abi clobbers safepoint? may-throw?
			count count-kind count-value count-type target-type result type
	][
		operands: pick instruction ins-operands
		metadata: pick instruction ins-metadata
		unless all [
			block? operands
			(length? operands) = 2
			block? operands/1
			block? operands/2
			operands/2/1 = 'vreg
			integer? operands/2/2
			block? metadata
			even? length? metadata
			find metadata 'callee
			find metadata 'target-kind
			find metadata 'abi
			find metadata 'clobbers
			find metadata 'safepoint
			find metadata 'may-throw
			find metadata 'count-kind
			find metadata 'stack-count
			(pick instruction ins-effect) = 'call
			(pick instruction ins-alias) = 'universal
			none? pick instruction ins-flags-in
			integer? pick instruction ins-flags-out
		][return no]
		target-kind: select metadata 'target-kind
		callee: select metadata 'callee
		abi: select metadata 'abi
		clobbers: select metadata 'clobbers
		safepoint?: select metadata 'safepoint
		may-throw?: select metadata 'may-throw
		count-kind: select metadata 'count-kind
		count: select metadata 'stack-count
		unless all [
			find [direct indirect] target-kind
			either target-kind = 'direct [
				all [operands/1/1 = 'symbol word? operands/1/2 callee = operands/1/2]
			][
				all [operands/1/1 = 'vreg integer? operands/1/2 none? callee]
			]
			word? abi
			abi = pick current fn-abi
			clobbers = 'abi-default
			logic? safepoint?
			logic? may-throw?
			find [static dynamic] count-kind
			either count-kind = 'static [
				all [integer? count count >= 0]
			][none? count]
		][return no]
		count-type: vreg-type operands/2/2
		unless all [
			valid-type? count-type
			count-type/1 = 'i32
			count-type/2 = 4
		][return no]
		if count-kind = 'static [
			count-value: constant-vreg-value operands/2/2
			unless all [integer? count-value count-value = count][return no]
		]
		if target-kind = 'indirect [
			target-type: vreg-type operands/1/2
			unless all [
				valid-type? target-type
				target-type/1 = 'ptr
				target-type/2 = 8
				target-type/3 = 'gpr
			][return no]
		]
		result: pick instruction ins-result
		type: pick instruction ins-type
		unless either result [valid-type? type][none? type][return no]
		yes
	]

	valid-atomic-metadata?: func [
		instruction [block!]
		/local opcode operands metadata operation old? returns? value-type pointer-type result type flags-out
	][
		opcode: pick instruction ins-opcode
		operands: pick instruction ins-operands
		metadata: pick instruction ins-metadata
		result: pick instruction ins-result
		type: pick instruction ins-type
		flags-out: pick instruction ins-flags-out
		unless all [
			block? metadata
			even? length? metadata
			(select metadata 'order) = 'seq-cst
			operation: select metadata 'operation
			find [load store add sub or xor and cas fence] operation
			logic? old?: select metadata 'old?
			logic? returns?: select metadata 'returns?
			(pick instruction ins-effect) = 'atomic
			(pick instruction ins-alias) = 'universal
			none? pick instruction ins-flags-in
		][return no]
		value-type: select metadata 'value-type
		pointer-type: none
		case [
			opcode = 'atomic-fence [
				all [empty? operands none? result none? type operation = 'fence not old? not returns? none? value-type none? flags-out]
			]
			opcode = 'atomic-load [
				all [
					(length? operands) = 1 operands/1/1 = 'vreg
					pointer-type: vreg-type operands/1/2 pointer-type pointer-type/1 = 'ptr
					result valid-type? type type/1 = 'i32 operation = 'load returns? not old?
					value-type = type none? flags-out
				]
			]
			opcode = 'atomic-store [
				all [
					(length? operands) = 2 operands/1/1 = 'vreg operands/2/1 = 'vreg
					pointer-type: vreg-type operands/1/2 pointer-type pointer-type/1 = 'ptr
					none? result none? type operation = 'store not old? not returns?
					value-type value-type/1 = 'i32 (vreg-type operands/2/2) = value-type none? flags-out
				]
			]
			opcode = 'atomic-math [
				all [
					(length? operands) = 2 operands/1/1 = 'vreg operands/2/1 = 'vreg
					pointer-type: vreg-type operands/1/2 pointer-type pointer-type/1 = 'ptr
					find [add sub or xor and] operation value-type value-type/1 = 'i32
					(vreg-type operands/2/2) = value-type logic? returns? logic? old?
					either returns? [all [result valid-type? type type/1 = 'i32]][all [none? result none? type]]
					integer? flags-out
				]
			]
			opcode = 'atomic-cas [
				all [
					(length? operands) = 3 operands/1/1 = 'vreg operands/2/1 = 'vreg operands/3/1 = 'vreg
					pointer-type: vreg-type operands/1/2 pointer-type pointer-type/1 = 'ptr operation = 'cas
					value-type value-type/1 = 'i32
					(vreg-type operands/2/2) = value-type (vreg-type operands/3/2) = value-type
					not old? logic? returns?
					either returns? [all [result valid-type? type type/1 = 'logic]][all [none? result none? type]]
					integer? flags-out
				]
			]
			true [no]
		]
	]

	intersect-block-ids: func [left [block!] right [block!] /local result id][
		result: make block! min length? left length? right
		foreach id left [if find right id [append result id]]
		result
	]

	compute-block-dominators: func [
		blocks [block!]
		/local reachable position block successor dominators id changed? predecessors
			predecessor predecessor-set new-set old-set
	][
		reachable: make block! length? blocks
		dominators: make block! (length? blocks) * 2
		if empty? blocks [return reduce [reachable dominators]]
		append reachable 1
		position: reachable
		while [not tail? position][
			block: pick blocks position/1
			foreach successor pick block bb-successors [
				if all [
					integer? successor
					successor >= 1
					successor <= length? blocks
					none? find reachable successor
				][append reachable successor]
			]
			position: next position
		]
		sort reachable
		foreach id reachable [
			set-table-value dominators id either id = 1 [reduce [1]][copy reachable]
		]

		changed?: yes
		while [changed?][
			changed?: no
			foreach id reachable [
				unless id = 1 [
					block: pick blocks id
					predecessors: pick block bb-predecessors
					new-set: none
					foreach predecessor predecessors [
						if find reachable predecessor [
							predecessor-set: table-value dominators predecessor
							new-set: either new-set [
								intersect-block-ids new-set predecessor-set
							][copy predecessor-set]
						]
					]
					unless new-set [new-set: make block! 1]
					unless find new-set id [append new-set id]
					sort new-set
					old-set: table-value dominators id
					if old-set <> new-set [
						set-table-value dominators id new-set
						changed?: yes
					]
				]
			]
		]
		reduce [reachable dominators]
	]

	verify-current: func [
		/local errors blocks block expected-block-id instructions instruction expected-id
			defined definitions definition definition-block definition-instruction
			flag-definitions flag-definition flags-defined live-flags
			previous-seq operand result type flags-in flags-out
			memory-in memory-out next-memory memory-definitions memory-definition
			block-memory-in block-memory-out expected-memory expected-memory-in
			expected-memory-out produced-version memory-version-id effect alias
			block-stack-in block-stack-out expected-stack expected-stack-out stack-delta
			last-op predecessors predecessor
			successors successor other reloc opcode operands terminator-seen? value-type
			cfg reachable dominators block-id block-dominators dominated? incoming-block
			phi-position safepoint safepoint-instruction roots root root-type
			seen-safepoints seen-roots metadata stack-count
	][
		unless function-active? [return no]
		errors: make block! 8
		blocks: pick current fn-blocks
		if empty? blocks [verifier-error errors "function has no basic blocks"]
		expected-block-id: 1
		expected-id: 1
		defined: make block! 16
		definitions: make block! 32
		flag-definitions: make block! 16
		memory-definitions: reduce [0 reduce [0 0 'universal]]
		flags-defined: 0
		next-memory: pick current fn-next-memory
		cfg: compute-block-dominators blocks
		reachable: cfg/1
		dominators: cfg/2
		foreach block blocks [
			foreach instruction pick block bb-instructions [
				result: pick instruction ins-result
				if all [result none? table-value definitions result][
					set-table-value definitions result reduce [
						pick block bb-id
						pick instruction ins-id
					]
				]
				flags-out: pick instruction ins-flags-out
				if flags-out [
					either all [integer? flags-out flags-out >= 1][
						either table-value flag-definitions flags-out [
							verifier-error errors rejoin ["duplicate flag definition f" flags-out]
						][
							set-table-value flag-definitions flags-out reduce [
								pick block bb-id
								pick instruction ins-id
							]
						]
					][
						verifier-error errors rejoin [
							"malformed flag definition in instruction " pick instruction ins-id
						]
					]
				]
			]
		]
		foreach block blocks [
			block-id: pick block bb-id
			live-flags: none
			block-stack-in: pick block bb-stack-in
			unless valid-stack-state? block-stack-in [
				verifier-error errors rejoin ["invalid stack entry into block " block-id]
			]
			if all [block-id = 1 block-stack-in <> 0][
				verifier-error errors "entry block does not start at stack depth 0"
			]
			expected-stack: either valid-stack-state? block-stack-in [copy-stack-state block-stack-in][0]
			block-memory-in: pick block bb-memory-in
			unless verify-memory-state block-memory-in next-memory [
				verifier-error errors rejoin ["invalid memory entry into block " block-id]
			]
			either block-id = 1 [
				unless block-memory-in = reduce ['universal 0][
					verifier-error errors "entry block does not start at memory version 0"
				]
			][
				produced-version: all [
					block? block-memory-in
					(length? block-memory-in) = 2
					block-memory-in/1 = 'universal
					memory-state-value block-memory-in 'universal
				]
				either all [
					integer? produced-version
					produced-version >= 1
					produced-version <= next-memory
				][
					memory-definition: table-value memory-definitions produced-version
					either memory-definition [
						verifier-error errors rejoin [
							"duplicate memory definition m" produced-version
							" at block " block-id
						]
					][
						set-table-value memory-definitions produced-version reduce [
							block-id 0 'universal
						]
					]
				][
					verifier-error errors rejoin ["invalid memory merge into block " block-id]
				]
			]
		expected-memory: either block? block-memory-in [copy block-memory-in][copy []]
			previous-seq: 0
			terminator-seen?: no
			if (pick block bb-id) <> expected-block-id [
				verifier-error errors rejoin ["non-contiguous block id at " expected-block-id]
			]
			expected-block-id: expected-block-id + 1
			instructions: pick block bb-instructions
			foreach instruction instructions [
				opcode: pick instruction ins-opcode
				if terminator-seen? [
					verifier-error errors rejoin [
						"instruction follows terminator in basic block " pick block bb-id
					]
				]
				if terminator-opcode? opcode [terminator-seen?: yes]
				if (pick instruction ins-id) <> expected-id [
					verifier-error errors rejoin ["non-contiguous instruction id at " expected-id]
				]
				expected-id: expected-id + 1
				operands: pick instruction ins-operands
				foreach operand operands [
					unless all [block? operand (length? operand) = 2 word? operand/1][
						verifier-error errors rejoin ["malformed operand in instruction " pick instruction ins-id]
					]
					if all [block? operand operand/1 = 'vreg opcode <> 'phi][
						definition: table-value definitions operand/2
						either definition [
							if find reachable block-id [
								definition-block: definition/1
								definition-instruction: definition/2
								dominated?: either definition-block = block-id [
									definition-instruction < pick instruction ins-id
								][
									block-dominators: table-value dominators block-id
									to logic! all [block-dominators find block-dominators definition-block]
								]
								unless dominated? [
									verifier-error errors rejoin [
										"vreg %" operand/2 " does not dominate instruction "
										pick instruction ins-id
									]
								]
							]
						][
							verifier-error errors rejoin ["use of undefined vreg %" operand/2]
						]
					]
				]
				if opcode = 'phi [
					if any [empty? operands odd? length? operands][
						verifier-error errors rejoin ["malformed phi in instruction " pick instruction ins-id]
					]
					phi-position: operands
					while [(length? phi-position) >= 2][
						incoming-block: either all [
							block? phi-position/1
							phi-position/1/1 = 'block
							integer? phi-position/1/2
						][phi-position/1/2][none]
						operand: phi-position/2
						unless all [incoming-block find pick block bb-predecessors incoming-block][
							verifier-error errors rejoin [
								"phi predecessor mismatch in instruction " pick instruction ins-id
							]
						]
						if all [block? operand operand/1 = 'vreg][
							definition: table-value definitions operand/2
							either definition [
								if all [incoming-block find reachable incoming-block][
									block-dominators: table-value dominators incoming-block
									unless all [block-dominators find block-dominators definition/1][
										verifier-error errors rejoin [
											"vreg %" operand/2 " does not dominate phi edge from b"
											incoming-block
										]
									]
								]
							][
								verifier-error errors rejoin ["use of undefined vreg %" operand/2]
							]
						]
						phi-position: skip phi-position 2
					]
				]
				result: pick instruction ins-result
				type: pick instruction ins-type
				if result [
					unless valid-type? type [
						verifier-error errors rejoin ["invalid result type in instruction " pick instruction ins-id]
					]
					if find defined result [
						verifier-error errors rejoin ["duplicate vreg definition %" result]
					]
					append defined result
				]
				if opcode = 'return [
					operands: pick instruction ins-operands
					either pick current fn-return-type [
						value-type: either all [
							(length? operands) = 1
							operands/1/1 = 'vreg
						][vreg-type operands/1/2][none]
						unless all [
							(length? operands) = 1
							operands/1/1 = 'vreg
							value-type
							value-type = pick current fn-return-type
						][
							verifier-error errors rejoin [
								"return value type mismatch in instruction " pick instruction ins-id
							]
						]
					][
						unless empty? operands [
							verifier-error errors rejoin [
								"void return has a value in instruction " pick instruction ins-id
							]
						]
					]
				]
				if opcode = 'unreachable [
					unless empty? pick instruction ins-operands [
						verifier-error errors rejoin [
							"unreachable has operands in instruction " pick instruction ins-id
						]
					]
				]
				if opcode = 'call [
					unless valid-call-metadata? instruction [
						verifier-error errors rejoin [
							"invalid call metadata in instruction " pick instruction ins-id
						]
					]
				]
				if opcode = 'custom-call [
					unless valid-custom-call-metadata? instruction [
						verifier-error errors rejoin [
							"invalid custom call metadata in instruction " pick instruction ins-id
						]
					]
				]
				if find [atomic-load atomic-store atomic-math atomic-cas atomic-fence] opcode [
					unless valid-atomic-metadata? instruction [
						verifier-error errors rejoin [
							"invalid atomic metadata in instruction " pick instruction ins-id
						]
					]
				]
				if opcode = 'stack-push [
					unless all [
						none? result
						none? type
						(length? operands) = 1
						operands/1/1 = 'vreg
						(pick instruction ins-effect) = 'stack
						(pick instruction ins-alias) = 'none
					][
						verifier-error errors rejoin ["invalid stack-push in instruction " pick instruction ins-id]
					]
				]
				if opcode = 'stack-pop [
					unless all [
						result
						valid-type? type
						type/1 = 'i32
						type/2 = 4
						empty? operands
						(pick instruction ins-effect) = 'stack
						(pick instruction ins-alias) = 'none
					][
						verifier-error errors rejoin ["invalid stack-pop in instruction " pick instruction ins-id]
					]
				]
				flags-in: pick instruction ins-flags-in
				flags-out: pick instruction ins-flags-out
				if flags-in [
					either all [integer? flags-in flags-in >= 1][
						flag-definition: table-value flag-definitions flags-in
						case [
							none? flag-definition [
								verifier-error errors rejoin ["undefined flag use f" flags-in]
							]
							flag-definition/1 <> block-id [
								verifier-error errors rejoin [
									"flag f" flags-in " crosses basic block at instruction "
									pick instruction ins-id
								]
							]
							flag-definition/2 >= pick instruction ins-id [
								verifier-error errors rejoin [
									"flag f" flags-in " is used before its definition at instruction "
									pick instruction ins-id
								]
							]
							live-flags <> flags-in [
								verifier-error errors rejoin [
									"flag f" flags-in " is not live at instruction "
									pick instruction ins-id
								]
							]
							true [none]
						]
					][
						verifier-error errors rejoin [
							"malformed flag use in instruction " pick instruction ins-id
						]
					]
				]
				if flags-out [
					either all [integer? flags-out flags-out >= 1][
						if flags-out <> (flags-defined + 1) [
							verifier-error errors rejoin ["non-contiguous flag definition f" flags-out]
						]
						flags-defined: flags-defined + 1
						live-flags: flags-out
					][
						live-flags: none
					]
				]
				memory-in: pick instruction ins-memory-in
				memory-out: pick instruction ins-memory-out
				unless verify-memory-state memory-in next-memory [
					verifier-error errors rejoin ["invalid memory input in instruction " pick instruction ins-id]
				]
				unless verify-memory-state memory-out next-memory [
					verifier-error errors rejoin ["invalid memory output in instruction " pick instruction ins-id]
				]
				effect: pick instruction ins-effect
				alias: pick instruction ins-alias
				expected-memory-in: copy []
				expected-memory-out: copy []
				produced-version: none
				either all [
					word? effect
					word? alias
					find [
						pure read write call opaque volatile atomic safepoint throw may-trap stack control
					] effect
				][
					case [
						effect = 'read [
							either alias = 'none [
								verifier-error errors rejoin [
									"memory read has no alias in instruction " pick instruction ins-id
								]
							][
								expected-memory-in: memory-state-projection expected-memory alias
								expected-memory-out: copy expected-memory-in
							]
						]
						effect = 'write [
							either alias = 'none [
								verifier-error errors rejoin [
									"memory write has no alias in instruction " pick instruction ins-id
								]
							][
								expected-memory-in: memory-state-projection expected-memory alias
								produced-version: all [
									block? memory-out
									memory-state-value memory-out alias
								]
								if integer? produced-version [
									set-memory-state-value expected-memory alias produced-version
								]
								expected-memory-out: memory-state-projection expected-memory alias
							]
						]
						find [call opaque volatile atomic safepoint throw may-trap] effect [
							unless alias = 'universal [
								verifier-error errors rejoin [
									"universal effect has alias " alias " in instruction "
									pick instruction ins-id
								]
							]
							expected-memory-in: copy expected-memory
							produced-version: all [
								block? memory-out
								memory-state-value memory-out 'universal
							]
							if integer? produced-version [
								set-memory-state-value expected-memory 'universal produced-version
								expected-memory-out: reduce ['universal produced-version]
							]
						]
						true [
							unless alias = 'none [
								verifier-error errors rejoin [
									"non-memory effect has alias " alias " in instruction "
									pick instruction ins-id
								]
							]
						]
					]
				][
					verifier-error errors rejoin [
						"invalid effect metadata in instruction " pick instruction ins-id
					]
				]
				if memory-in <> expected-memory-in [
					verifier-error errors rejoin [
						"memory input dependency mismatch in instruction " pick instruction ins-id
						" expected=" mold/flat expected-memory-in
						" actual=" mold/flat memory-in
					]
				]
				if memory-out <> expected-memory-out [
					verifier-error errors rejoin [
						"memory output dependency mismatch in instruction " pick instruction ins-id
						" expected=" mold/flat expected-memory-out
						" actual=" mold/flat memory-out
					]
				]
				if produced-version [
					either all [
						integer? produced-version
						produced-version >= 1
						produced-version <= next-memory
					][
						memory-definition: table-value memory-definitions produced-version
						either memory-definition [
							verifier-error errors rejoin [
								"duplicate memory definition m" produced-version
								" in instruction " pick instruction ins-id
							]
						][
							set-table-value memory-definitions produced-version reduce [
								block-id pick instruction ins-id alias
							]
						]
					][
						verifier-error errors rejoin [
							"invalid produced memory version in instruction " pick instruction ins-id
						]
					]
				]
				unless all [
					valid-stack-state? pick instruction ins-stack-in
					valid-stack-state? pick instruction ins-stack-out
				][
					verifier-error errors rejoin ["invalid stack state in instruction " pick instruction ins-id]
				]
				if (pick instruction ins-stack-in) <> expected-stack [
					verifier-error errors rejoin [
						"stack input mismatch in instruction " pick instruction ins-id
						" expected=" expected-stack " actual=" pick instruction ins-stack-in
					]
				]
				expected-stack-out: instruction-stack-output instruction expected-stack
				if all [integer? expected-stack-out expected-stack-out < 0][
					verifier-error errors rejoin ["stack underflow in instruction " pick instruction ins-id]
				]
				either not none? expected-stack-out [
					if (pick instruction ins-stack-out) <> expected-stack-out [
						verifier-error errors rejoin [
							"stack output mismatch in instruction " pick instruction ins-id
							" expected=" mold/flat expected-stack-out
							" actual=" mold/flat pick instruction ins-stack-out
						]
					]
					expected-stack: expected-stack-out
				][
					verifier-error errors rejoin ["unknown stack transition in instruction " pick instruction ins-id]
				]
				if all [
					find [call resolve-series] opcode
					(pick instruction ins-stack-in) <> 0
					any [opcode <> 'call not integer? (pick instruction ins-stack-in)]
				][
					verifier-error errors rejoin ["ABI call with active explicit stack in instruction " pick instruction ins-id]
				]
				if all [
					find [return unreachable] opcode
					expected-stack <> 0
					not dynamic-stack-state? expected-stack
				][
					verifier-error errors rejoin ["terminator leaves explicit stack active in instruction " pick instruction ins-id]
				]
				if (pick instruction ins-source-seq) <= previous-seq [
					verifier-error errors rejoin ["source sequence is not increasing at instruction " pick instruction ins-id]
				]
				previous-seq: pick instruction ins-source-seq
			]
			block-memory-out: pick block bb-memory-out
			unless verify-memory-state block-memory-out next-memory [
				verifier-error errors rejoin ["invalid memory exit from block " block-id]
			]
			if block-memory-out <> expected-memory [
				verifier-error errors rejoin [
					"memory exit dependency mismatch in block " block-id
					" expected=" mold/flat expected-memory
					" actual=" mold/flat block-memory-out
				]
			]
			block-stack-out: pick block bb-stack-out
			unless valid-stack-state? block-stack-out [
				verifier-error errors rejoin ["invalid stack exit from block " block-id]
			]
			if block-stack-out <> expected-stack [
				verifier-error errors rejoin [
					"stack exit mismatch in block " block-id
					" expected=" expected-stack " actual=" block-stack-out
				]
			]
			if empty? instructions [
				verifier-error errors rejoin ["empty basic block " pick block bb-id]
			]
			unless empty? instructions [
				last-op: pick last instructions ins-opcode
				unless terminator-opcode? last-op [
					verifier-error errors rejoin [
						"basic block " pick block bb-id " has no terminator"
					]
				]
			]
			predecessors: pick block bb-predecessors
			foreach predecessor predecessors [
				either all [
					integer? predecessor
					predecessor >= 1
					predecessor <= length? blocks
				][
					other: pick blocks predecessor
					unless find pick other bb-successors pick block bb-id [
						verifier-error errors rejoin [
							"asymmetric predecessor edge into block " pick block bb-id
						]
					]
				][
					verifier-error errors rejoin ["invalid predecessor into block " pick block bb-id]
				]
			]
			successors: pick block bb-successors
			foreach successor successors [
				either all [integer? successor successor >= 1 successor <= length? blocks][
					other: pick blocks successor
					unless find pick other bb-predecessors pick block bb-id [
						verifier-error errors rejoin [
							"asymmetric successor edge from block " pick block bb-id
						]
					]
					if (pick block bb-stack-out) <> (pick other bb-stack-in) [
						verifier-error errors rejoin [
							"stack depth mismatch on edge b" pick block bb-id "->b" successor
						]
					]
				][
					verifier-error errors rejoin ["invalid successor from block " pick block bb-id]
				]
			]
		]
		memory-version-id: 0
		while [memory-version-id <= next-memory][
			unless table-value memory-definitions memory-version-id [
				verifier-error errors rejoin ["memory version m" memory-version-id " has no definition"]
			]
			memory-version-id: memory-version-id + 1
		]
		seen-safepoints: make block! 4
		foreach safepoint pick current fn-safepoints [
			either all [
				block? safepoint
				(length? safepoint) = 2
				integer? safepoint/1
				block? safepoint/2
			][
				either find seen-safepoints safepoint/1 [
					verifier-error errors rejoin ["duplicate safepoint at instruction " safepoint/1]
				][append seen-safepoints safepoint/1]
				safepoint-instruction: find-instruction safepoint/1
				unless all [
					safepoint-instruction
					find [call custom-call resolve-series] pick safepoint-instruction ins-opcode
				][
					verifier-error errors rejoin ["invalid safepoint instruction " safepoint/1]
				]
				roots: safepoint/2
				seen-roots: make block! length? roots
				foreach root roots [
					root-type: all [
						block? root
						(length? root) = 5
						root/1 = 'vreg
						integer? root/2
						vreg-type root/2
					]
					unless all [
						block? root
						(length? root) = 5
						root/1 = 'vreg
						integer? root/2
						root-type
						root-type/6 <> 'none
						root/3 = 'frame
						integer? root/4
						root/4 < 0
						zero? root/4 // 8
						root/5 = root-type/6
						none? find seen-roots root/2
					][
						verifier-error errors rejoin [
							"invalid safepoint root at instruction " safepoint/1
						]
					]
					if all [block? root integer? root/2][append seen-roots root/2]
				]
			][
				verifier-error errors "malformed safepoint"
			]
		]
		foreach reloc pick current fn-relocations [
			either all [
				block? reloc
				(length? reloc) = 5
				integer? reloc/1
				word? reloc/2
				word? reloc/3
				integer? reloc/4
				integer? reloc/5
				reloc/5 >= 1
			][
				instruction: find-instruction reloc/1
				either instruction [
					opcode: pick instruction ins-opcode
					operands: pick instruction ins-operands
					unless case [
					reloc/2 = 'call-rel32 [
						any [
							all [
								find [call custom-call] opcode
								not empty? operands
								operands/1 = symbol-operand reloc/3
								]
								all [
									opcode = 'resolve-series
									reloc/3 = 'red>resolve-series
									not empty? operands
									operands/1 = symbol-operand reloc/3
								]
							]
						]
						reloc/2 = 'rip-rel32 [
							any [
								all [
									find [load-global store-global] opcode
									not empty? operands
									operands/1 = global-operand reloc/3
								]
								all [
									find [address-symbol address-global] opcode
									not empty? operands
									any [
										operands/1 = symbol-operand reloc/3
										operands/1 = global-operand reloc/3
									]
								]
								all [
									find [resolve-node resolve-series] opcode
									reloc/3 = 'red>node-registry
								]
							]
						]
						true [no]
					][
						verifier-error errors rejoin [
							"relocation does not match instruction " reloc/1
						]
					]
				][
					verifier-error errors rejoin ["relocation has no instruction " reloc/1]
				]
			][
				verifier-error errors "malformed relocation"
			]
		]
		poke current fn-verifier-errors errors
		either empty? errors [
			yes
		][
			mark-unsupported 'verification-failed
			no
		]
	]

	format-type: func [type /local kind][
		if none? type [return "void"]
		unless valid-type? type [return "<invalid-type>"]
		kind: type/1
		case [
			kind = 'ptr [rejoin ["ptr" type/2 "x" type/5 "/" type/6]]
			kind = 'agg [rejoin ["aggref" type/5]]
			find [i8 i16 i32 i64] kind [form kind]
			find [f32 f64] kind [form kind]
			kind = 'logic ["logic"]
			true [form kind]
		]
	]

	format-stack-state: func [state][
		either integer? state [form state][mold/flat state]
	]

	format-operand: func [operand /local kind][
		unless all [block? operand (length? operand) = 2][return mold operand]
		kind: operand/1
		switch/default kind [
			vreg [rejoin ["%" operand/2]]
			imm [mold operand/2]
			local [rejoin ["$" form operand/2]]
			global [rejoin ["@" form operand/2]]
			symbol [form operand/2]
			block [rejoin ["b" operand/2]]
		][mold operand]
	]

	format-operands: func [operands [block!] /local out first? operand][
		out: make string! 32
		first?: yes
		foreach operand operands [
			unless first? [append out ", "]
			append out format-operand operand
			first?: no
		]
		out
	]

	dump-current: func [
		/local out block instruction result type reasons errors object reloc safepoint
	][
		unless function-active? [return copy ""]
		out: make string! 1024
		append out rejoin [
			"function " form pick current fn-name
			" abi=" form pick current fn-abi
			" return=" format-type pick current fn-return-type
			" eligible=" mold pick current fn-eligible?
			" selected=" mold pick current fn-selected?
			" body=" pick current fn-body-start ".." pick current fn-body-end
			newline
		]
		foreach object pick current fn-stack-objects [
			append out rejoin [
				"  stack #" pick object stack-id
				" " form pick object stack-kind
				" $" form pick object stack-name
				" : " format-type pick object stack-type
				" size=" pick object stack-size
				" align=" pick object stack-align
				" gc=" form pick object stack-gc-kind
				" frame=" mold pick object stack-frame-offset
				newline
			]
		]
		unless empty? pick current fn-pass-log [
			append out rejoin ["  passes: " mold/flat pick current fn-pass-log newline]
		]
		unless empty? pick current fn-allocation [
			append out rejoin ["  allocation: " mold/flat pick current fn-allocation newline]
		]
		if integer? pick current fn-frame-bitmap-offset [
			append out rejoin [
				"  frame-bitmap: " pick current fn-frame-bitmap-offset newline
			]
		]
		foreach reloc pick current fn-relocations [
			append out rejoin [
				"  relocation i" reloc/1 " " form reloc/2
				" " form reloc/3 " addend=" reloc/4 newline
			]
		]
		foreach safepoint pick current fn-safepoints [
			append out rejoin [
				"  safepoint i" safepoint/1 " roots=" mold/flat safepoint/2 newline
			]
		]
		foreach block pick current fn-blocks [
			append out rejoin [
				"b" pick block bb-id " " form pick block bb-label ":" newline
			]
			foreach instruction pick block bb-instructions [
				result: pick instruction ins-result
				type: pick instruction ins-type
				append out "  "
				if result [
					append out rejoin ["%" result ":" format-type type " = "]
				]
				append out rejoin [
					form pick instruction ins-opcode
					" " format-operands pick instruction ins-operands
					" ; effect=" form pick instruction ins-effect
				]
				if pick instruction ins-flags-in [
					append out rejoin [" flags-in=f" pick instruction ins-flags-in]
				]
				if pick instruction ins-flags-out [
					append out rejoin [" flags-out=f" pick instruction ins-flags-out]
				]
				if find [atomic-load atomic-store atomic-math atomic-cas atomic-fence]
					pick instruction ins-opcode
				[
					append out rejoin [" atomic=" mold/flat pick instruction ins-metadata]
				]
				if any [
					(pick instruction ins-stack-in) <> 0
					(pick instruction ins-stack-out) <> 0
					find [stack-push stack-pop custom-call] pick instruction ins-opcode
				][
					append out rejoin [
						" stack=" format-stack-state pick instruction ins-stack-in
						"->" format-stack-state pick instruction ins-stack-out
					]
				]
				append out rejoin [
					" mem=" mold/flat pick instruction ins-memory-in
					"->" mold/flat pick instruction ins-memory-out
					" src=" form pick instruction ins-source-file
					":" pick instruction ins-source-line
					newline
				]
			]
		]
		reasons: pick current fn-fallback-reasons
		unless empty? reasons [
			append out rejoin ["  fallback: " mold/flat reasons newline]
		]
		errors: pick current fn-verifier-errors
		unless empty? errors [
			append out rejoin ["  verifier-errors: " mold/flat errors newline]
		]
		append out newline
		out
	]

	finish-function: func [
		direct-chunk [block!]
		/debug debug-lines [block!]
		/local verified? eligible? selected-chunk dump block
	][
		unless function-active? [return direct-chunk]
		poke current fn-direct-bytes length? direct-chunk/1
		poke stats stats-functions (pick stats stats-functions) + 1
		poke stats stats-bytes (pick stats stats-bytes) + (length? direct-chunk/1)

		phase-timer/begin 'o2-ir-finalize-cfg
		block: pick current fn-current-block
		unless block-terminated? block [
			either block-reachable? pick block bb-id [
				either pick current fn-return-type [
					unless pick current fn-last-result [mark-unsupported 'missing-return-value]
					emit-return pick current fn-last-result
				][
					emit-return none
				]
			][
				emit-unreachable
			]
		]

		renumber-current
		rebuild-current-stack-dependencies
		phase-timer/finish 'o2-ir-finalize-cfg
		phase-timer/begin 'o2-ir-verify
		verified?: verify-current
		phase-timer/finish 'o2-ir-verify
		if all [verified? pick current fn-eligible?][
			phase-timer/begin 'o2-ir-optimize
			verified?: optimize-current
			phase-timer/finish 'o2-ir-optimize
		]
		if verified? [
			poke stats stats-verified (pick stats stats-verified) + 1
		]
		eligible?: all [verified? pick current fn-eligible?]
		if eligible? [
			poke stats stats-eligible (pick stats stats-eligible) + 1
			either all [debug? not debug] [
				mark-unsupported 'debug-offsets
			][
				phase-timer/begin 'o2-x64-select
				selected-chunk: rs-o2-x64/select-current direct-chunk
				phase-timer/finish 'o2-x64-select
				if all [selected-chunk debug] [
					phase-timer/begin 'o2-debug-rewrite
					unless rs-o2-x64/rewrite-debug-lines debug-lines direct-chunk [
						selected-chunk: none
					]
					phase-timer/finish 'o2-debug-rewrite
				]
			]
		]
		if all [selected-chunk not pick current fn-eligible?][selected-chunk: none]
		either selected-chunk [
			poke current fn-selected? yes
			poke current fn-selected-bytes length? selected-chunk/1
			poke stats stats-selected (pick stats stats-selected) + 1
		][
			poke stats stats-fallback (pick stats stats-fallback) + 1
		]

		if dump-path [
			phase-timer/begin 'o2-ir-dump
			dump: dump-current
			write/append dump-path dump
			phase-timer/finish 'o2-ir-dump
		]
		if all [verbose >= 3 not selected-chunk][
			print [
				"O2 IR fallback:" pick current fn-name
				mold/flat pick current fn-fallback-reasons
			]
		]
		abort-function
		any [selected-chunk direct-chunk]
	]
]

#include %machine-ir-x64.red
