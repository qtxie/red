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


	; Basic block record slots.
	bb-id:           1
	bb-label:        2
	bb-instructions: 3
	bb-predecessors: 4
	bb-successors:   5
	bb-sealed?:      6

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
		]
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
		]
		function-active?: yes
		yes
	]

	abort-function: does [
		current: rs-o2-ir-current-root: none
		function-active?: no
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

	add-block: func [label [word!] /local blocks block][
		unless function-active? [return none]
		blocks: pick current fn-blocks
		block: make-block (length? blocks) + 1 label
		append/only blocks block
		poke current fn-current-block block
		block
	]

	set-current-block: func [id [integer!] /local blocks][
		unless function-active? [return no]
		blocks: pick current fn-blocks
		unless all [id >= 1 id <= length? blocks][return no]
		poke current fn-current-block pick blocks id
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

	block-terminated?: func [block [block!] /local instructions][
		instructions: pick block bb-instructions
		all [
			not empty? instructions
			find [return jump branch switch throw] pick last instructions ins-opcode
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
			find [call opaque volatile atomic safepoint throw] effect [
				before: copy pick current fn-memory-state
				version: next-memory-version
				set-memory-version 'universal version
				after: reduce ['universal version]
			]
			true [before: after: copy []]
		]
		reduce [before after]
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
		result: either result-type [new-vreg result-type][none]
		flags-out: either define-flags? [new-flags][none]
		memory: memory-dependencies effect alias
		stack-in: pick current fn-stack-version
		stack-out: stack-in
		if effect = 'stack [
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
		if result [
			poke current fn-last-result result
			poke current fn-last-type copy/deep result-type
		]
		result
	]

	emit-constant: func [value type [block!]][
		append-op 'const reduce [immediate-operand :value] type 'pure 'none none no none
	]

	emit-load-local: func [name [word!] type [block!]][
		append-op 'load-local reduce [local-operand name] type 'read name none no none
	]

	emit-store-local: func [name [word!] value [integer!] type [block!]][
		append-op 'store-local reduce [local-operand name vreg-operand value] none 'write name none no reduce ['value-type copy/deep type]
		poke current fn-last-result value
		poke current fn-last-type copy/deep type
		value
	]

	emit-load-global: func [name [word!] type [block!]][
		append-op 'load-global reduce [global-operand name] type 'read 'universal none no none
	]

	emit-store-global: func [name [word!] value [integer!] type [block!]][
		append-op 'store-global reduce [global-operand name vreg-operand value] none 'write 'universal none no reduce ['value-type copy/deep type]
		poke current fn-last-result value
		poke current fn-last-type copy/deep type
		value
	]

	emit-binary: func [
		opcode [word!]
		left [integer!]
		right [integer!]
		type [block!]
		effect [word!]
	][
		append-op opcode reduce [vreg-operand left vreg-operand right] type effect 'none none yes none
	]

	emit-call: func [name [word!] args [block!] type [block! none!] /local operands value][
		operands: make block! (length? args) + 1
		append/only operands symbol-operand name
		foreach value args [append/only operands vreg-operand value]
		append-op 'call operands type 'call 'universal none yes reduce ['callee name]
	]

	emit-opaque: func [reason [word!] type [block! none!] /local result][
		mark-unsupported reason
		result: append-op 'opaque reduce [symbol-operand reason] type 'opaque 'universal none yes reduce ['reason reason]
		result
	]

	emit-return: func [value [integer! none!] /local operands][
		operands: make block! 1
		if value [append/only operands vreg-operand value]
		append-op 'return operands none 'control 'none none no none
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
		/local definition opcode flags from-id
	][
		definition: find-vreg-definition condition
		opcode: all [definition pick definition ins-opcode]
		flags: all [definition pick definition ins-flags-out]
		unless all [opcode comparison-op? opcode flags][
			mark-unsupported 'unsupported-branch-condition
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
		from-id: current-block-id
		condition: add-block 'while-condition
		body: add-block 'while-body
		done: add-block 'while-exit
		set-current-block from-id
		emit-jump pick condition bb-id
		set-current-block pick condition bb-id
		reduce [pick condition bb-id pick body bb-id pick done bb-id]
	]

	while-condition: func [state [block!] /local condition][
		unless all [function-active? (length? state) = 3][return none]
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
	]

	begin-if: func [/local condition-id true-block done-block][
		unless function-active? [return none]
		condition-id: current-block-id
		true-block: add-block 'if-true
		done-block: add-block 'if-exit
		set-current-block condition-id
		reduce [condition-id pick true-block bb-id pick done-block bb-id]
	]

	if-condition: func [state [block!] /local condition][
		unless all [function-active? (length? state) = 3][return none]
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

	mark-stack-object-escaped: func [name [word!] /local object][
		foreach object pick current fn-stack-objects [
			if (pick object stack-name) = name [
				poke object stack-escaped? yes
				return yes
			]
		]
		no
	]

	add-relocation: func [instruction-id [integer!] kind [word!] symbol [word!] addend [integer!]][
		append/only pick current fn-relocations reduce [instruction-id kind symbol addend]
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

	make-copy-instruction: func [instruction [block!] source [integer!]][
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
			left-definition right-definition left right type folded target
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
					if all [definition comparison-op? opcode][
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
				if target [rewrite-branch-as-jump block instruction target]
			]
		]
	]

	pass-unreachable-blocks: func [
		/local blocks reachable position id block successor mapping kept new-id
			predecessors successors mapped instruction operand
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
				foreach operand pick instruction ins-operands [
					if operand/1 = 'block [operand/2: table-value mapping operand/2]
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
		/local block instructions position instruction kept live result effect keep? operand found
	][
		foreach block pick current fn-blocks [
			instructions: pick block bb-instructions
			position: tail instructions
			kept: make block! length? instructions
			live: make block! 16
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
				input: pick instruction ins-flags-in
				if input [
					mapped: table-value flag-map input
					poke instruction ins-flags-in mapped
				]
				output: pick instruction ins-flags-out
				if output [
					flag: flag + 1
					set-table-value flag-map output flag
					poke instruction ins-flags-out flag
				]
			]
		]
		foreach reloc pick current fn-relocations [
			mapped: table-value id-map reloc/1
			if mapped [reloc/1: mapped]
		]
		foreach safepoint pick current fn-safepoints [
			mapped: table-value id-map safepoint/1
			if mapped [safepoint/1: mapped]
		]
		poke current fn-instruction-count id
		poke current fn-flag-count flag
		poke current fn-last-flags either zero? flag [none][flag]
	]

	record-pass: func [name [word!] before [integer!] after [integer!]][
		repend pick current fn-pass-log [name before after]
	]

	run-pass: func [name [word!] body [block!] /local before after][
		before: pick current fn-instruction-count
		do body
		renumber-current
		after: pick current fn-instruction-count
		record-pass name before after
		verify-current
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

	verify-current: func [
		/local errors blocks block expected-block-id instructions instruction expected-id
			defined flags-defined previous-seq operand result type flags-in flags-out
			memory-in memory-out next-memory last-op predecessors predecessor
			successors successor other
	][
		unless function-active? [return no]
		errors: make block! 8
		blocks: pick current fn-blocks
		if empty? blocks [verifier-error errors "function has no basic blocks"]
		expected-block-id: 1
		expected-id: 1
		defined: make block! 16
		flags-defined: 0
		next-memory: pick current fn-next-memory
		foreach block blocks [
			previous-seq: 0
			if (pick block bb-id) <> expected-block-id [
				verifier-error errors rejoin ["non-contiguous block id at " expected-block-id]
			]
			expected-block-id: expected-block-id + 1
			instructions: pick block bb-instructions
			foreach instruction instructions [
				if (pick instruction ins-id) <> expected-id [
					verifier-error errors rejoin ["non-contiguous instruction id at " expected-id]
				]
				expected-id: expected-id + 1
				foreach operand pick instruction ins-operands [
					unless all [block? operand (length? operand) = 2 word? operand/1][
						verifier-error errors rejoin ["malformed operand in instruction " pick instruction ins-id]
					]
					if all [block? operand operand/1 = 'vreg not find defined operand/2][
						verifier-error errors rejoin ["use of undefined vreg %" operand/2]
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
				flags-in: pick instruction ins-flags-in
				flags-out: pick instruction ins-flags-out
				if all [flags-in any [flags-in < 1 flags-in > flags-defined]][
					verifier-error errors rejoin ["invalid flag use f" flags-in]
				]
				if flags-out [
					if flags-out <> (flags-defined + 1) [
						verifier-error errors rejoin ["non-contiguous flag definition f" flags-out]
					]
					flags-defined: flags-out
				]
				memory-in: pick instruction ins-memory-in
				memory-out: pick instruction ins-memory-out
				unless verify-memory-state memory-in next-memory [
					verifier-error errors rejoin ["invalid memory input in instruction " pick instruction ins-id]
				]
				unless verify-memory-state memory-out next-memory [
					verifier-error errors rejoin ["invalid memory output in instruction " pick instruction ins-id]
				]
				if (pick instruction ins-stack-out) < (pick instruction ins-stack-in) [
					verifier-error errors rejoin ["stack token moved backwards in instruction " pick instruction ins-id]
				]
				if (pick instruction ins-source-seq) <= previous-seq [
					verifier-error errors rejoin ["source sequence is not increasing at instruction " pick instruction ins-id]
				]
				previous-seq: pick instruction ins-source-seq
			]
			if empty? instructions [
				verifier-error errors rejoin ["empty basic block " pick block bb-id]
			]
			unless empty? instructions [
				last-op: pick last instructions ins-opcode
				unless find [return jump branch switch throw] last-op [
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
				][
					verifier-error errors rejoin ["invalid successor from block " pick block bb-id]
				]
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
			find [i8 i16 i32 i64] kind [form kind]
			find [f32 f64] kind [form kind]
			kind = 'logic ["logic"]
			true [form kind]
		]
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
		/local out block instruction result type reasons errors object
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
		/local verified? eligible? selected-chunk dump
	][
		unless function-active? [return direct-chunk]
		poke current fn-direct-bytes length? direct-chunk/1
		poke stats stats-functions (pick stats stats-functions) + 1
		poke stats stats-bytes (pick stats stats-bytes) + (length? direct-chunk/1)

		if pick current fn-return-type [
			unless pick current fn-last-result [mark-unsupported 'missing-return-value]
			emit-return pick current fn-last-result
		]
		unless pick current fn-return-type [emit-return none]

		renumber-current
		verified?: verify-current
		if all [verified? pick current fn-eligible?][verified?: optimize-current]
		if verified? [
			poke stats stats-verified (pick stats stats-verified) + 1
		]
		eligible?: all [verified? pick current fn-eligible?]
		if eligible? [
			poke stats stats-eligible (pick stats stats-eligible) + 1
			either all [debug? not debug] [
				mark-unsupported 'debug-offsets
			][
				selected-chunk: rs-o2-x64/select-current direct-chunk
				if all [selected-chunk debug] [
					unless rs-o2-x64/rewrite-debug-lines debug-lines direct-chunk [
						selected-chunk: none
					]
				]
			]
		]
		either selected-chunk [
			poke current fn-selected? yes
			poke current fn-selected-bytes length? selected-chunk/1
			poke stats stats-selected (pick stats stats-selected) + 1
		][
			poke stats stats-fallback (pick stats stats-fallback) + 1
		]

		if dump-path [
			dump: dump-current
			write/append dump-path dump
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
