Red [
	Title: "Red/System x64 machine IR selection"
	File:  %machine-ir-x64.red
]

rs-o2-x64: context [
	interval-id:        1
	interval-start:     2
	interval-end:       3
	interval-register:  4
	interval-preferred: 5
	interval-fixed:     6

	integer-registers: [eax ecx edx r8d r9d r10d r11d]
	frameless?: no
	promoted-locals: make block! 8
	promoted-registers: make block! 4
	promoted-entry-loads: make block! 4
	loop-blocks: make block! 8
	folded-loads: make block! 8
	call-relocations: make block! 8
	encoded-call-patches: make block! 8
	encoded-instruction-offsets: make block! 16
	relaxed-branches: make block! 8
	branch-relaxation-changed?: no
	spilled-values: make block! 8
	call-spilled-values: make block! 8
	spill-frame-bytes: 0
	outgoing-frame-bytes: 0
	spill-gpr-scratch: none
	spill-xmm-scratch: none
	gc-bitmap-list: none
	gc-bitmap-original: none
	gc-bitmap-offset: none

	fail-selection: func [reason [word!]][
		rs-o2-ir/mark-unsupported reason
		none
	]

	supported-i32?: func [type][
		all [
			rs-o2-ir/valid-type? type
			type/1 = 'i32
			type/2 = 4
			type/3 = 'gpr
		]
	]

	supported-float?: func [type][
		all [
			rs-o2-ir/valid-type? type
			find [f32 f64] type/1
			find [4 8] type/2
			type/3 = 'xmm
		]
	]

	supported-logic?: func [type][
		all [
			rs-o2-ir/valid-type? type
			type/1 = 'logic
			type/2 = 4
			type/3 = 'gpr
		]
	]

	supported-wide-gpr?: func [type][
		to logic! all [
			rs-o2-ir/valid-type? type
			find [i64 ptr] type/1
			type/2 = 8
			type/3 = 'gpr
		]
	]

	supported-gpr-scalar?: func [type][
		any [supported-i32? type supported-logic? type supported-wide-gpr? type]
	]

	find-stack-object: func [name [word!] /local stack-entry][
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			if (pick stack-entry rs-o2-ir/stack-name) = name [return stack-entry]
		]
		none
	]

	stack-offset: func [name [word!] /local stack-entry][
		stack-entry: find-stack-object name
		all [stack-entry pick stack-entry rs-o2-ir/stack-frame-offset]
	]

	argument-register: func [
		name [word!]
		/local abi index integer-index float-index stack-entry type registers
	][
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		index: 0
		integer-index: 0
		float-index: 0
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			if (pick stack-entry rs-o2-ir/stack-kind) = 'argument [
				index: index + 1
				type: pick stack-entry rs-o2-ir/stack-type
				if supported-float? type [float-index: float-index + 1]
				unless supported-float? type [integer-index: integer-index + 1]
				if (pick stack-entry rs-o2-ir/stack-name) = name [
					return either abi = 'win64 [
						registers: either supported-float? type [
							[xmm0 xmm1 xmm2 xmm3]
						][
							[ecx edx r8d r9d]
						]
						pick registers index
					][
						registers: either supported-float? type [
							[xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7]
						][
							[edi esi edx ecx r8d r9d]
						]
						pick registers either supported-float? type [float-index][integer-index]
					]
				]
			]
		]
		none
	]

	promoted-register: func [name [word!]][
		rs-o2-ir/table-value promoted-locals name
	]

	local-referenced?: func [name [word!] /local block instruction operand][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				foreach operand pick instruction rs-o2-ir/ins-operands [
					if all [operand/1 = 'local operand/2 = name][return yes]
				]
			]
		]
		no
	]

	local-written?: func [name [word!] /local block instruction operands][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'store-local [
					operands: pick instruction rs-o2-ir/ins-operands
					if operands/1/2 = name [return yes]
				]
			]
		]
		no
	]

	function-has-call?: func [/local block instruction][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'call [return yes]
			]
		]
		no
	]

	block-reaches?: func [
		from-id [integer!]
		target-id [integer!]
		visited [block!]
		/local blocks block successor
	][
		if from-id = target-id [return yes]
		if find visited from-id [return no]
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		unless all [from-id >= 1 from-id <= length? blocks][return no]
		append visited from-id
		block: pick blocks from-id
		foreach successor pick block rs-o2-ir/bb-successors [
			if block-reaches? successor target-id visited [return yes]
		]
		no
	]

	plan-loop-blocks: func [/local block id successor][
		clear loop-blocks
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			id: pick block rs-o2-ir/bb-id
			foreach successor pick block rs-o2-ir/bb-successors [
				if block-reaches? successor id copy [] [
					append loop-blocks id
					break
				]
			]
		]
	]

	local-reference-score: func [name [word!] /local score block weight instruction operand][
		score: 0
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			weight: either find loop-blocks pick block rs-o2-ir/bb-id [16][1]
			foreach instruction pick block rs-o2-ir/bb-instructions [
				foreach operand pick instruction rs-o2-ir/ins-operands [
					if all [operand/1 = 'local operand/2 = name][
						score: score + weight
					]
				]
			]
		]
		score
	]

	local-load-before-store?: func [
		block-id [integer!]
		name [word!]
		stored? [logic!]
		visited [block!]
		/local blocks block key instruction opcode operands successor
	][
		key: block-id * 2
		if stored? [key: key + 1]
		if find visited key [return no]
		append visited key
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		unless all [block-id >= 1 block-id <= length? blocks][return no]
		block: pick blocks block-id
		foreach instruction pick block rs-o2-ir/bb-instructions [
			opcode: pick instruction rs-o2-ir/ins-opcode
			if find [load-local store-local] opcode [
				operands: pick instruction rs-o2-ir/ins-operands
				if operands/1/2 = name [
					if all [opcode = 'load-local not stored?][return yes]
					if opcode = 'store-local [stored?: yes]
				]
			]
		]
		foreach successor pick block rs-o2-ir/bb-successors [
			if local-load-before-store? successor name stored? visited [return yes]
		]
		no
	]

	local-needs-entry-load?: func [name [word!]][
		local-load-before-store? 1 name no copy []
	]

	vreg-use-count: func [id [integer!] /local count block instruction operand][
		count: 0
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				foreach operand pick instruction rs-o2-ir/ins-operands [
					if all [
						block? operand
						operand/1 = 'vreg
						operand/2 = id
					][count: count + 1]
				]
			]
		]
		count
	]

	comparison-value-used?: func [id [integer!] /local block instruction opcode index operand][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				index: 0
				foreach operand pick instruction rs-o2-ir/ins-operands [
					index: index + 1
					if all [operand/1 = 'vreg operand/2 = id][
						unless all [opcode = 'branch index = 1][return yes]
					]
				]
			]
		]
		no
	]

	folded-load-name: func [id [integer!]][
		rs-o2-ir/table-value folded-loads id
	]

	vreg-operand-index: func [instruction [block!] id [integer!] /local index operand][
		index: 0
		foreach operand pick instruction rs-o2-ir/ins-operands [
			index: index + 1
			if all [operand/1 = 'vreg operand/2 = id][return index]
		]
		none
	]

	instruction-has-folded-operand?: func [
		instruction [block!]
		except-id [integer!]
		/local operand
	][
		foreach operand pick instruction rs-o2-ir/ins-operands [
			if all [
				operand/1 = 'vreg
				operand/2 <> except-id
				folded-load-name operand/2
			][return yes]
		]
		no
	]

	memory-fold-barrier?: func [instruction [block!] name [word!] /local opcode operands effect alias][
		opcode: pick instruction rs-o2-ir/ins-opcode
		operands: pick instruction rs-o2-ir/ins-operands
		effect: pick instruction rs-o2-ir/ins-effect
		alias: pick instruction rs-o2-ir/ins-alias
		any [
			all [opcode = 'store-local operands/1/2 = name]
			find [call opaque volatile atomic safepoint throw stack] effect
			all [effect = 'write alias = 'universal]
		]
	]

	foldable-memory-use?: func [
		instruction [block!]
		operand-index [integer!]
		type [block!]
		/local opcode
	][
		opcode: pick instruction rs-o2-ir/ins-opcode
		any [
			all [
				supported-i32? type
				supported-binary? opcode
				any [
					operand-index = 2
					all [operand-index = 1 rs-o2-ir/commutative-op? opcode]
				]
			]
			all [
				supported-i32? type
				rs-o2-ir/comparison-op? opcode
				operand-index = 2
			]
			all [
				supported-float? type
				supported-float-binary? opcode
				any [
					operand-index = 2
					all [operand-index = 1 rs-o2-ir/commutative-op? opcode]
				]
			]
		]
	]

	plan-folded-loads: func [
		/local block instructions position instruction opcode result consumer-position consumer
			operands name type operand-index
	][
		clear folded-loads
		if frameless? [exit]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			instructions: pick block rs-o2-ir/bb-instructions
			position: instructions
			while [not tail? position][
				instruction: position/1
				opcode: pick instruction rs-o2-ir/ins-opcode
				if opcode = 'load-local [
					result: pick instruction rs-o2-ir/ins-result
					operands: pick instruction rs-o2-ir/ins-operands
					name: operands/1/2
					type: pick instruction rs-o2-ir/ins-type
					if all [
						result
						(vreg-use-count result) = 1
						not rs-o2-ir/stack-object-escaped? name
						integer? stack-offset name
					][
						consumer-position: next position
						while [not tail? consumer-position][
							consumer: consumer-position/1
							if memory-fold-barrier? consumer name [break]
							if operand-index: vreg-operand-index consumer result [
								if all [
									none? promoted-register name
									foldable-memory-use? consumer operand-index type
									not instruction-has-folded-operand? consumer result
								][repend folded-loads [result name]]
								break
							]
							consumer-position: next consumer-position
						]
					]
				]
				position: next position
			]
		]
	]

	plan-promoted-locals: func [
		/local registers candidates candidate stack-entry name type register score
			position best-position best-score has-call?
	][
		clear promoted-locals
		clear promoted-registers
		clear promoted-entry-loads
		if (length? pick rs-o2-ir/current rs-o2-ir/fn-blocks) = 1 [return none]
		plan-loop-blocks
		has-call?: function-has-call?
		registers: copy [r8d r9d r10d r11d]
		candidates: make block! 8
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			name: pick stack-entry rs-o2-ir/stack-name
			type: pick stack-entry rs-o2-ir/stack-type
			if all [
				supported-i32? type
				(pick stack-entry rs-o2-ir/stack-gc-kind) = 'none
				not pick stack-entry rs-o2-ir/stack-escaped?
				integer? pick stack-entry rs-o2-ir/stack-frame-offset
				local-referenced? name
				any [not has-call? local-written? name]
			][
				score: local-reference-score name
				append/only candidates reduce [stack-entry score]
			]
		]
		while [all [not empty? registers not empty? candidates]][
			best-position: candidates
			best-score: best-position/1/2
			position: next candidates
			while [not tail? position][
				if position/1/2 > best-score [
					best-position: position
					best-score: position/1/2
				]
				position: next position
			]
			candidate: best-position/1
			remove best-position
			stack-entry: candidate/1
			name: pick stack-entry rs-o2-ir/stack-name
			register: take registers
			repend promoted-locals [name register]
			append promoted-registers register
		]
		foreach [name register] promoted-locals [
			if local-needs-entry-load? name [append promoted-entry-loads name]
		]
	]

	frameless-eligible?: func [/local block instruction opcode operands stack-entry][
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			unless (pick stack-entry rs-o2-ir/stack-gc-kind) = 'none [return no]
			if pick stack-entry rs-o2-ir/stack-escaped? [return no]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				if opcode = 'call [return no]
				if opcode = 'store-local [return no]
				if all [
					opcode = 'load-local
					none? argument-register operands/1/2
				][return no]
			]
		]
		yes
	]

	available-registers: has [registers register position][
		registers: either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
			copy [eax ecx edx r8d r9d r10d r11d]
		][
			copy [eax ecx edx esi edi r8d r9d r10d r11d]
		]
		foreach register promoted-registers [
			if position: find registers register [remove position]
		]
		registers
	]

	available-xmm-registers: does [
		either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
			copy [xmm0 xmm1 xmm2 xmm3 xmm4 xmm5]
		][
			copy [
				xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7
				xmm8 xmm9 xmm10 xmm11 xmm12 xmm13 xmm14 xmm15
			]
		]
	]

	call-argument-register: func [
		instruction [block!]
		argument-index [integer!]
		/local operands abi index integer-index float-index operand type registers
	][
		operands: next pick instruction rs-o2-ir/ins-operands
		unless all [argument-index >= 1 argument-index <= length? operands][return none]
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		integer-index: 0
		float-index: 0
		repeat index argument-index [
			operand: pick operands index
			type: rs-o2-ir/vreg-type operand/2
			either supported-float? type [
				float-index: float-index + 1
			][integer-index: integer-index + 1]
		]
		either abi = 'win64 [
			registers: either supported-float? type [
				[xmm0 xmm1 xmm2 xmm3]
			][
				[ecx edx r8d r9d]
			]
			pick registers argument-index
		][
			registers: either supported-float? type [
				[xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7]
			][
				[edi esi edx ecx r8d r9d]
			]
			pick registers either supported-float? type [float-index][integer-index]
		]
	]

	call-stack-argument-offset: func [
		instruction [block!]
		argument-index [integer!]
		/local operands abi index integer-index float-index stack-index operand type on-stack?
	][
		operands: next pick instruction rs-o2-ir/ins-operands
		unless all [argument-index >= 1 argument-index <= length? operands][return none]
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		if abi = 'win64 [
			return either argument-index > 4 [(argument-index - 1) * 8][none]
		]
		integer-index: 0
		float-index: 0
		stack-index: 0
		on-stack?: no
		repeat index argument-index [
			operand: pick operands index
			type: rs-o2-ir/vreg-type operand/2
			either supported-float? type [
				float-index: float-index + 1
				on-stack?: float-index > 8
			][
				integer-index: integer-index + 1
				on-stack?: integer-index > 6
			]
			if on-stack? [stack-index: stack-index + 1]
		]
		either on-stack? [(stack-index - 1) * 8][none]
	]

	maximum-outgoing-frame-bytes: func [
		/local maximum block instruction operands argument-index operand offset
	][
		maximum: 0
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'call [
					operands: pick instruction rs-o2-ir/ins-operands
					argument-index: 0
					foreach operand next operands [
						argument-index: argument-index + 1
						offset: call-stack-argument-offset instruction argument-index
						if integer? offset [maximum: max maximum (offset + 8)]
					]
				]
			]
		]
		either zero? maximum [0][round/to/ceiling maximum 16]
	]

	supported-binary?: func [opcode [word!]][
		any [
			opcode = rs-o2-ir/add-op
			opcode = rs-o2-ir/subtract-op
			opcode = rs-o2-ir/multiply-op
			opcode = 'and
			opcode = 'or
			opcode = 'xor
		]
	]

	supported-float-binary?: func [opcode [word!]][
		any [
			opcode = rs-o2-ir/add-op
			opcode = rs-o2-ir/subtract-op
			opcode = rs-o2-ir/multiply-op
			opcode = first [/]
		]
	]

	supported-binary-operation?: func [opcode [word!]][
		any [supported-binary? opcode supported-float-binary? opcode]
	]

	return-register: func [type][
		either supported-float? type ['xmm0]['eax]
	]

	validate-operands: func [
		instruction [block!]
		/local opcode operands stack-entry name result type operand left-type right-type
	][
		opcode: pick instruction rs-o2-ir/ins-opcode
		operands: pick instruction rs-o2-ir/ins-operands
		result: pick instruction rs-o2-ir/ins-result
		type: pick instruction rs-o2-ir/ins-type
		if all [
			result
			not any [
				supported-gpr-scalar? type
				supported-float? type
			]
		][return fail-selection 'x64-unsupported-type]
		if all [
			pick instruction rs-o2-ir/ins-flags-in
			opcode <> 'branch
		][return fail-selection 'x64-live-flags]
		if all [
			pick instruction rs-o2-ir/ins-flags-out
			rs-o2-ir/flags-used? pick instruction rs-o2-ir/ins-flags-out
			not rs-o2-ir/comparison-op? opcode
		][return fail-selection 'x64-live-flags]
		case [
			opcode = 'const [
				unless all [
					result
					(length? operands) = 1
					operands/1/1 = 'imm
					all [any [supported-i32? type supported-logic? type] integer? operands/1/2]
				][return fail-selection 'x64-constant-shape]
			]
			opcode = 'copy [
				unless all [result (length? operands) = 1 operands/1/1 = 'vreg][
					return fail-selection 'x64-copy-shape
				]
			]
			opcode = 'load-local [
				unless all [result (length? operands) = 1 operands/1/1 = 'local][
					return fail-selection 'x64-load-shape
				]
				name: operands/1/2
				stack-entry: find-stack-object name
				unless all [
					stack-entry
					any [
						integer? pick stack-entry rs-o2-ir/stack-frame-offset
						argument-register name
					]
					not pick stack-entry rs-o2-ir/stack-escaped?
				][return fail-selection 'x64-unresolved-stack-offset]
			]
			opcode = 'store-local [
				unless all [
					(length? operands) = 2
					operands/1/1 = 'local
					operands/2/1 = 'vreg
				][return fail-selection 'x64-store-shape]
				name: operands/1/2
				stack-entry: find-stack-object name
				unless all [
					stack-entry
					integer? pick stack-entry rs-o2-ir/stack-frame-offset
					not pick stack-entry rs-o2-ir/stack-escaped?
				][return fail-selection 'x64-unresolved-stack-offset]
			]
			supported-binary-operation? opcode [
				unless all [
					result
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'vreg
				][return fail-selection 'x64-binary-shape]
				left-type: rs-o2-ir/vreg-type operands/1/2
				right-type: rs-o2-ir/vreg-type operands/2/2
				unless either supported-float? type [
					all [
						supported-float-binary? opcode
						left-type = type
						right-type = type
					]
				][
					all [
						supported-i32? type
						supported-binary? opcode
						supported-i32? left-type
						supported-i32? right-type
					]
				][return fail-selection 'x64-binary-type]
			]
			rs-o2-ir/comparison-op? opcode [
				unless all [
					result
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'vreg
					pick instruction rs-o2-ir/ins-flags-out
				][return fail-selection 'x64-comparison-shape]
				left-type: rs-o2-ir/vreg-type operands/1/2
				right-type: rs-o2-ir/vreg-type operands/2/2
				unless all [supported-i32? left-type supported-i32? right-type][
					return fail-selection 'x64-float-comparison
				]
			]
				opcode = 'call [
					unless all [
						not empty? operands
						operands/1/1 = 'symbol
					][return fail-selection 'x64-call-shape]
				foreach operand next operands [
					unless operand/1 = 'vreg [return fail-selection 'x64-call-argument]
				]
			]
			opcode = 'jump [
				unless all [(length? operands) = 1 operands/1/1 = 'block][
					return fail-selection 'x64-jump-shape
				]
			]
			opcode = 'branch [
				unless all [
					(length? operands) = 3
					operands/1/1 = 'vreg
					operands/2/1 = 'block
					operands/3/1 = 'block
					pick instruction rs-o2-ir/ins-flags-in
				][return fail-selection 'x64-branch-shape]
			]
			opcode = 'return [
				unless all [
					(length? operands) <= 1
					any [empty? operands operands/1/1 = 'vreg]
				][return fail-selection 'x64-return-shape]
			]
			true [return fail-selection 'x64-unsupported-opcode]
		]
		yes
	]

	plan-call-relocations: func [
		direct-chunk [block!]
		/local calls refs block instruction position name spec ref relative start ending
	][
		clear call-relocations
		calls: make block! 8
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'call [append/only calls instruction]
			]
		]
		refs: direct-chunk/2
		unless (length? calls) = length? refs [return fail-selection 'x64-call-relocation-count]
		if empty? calls [return yes]
		unless all [(length? direct-chunk) >= 3 integer? direct-chunk/3][
			return fail-selection 'x64-call-relocation-base
		]
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		ending: pick rs-o2-ir/current rs-o2-ir/fn-body-end
		position: refs
		foreach instruction calls [
			name: pick instruction rs-o2-ir/ins-operands
			name: name/1/2
			spec: select emitter/symbols name
			ref: position/1
			unless all [
				spec
				spec/1 = 'native
				block? ref
				not tail? ref
				same? head ref spec/3
			][return fail-selection 'x64-call-relocation-symbol]
			relative: ref/1 - direct-chunk/3 + 1
			unless all [relative > start relative <= ending][
				return fail-selection 'x64-call-relocation-range
			]
			repend call-relocations [pick instruction rs-o2-ir/ins-id ref]
			position: next position
		]
		yes
	]

	validate-current: func [direct-chunk [block!] /local blocks block instruction start ending type][
		frameless?: no
		clear promoted-locals
		clear promoted-registers
		clear promoted-entry-loads
		clear loop-blocks
		clear folded-loads
		clear call-relocations
		clear encoded-call-patches
		clear spilled-values
		clear call-spilled-values
		spill-frame-bytes: 0
		outgoing-frame-bytes: 0
		spill-gpr-scratch: none
		spill-xmm-scratch: none
		gc-bitmap-list: none
		gc-bitmap-original: none
		gc-bitmap-offset: none
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		unless empty? pick rs-o2-ir/current rs-o2-ir/fn-relocations [
			return fail-selection 'x64-ir-relocations
		]
		unless empty? pick rs-o2-ir/current rs-o2-ir/fn-safepoints [
			return fail-selection 'x64-safepoints
		]
		unless (length? direct-chunk) >= 2 [return fail-selection 'x64-direct-chunk]
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		ending: pick rs-o2-ir/current rs-o2-ir/fn-body-end
		unless all [
			integer? start
			integer? ending
			start >= 0
			ending >= start
			ending <= length? direct-chunk/1
		][return fail-selection 'x64-invalid-body-range]
		type: pick rs-o2-ir/current rs-o2-ir/fn-return-type
		if all [type not any [supported-gpr-scalar? type supported-float? type]][
			return fail-selection 'x64-return-type
		]
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				unless validate-operands instruction [return no]
			]
		]
		unless plan-call-relocations direct-chunk [return no]
		frameless?: all [(length? blocks) = 1 frameless-eligible?]
		unless frameless? [plan-promoted-locals]
		yes
	]

	find-interval: func [intervals [block!] id [integer!] /local interval][
		foreach interval intervals [
			if (pick interval interval-id) = id [return interval]
		]
		none
	]

	build-intervals: func [
		/local intervals block instruction use-position definition-position operand interval
			result opcode operands preferred fixed return-interval
			store-targets register existing existing-fixed argument-index call-operand
	][
		intervals: make block! 16
		if frameless? [
			foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
				foreach instruction pick block rs-o2-ir/bb-instructions [
					if (pick instruction rs-o2-ir/ins-opcode) = 'load-local [
						operands: pick instruction rs-o2-ir/ins-operands
						result: pick instruction rs-o2-ir/ins-result
						fixed: argument-register operands/1/2
						append/only intervals reduce [result 0 0 none none fixed]
					]
				]
			]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				use-position: (pick instruction rs-o2-ir/ins-id) * 2
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				foreach operand operands [
					if all [
						operand/1 = 'vreg
						none? folded-load-name operand/2
					][
						interval: find-interval intervals operand/2
						unless interval [return fail-selection 'x64-undefined-interval]
						if use-position > pick interval interval-end [
							poke interval interval-end use-position
						]
					]
				]
				result: pick instruction rs-o2-ir/ins-result
				if all [result none? folded-load-name result][
					definition-position: use-position + 1
					preferred: none
					fixed: none
					if opcode = 'load-local [
						fixed: promoted-register operands/1/2
					]
					if opcode = 'call [
						fixed: return-register pick instruction rs-o2-ir/ins-type
					]
					if all [
						any [opcode = 'copy supported-binary-operation? opcode]
						not empty? operands
						operands/1/1 = 'vreg
					][preferred: operands/1/2]
					interval: find-interval intervals result
					either interval [
						poke interval interval-preferred preferred
						if all [fixed none? pick interval interval-fixed][
							poke interval interval-fixed fixed
						]
					][
						append/only intervals reduce [
							result definition-position definition-position none preferred fixed
						]
					]
				]
				if opcode = 'call [
					argument-index: 0
					foreach call-operand next operands [
						argument-index: argument-index + 1
						interval: find-interval intervals call-operand/2
						unless interval [return fail-selection 'x64-call-undefined-argument]
						fixed: call-argument-register instruction argument-index
						if fixed [
							existing-fixed: pick interval interval-fixed
							unless existing-fixed [poke interval interval-fixed fixed]
						]
					]
				]
			]
		]
		store-targets: make block! 8
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'store-local [
					operands: pick instruction rs-o2-ir/ins-operands
					register: promoted-register operands/1/2
					if register [
						result: operands/2/2
						existing: rs-o2-ir/table-value store-targets result
						either existing [
							unless existing = register [
								rs-o2-ir/set-table-value store-targets result 'conflict
							]
						][
							rs-o2-ir/set-table-value store-targets result register
						]
					]
				]
			]
		]
		foreach [result register] store-targets [
			if all [register <> 'conflict interval: find-interval intervals result][
				if none? pick interval interval-fixed [poke interval interval-fixed register]
			]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'return [
					operands: pick instruction rs-o2-ir/ins-operands
					unless empty? operands [
						return-interval: find-interval intervals operands/1/2
						if all [return-interval none? pick return-interval interval-fixed][
							poke return-interval interval-fixed return-register rs-o2-ir/vreg-type operands/1/2
						]
					]
				]
			]
		]
		intervals
	]

	plan-call-spills: func [
		intervals [block!]
		/local block instruction position interval id
	][
		clear call-spilled-values
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'call [
					position: (pick instruction rs-o2-ir/ins-id) * 2
					foreach interval intervals [
						if all [
							(pick interval interval-start) < position
							(pick interval interval-end) > position
							not find promoted-registers pick interval interval-fixed
						][
							id: pick interval interval-id
							unless find call-spilled-values id [append call-spilled-values id]
						]
					]
				]
			]
		]
		yes
	]

	allocation-register: func [allocation [block!] id [integer!]][
		rs-o2-ir/table-value allocation id
	]

	fixed-register-used?: func [intervals [block!] register [word!] /local interval][
		foreach interval intervals [
			if (pick interval interval-fixed) = register [return yes]
		]
		no
	]

	choose-spill-scratch: func [
		register-class [word!]
		intervals [block!]
		/local candidates candidate
	][
		candidates: case [
			register-class = 'gpr [[r11d r10d]]
			register-class = 'xmm [
				either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
					[xmm5 xmm4]
				][
					[xmm15 xmm14 xmm13 xmm12 xmm11 xmm10 xmm9 xmm8]
				]
			]
			true [copy []]
		]
		foreach candidate candidates [
			unless any [
				find promoted-registers candidate
				fixed-register-used? intervals candidate
			][return candidate]
		]
		none
	]

	prepare-call-spill-scratches: func [
		intervals [block!]
		free-gpr [block!]
		free-xmm [block!]
		/local id type register-class scratch position
	][
		foreach id call-spilled-values [
			type: rs-o2-ir/vreg-type id
			unless rs-o2-ir/valid-type? type [return fail-selection 'x64-call-spill-type]
			register-class: type/3
			case [
				register-class = 'gpr [
					unless spill-gpr-scratch [
						scratch: choose-spill-scratch register-class intervals
						unless scratch [return fail-selection 'x64-call-spill-scratch]
						spill-gpr-scratch: scratch
						if position: find free-gpr scratch [remove position]
					]
				]
				register-class = 'xmm [
					unless spill-xmm-scratch [
						scratch: choose-spill-scratch register-class intervals
						unless scratch [return fail-selection 'x64-call-spill-scratch]
						spill-xmm-scratch: scratch
						if position: find free-xmm scratch [remove position]
					]
				]
				true [return fail-selection 'x64-call-spill-register-class]
			]
		]
		yes
	]

	spill-active-register: func [
		active [block!]
		register [word!]
		allocation [block!]
		/local position interval
	][
		position: active
		while [not tail? position][
			interval: position/1
			if (pick interval interval-register) = register [
				if pick interval interval-fixed [return no]
				poke interval interval-register 'spill
				rs-o2-ir/set-table-value allocation pick interval interval-id 'spill
				remove position
				return yes
			]
			position: next position
		]
		yes
	]

	reserve-spill-scratch: func [
		register-class [word!]
		intervals [block!]
		allocation [block!]
		free [block!]
		active [block!]
		/local scratch free-position
	][
		scratch: either register-class = 'gpr [spill-gpr-scratch][spill-xmm-scratch]
		unless scratch [
			scratch: choose-spill-scratch register-class intervals
			unless scratch [return no]
			either register-class = 'gpr [
				spill-gpr-scratch: scratch
			][spill-xmm-scratch: scratch]
		]
		if free-position: find free scratch [remove free-position]
		spill-active-register active scratch allocation
	]

	allocate-intervals: func [
		intervals [block!]
		/local allocation free-gpr free-xmm active-gpr active-xmm free active interval
			position active-interval start preferred preferred-register free-position
			id register promoted-fixed? type register-class occupant-position occupant
			victim-position victim
	][
		allocation: make block! 16
		free-gpr: available-registers
		free-xmm: available-xmm-registers
		unless prepare-call-spill-scratches intervals free-gpr free-xmm [return none]
		active-gpr: make block! 8
		active-xmm: make block! 8
		foreach interval intervals [
			id: pick interval interval-id
			type: rs-o2-ir/vreg-type id
			unless rs-o2-ir/valid-type? type [return fail-selection 'x64-allocation-type]
			if find call-spilled-values id [
				poke interval interval-register 'spill
				repend allocation [id 'spill]
				continue
			]
			register-class: type/3
			case [
				register-class = 'gpr [free: free-gpr active: active-gpr]
				register-class = 'xmm [free: free-xmm active: active-xmm]
				true [return fail-selection 'x64-register-class]
			]
			start: pick interval interval-start
			position: active
			while [not tail? position][
				active-interval: position/1
				either (pick active-interval interval-end) < start [
					register: pick active-interval interval-register
					unless find free register [insert free register]
					remove position
				][position: next position]
			]
			register: pick interval interval-fixed
			promoted-fixed?: all [register find promoted-registers register]
			either register [
				either promoted-fixed? [
					; Promoted locals own their register for the whole function. They
					; are intentionally outside the transient active interval set.
				][
					free-position: find free register
					either free-position [
						remove free-position
					][
						occupant-position: active
						occupant: none
						while [not tail? occupant-position][
							if (pick occupant-position/1 interval-register) = register [
								occupant: occupant-position/1
								break
							]
							occupant-position: next occupant-position
						]
						unless all [
							occupant
							none? pick occupant interval-fixed
							reserve-spill-scratch register-class intervals allocation free active
							spill-active-register active register allocation
						][return fail-selection 'x64-fixed-register-conflict]
					]
				]
			][
				preferred: pick interval interval-preferred
				if preferred [
					preferred-register: allocation-register allocation preferred
					if all [preferred-register free-position: find free preferred-register][
						register: free-position/1
						remove free-position
					]
				]
			]
			if none? register [
				either empty? free [
					unless reserve-spill-scratch register-class intervals allocation free active [
						return fail-selection 'x64-spill-scratch
					]
					victim-position: none
					victim: none
					position: active
					while [not tail? position][
						active-interval: position/1
						if all [
							none? pick active-interval interval-fixed
							(pick active-interval interval-end) > pick interval interval-end
							any [
								none? victim
								(pick active-interval interval-end) > pick victim interval-end
							]
						][
							victim-position: position
							victim: active-interval
						]
						position: next position
					]
					either victim [
						register: pick victim interval-register
						poke victim interval-register 'spill
						rs-o2-ir/set-table-value allocation pick victim interval-id 'spill
						remove victim-position
					][register: 'spill]
				][register: take free]
			]
			poke interval interval-register register
			repend allocation [pick interval interval-id register]
			unless any [promoted-fixed? register = 'spill] [append/only active interval]
		]
		poke rs-o2-ir/current rs-o2-ir/fn-allocation allocation
		allocation
	]

	plan-spill-slots: func [
		intervals [block!]
		/local minimum stack-entry offset interval id type size name slot count total
	][
		clear spilled-values
		spill-frame-bytes: 0
		minimum: -32
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			offset: pick stack-entry rs-o2-ir/stack-frame-offset
			if all [integer? offset offset < minimum][minimum: offset]
		]
		slot: minimum - 48
		count: 0
		foreach interval intervals [
			if (pick interval interval-register) = 'spill [
				id: pick interval interval-id
				type: rs-o2-ir/vreg-type id
				size: max 8 type/2
				name: to word! rejoin ["__o2-spill-" id]
				rs-o2-ir/add-stack-object name 'spill type size size type/6
				rs-o2-ir/set-stack-offset name slot
				repend spilled-values [id slot]
				slot: slot - size
				count: count + size
			]
		]
		outgoing-frame-bytes: maximum-outgoing-frame-bytes
		total: outgoing-frame-bytes
		if positive? count [total: total + 48 + count]
		unless zero? total [
			spill-frame-bytes: round/to/ceiling total 16
			frameless?: no
		]
	]

	bitmap-word-at: func [word-offset [integer!] /local position][
		emitter/ensure-bits-buf
		position: (word-offset * 4) + 1
		unless all [
			position >= 1
			(position + 3) <= length? emitter/bits-buf
		][return none]
		to integer! reverse copy/part at emitter/bits-buf position 4
	]

	read-frame-bitmap: func [
		offset [integer!]
		/local base cursor arg-slots local-slots arg-words local-words word
	][
		base: offset and 0FFFFFFFh
		arg-slots: bitmap-word-at base
		local-slots: bitmap-word-at base + 1
		unless all [
			integer? arg-slots
			integer? local-slots
			arg-slots >= 0
			local-slots >= 0
		][return none]
		cursor: base + 2
		arg-words: make block! 2
		until [
			word: bitmap-word-at cursor
			unless integer? word [return none]
			append arg-words word
			cursor: cursor + 1
			zero? word and 80000000h
		]
		local-words: make block! 2
		until [
			word: bitmap-word-at cursor
			unless integer? word [return none]
			append local-words word
			cursor: cursor + 1
			zero? word and 80000000h
		]
		reduce [arg-slots local-slots arg-words local-words]
	]

	normalize-bitmap-words: func [words [block!] /local index word][
		if empty? words [append words 0]
		repeat index length? words [
			word: (pick words index) and 7FFFFFFFh
			if index < length? words [word: word or 80000000h]
			poke words index word
		]
		words
	]

	plan-gc-metadata: func [
		intervals [block!]
		allocation [block!]
		direct-chunk [block!]
		/local safepoints root-spills block instruction position roots interval id type
			location offset original bitmap arg-slots local-slots arg-words local-words
			local-index required-local-slots word-index bit-index word bytes
	][
		safepoints: pick rs-o2-ir/current rs-o2-ir/fn-safepoints
		clear safepoints
		root-spills: make block! 4
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'call [
					position: (pick instruction rs-o2-ir/ins-id) * 2
					roots: make block! 2
					foreach interval intervals [
						if all [
							(pick interval interval-start) < position
							(pick interval interval-end) > position
						][
							id: pick interval interval-id
							type: rs-o2-ir/vreg-type id
							if all [rs-o2-ir/valid-type? type type/6 <> 'none][
								location: allocation-register allocation id
								unless location = 'spill [
									return fail-selection 'x64-gc-register-root
								]
								offset: spill-offset id
								unless integer? offset [
									return fail-selection 'x64-gc-spill-offset
								]
								append/only roots reduce ['vreg id 'frame offset type/6]
								unless find root-spills id [append root-spills id]
							]
						]
					]
					rs-o2-ir/add-safepoint pick instruction rs-o2-ir/ins-id roots
				]
			]
		]
		if empty? root-spills [return yes]
		original: pick rs-o2-ir/current rs-o2-ir/fn-frame-bitmap-offset
		unless integer? original [return fail-selection 'x64-gc-bitmap-offset]
		bytes: direct-chunk/1
		unless all [
			(length? bytes) >= 13
			(copy/part at bytes 9 1) = #{68}
		][return fail-selection 'x64-gc-bitmap-patch-point]
		bitmap: read-frame-bitmap original
		unless bitmap [return fail-selection 'x64-gc-bitmap-decode]
		arg-slots: bitmap/1
		local-slots: bitmap/2
		arg-words: copy bitmap/3
		local-words: copy bitmap/4
		required-local-slots: local-slots
		foreach id root-spills [
			offset: spill-offset id
			unless all [offset < 0 zero? offset // 8][
				return fail-selection 'x64-gc-spill-alignment
			]
			local-index: ((to integer! ((absolute offset) / 8)) - 5) - arg-slots
			if local-index < 0 [return fail-selection 'x64-gc-spill-range]
			required-local-slots: max required-local-slots local-index + 1
			word-index: (to integer! (local-index / 31)) + 1
			while [(length? local-words) < word-index][append local-words 0]
			bit-index: local-index // 31
			word: (pick local-words word-index) and 7FFFFFFFh
			word: word or (shift/left 1 bit-index)
			poke local-words word-index word
		]
		normalize-bitmap-words arg-words
		normalize-bitmap-words local-words
		gc-bitmap-list: reduce [arg-slots required-local-slots]
		foreach word arg-words [append gc-bitmap-list word]
		append gc-bitmap-list '-
		foreach word local-words [append gc-bitmap-list word]
		gc-bitmap-original: original
		yes
	]

	apply-gc-bitmap: func [selected [block!] /local offset flags bytes][
		unless block? gc-bitmap-list [return yes]
		offset: emitter/store-ptr-bitmap gc-bitmap-list
		flags: gc-bitmap-original and 40000000h
		if not zero? flags [offset: offset or flags]
		bytes: selected/1
		unless all [
			(length? bytes) >= 13
			(copy/part at bytes 9 1) = #{68}
		][return fail-selection 'x64-gc-bitmap-patch-point]
		change/part at bytes 10 int-to-bin/to-bin32 offset 4
		gc-bitmap-offset: offset
		rs-o2-ir/set-frame-bitmap-offset offset
		yes
	]

	register-code: func [register [word!]][
		select [eax 0 ecx 1 edx 2 esi 6 edi 7 r8d 8 r9d 9 r10d 10 r11d 11] register
	]

	xmm-register-code: func [register [word!]][
		select [
			xmm0 0 xmm1 1 xmm2 2 xmm3 3
			xmm4 4 xmm5 5 xmm6 6 xmm7 7
			xmm8 8 xmm9 9 xmm10 10 xmm11 11
			xmm12 12 xmm13 13 xmm14 14 xmm15 15
		] register
	]

	append-byte: func [code [binary!] value [integer!]][
		append code int-to-bin/to-bin8 value
	]

	emit-rex: func [
		code [binary!]
		wide? [logic!]
		reg-field [integer! none!]
		index-field [integer! none!]
		base-field [integer! none!]
		/local rex
	][
		rex: 64
		if wide? [rex: rex or 8]
		if all [reg-field reg-field >= 8][rex: rex or 4]
		if all [index-field index-field >= 8][rex: rex or 2]
		if all [base-field base-field >= 8][rex: rex or 1]
		if rex <> 64 [append-byte code rex]
	]

	emit-modrm: func [code [binary!] mode [integer!] reg [integer!] rm [integer!]][
		append-byte code mode + (((reg and 7) * 8) + (rm and 7))
	]

	emit-mov-immediate: func [code [binary!] destination [word!] value [integer!] /local dst][
		dst: register-code destination
		emit-rex code no none none dst
		append-byte code 184 + (dst and 7)
		append code int-to-bin/to-bin32 value
	]

	emit-mov-register: func [code [binary!] destination [word!] source [word!] /local dst src][
		if destination = source [exit]
		dst: register-code destination
		src: register-code source
		emit-rex code no src none dst
		append-byte code 137
		emit-modrm code 192 src dst
	]

	emit-gpr-move: func [
		code [binary!]
		type [block!]
		destination [word!]
		source [word!]
		/local dst src
	][
		if destination = source [exit]
		dst: register-code destination
		src: register-code source
		emit-rex code supported-wide-gpr? type src none dst
		append-byte code 137
		emit-modrm code 192 src dst
	]

	emit-frame-modrm: func [code [binary!] reg [integer!] offset [integer!]][
		either all [offset >= -128 offset <= 127][
			emit-modrm code 64 reg 5
			append code int-to-bin/to-bin8 offset
		][
			emit-modrm code 128 reg 5
			append code int-to-bin/to-bin32 offset
		]
	]

	emit-frame-load: func [code [binary!] destination [word!] offset [integer!] /local dst][
		dst: register-code destination
		emit-rex code no dst none 5
		append-byte code 139
		emit-frame-modrm code dst offset
	]

	emit-frame-store: func [code [binary!] offset [integer!] source [word!] /local src][
		src: register-code source
		emit-rex code no src none 5
		append-byte code 137
		emit-frame-modrm code src offset
	]

	emit-gpr-frame-load: func [
		code [binary!]
		type [block!]
		destination [word!]
		offset [integer!]
		/local dst
	][
		dst: register-code destination
		emit-rex code supported-wide-gpr? type dst none 5
		append-byte code 139
		emit-frame-modrm code dst offset
	]

	emit-gpr-frame-store: func [
		code [binary!]
		type [block!]
		offset [integer!]
		source [word!]
		/local src
	][
		src: register-code source
		emit-rex code supported-wide-gpr? type src none 5
		append-byte code 137
		emit-frame-modrm code src offset
	]

	emit-rsp-modrm: func [code [binary!] reg [integer!] offset [integer!]][
		case [
			zero? offset [
				emit-modrm code 0 reg 4
				append-byte code 36
			]
			all [offset >= -128 offset <= 127] [
				emit-modrm code 64 reg 4
				append-byte code 36
				append code int-to-bin/to-bin8 offset
			]
			true [
				emit-modrm code 128 reg 4
				append-byte code 36
				append code int-to-bin/to-bin32 offset
			]
		]
	]

	emit-gpr-rsp-store: func [
		code [binary!]
		type [block!]
		offset [integer!]
		source [word!]
		/local src
	][
		src: register-code source
		emit-rex code supported-wide-gpr? type src none 4
		append-byte code 137
		emit-rsp-modrm code src offset
	]

	emit-xmm-rsp-store: func [
		code [binary!]
		type [block!]
		offset [integer!]
		source [word!]
		/local src
	][
		src: xmm-register-code source
		append-byte code float-prefix type
		emit-rex code no src none 4
		append-byte code 15
		append-byte code 17
		emit-rsp-modrm code src offset
	]

	float-prefix: func [type [block!]][either type/1 = 'f32 [243][242]]

	emit-xmm-move: func [
		code [binary!]
		type [block!]
		destination [word!]
		source [word!]
		/local dst src
	][
		if destination = source [exit]
		dst: xmm-register-code destination
		src: xmm-register-code source
		append-byte code float-prefix type
		emit-rex code no dst none src
		append code #{0F10}
		emit-modrm code 192 dst src
	]

	emit-xmm-frame-load: func [
		code [binary!]
		type [block!]
		destination [word!]
		offset [integer!]
		/local dst
	][
		dst: xmm-register-code destination
		append-byte code float-prefix type
		emit-rex code no dst none 5
		append code #{0F10}
		emit-frame-modrm code dst offset
	]

	emit-xmm-frame-store: func [
		code [binary!]
		type [block!]
		offset [integer!]
		source [word!]
		/local src
	][
		src: xmm-register-code source
		append-byte code float-prefix type
		emit-rex code no src none 5
		append code #{0F11}
		emit-frame-modrm code src offset
	]

	float-binary-opcode: func [opcode [word!]][
		case [
			opcode = rs-o2-ir/add-op [88]
			opcode = rs-o2-ir/subtract-op [92]
			opcode = rs-o2-ir/multiply-op [89]
			opcode = first [/] [94]
			true [none]
		]
	]

	emit-xmm-binary: func [
		code [binary!]
		type [block!]
		opcode [word!]
		destination [word!]
		left [word!]
		right [word!]
		/local dst rhs byte swap
	][
		if all [destination = right destination <> left][
			unless rs-o2-ir/commutative-op? opcode [
				return fail-selection 'x64-float-two-address-conflict
			]
			swap: left
			left: right
			right: swap
		]
		emit-xmm-move code type destination left
		dst: xmm-register-code destination
		rhs: xmm-register-code right
		byte: float-binary-opcode opcode
		unless integer? byte [return fail-selection 'x64-float-binary-encoding]
		append-byte code float-prefix type
		emit-rex code no dst none rhs
		append-byte code 15
		append-byte code byte
		emit-modrm code 192 dst rhs
		yes
	]

	emit-xmm-binary-memory: func [
		code [binary!]
		type [block!]
		opcode [word!]
		destination [word!]
		left [word!]
		offset [integer!]
		/local dst byte
	][
		emit-xmm-move code type destination left
		dst: xmm-register-code destination
		byte: float-binary-opcode opcode
		unless integer? byte [return fail-selection 'x64-float-memory-encoding]
		append-byte code float-prefix type
		emit-rex code no dst none 5
		append-byte code 15
		append-byte code byte
		emit-frame-modrm code dst offset
		yes
	]

	spill-offset: func [id [integer!]][
		rs-o2-ir/table-value spilled-values id
	]

	spill-scratch: func [type [block!]][
		either supported-float? type [spill-xmm-scratch][spill-gpr-scratch]
	]

	materialize-value: func [
		code [binary!]
		allocation [block!]
		id [integer!]
		/local location type scratch offset
	][
		location: allocation-register allocation id
		unless location [return fail-selection 'x64-missing-allocation]
		unless location = 'spill [return location]
		type: rs-o2-ir/vreg-type id
		scratch: spill-scratch type
		offset: spill-offset id
		unless all [scratch integer? offset][return fail-selection 'x64-missing-spill-slot]
		either supported-float? type [
			emit-xmm-frame-load code type scratch offset
		][emit-gpr-frame-load code type scratch offset]
		scratch
	]

	result-register: func [allocation [block!] id [integer!] /local location type scratch][
		location: allocation-register allocation id
		unless location [return fail-selection 'x64-missing-result-allocation]
		unless location = 'spill [return location]
		type: rs-o2-ir/vreg-type id
		scratch: spill-scratch type
		any [scratch fail-selection 'x64-missing-spill-scratch]
	]

	emit-spilled-result: func [
		code [binary!]
		allocation [block!]
		id [integer! none!]
		register [word! none!]
		/local location type offset
	][
		if none? id [return yes]
		location: allocation-register allocation id
		unless location [return fail-selection 'x64-missing-result-allocation]
		unless location = 'spill [return yes]
		type: rs-o2-ir/vreg-type id
		offset: spill-offset id
		unless all [register integer? offset][return fail-selection 'x64-missing-spill-store]
		either supported-float? type [
			emit-xmm-frame-store code type offset register
		][emit-gpr-frame-store code type offset register]
		yes
	]

	emit-spill-frame-reserve: func [code [binary!] /local short?][
		if zero? spill-frame-bytes [return yes]
		short?: spill-frame-bytes <= 127
		append code either short? [#{4883EC}][#{4881EC}]
		append code either short? [
			int-to-bin/to-bin8 spill-frame-bytes
		][int-to-bin/to-bin32 spill-frame-bytes]
		yes
	]

	emit-promoted-local-loads: func [code [binary!] /local name register offset][
		foreach [name register] promoted-locals [
			if find promoted-entry-loads name [
				offset: stack-offset name
				unless integer? offset [return fail-selection 'x64-unresolved-promoted-local]
				emit-frame-load code register offset
			]
		]
		yes
	]

	emit-promoted-local-stores: func [code [binary!] /local name register offset][
		foreach [name register] promoted-locals [
			offset: stack-offset name
			unless integer? offset [return fail-selection 'x64-unresolved-promoted-local]
			emit-frame-store code offset register
		]
		yes
	]

	emit-promoted-local-reloads: func [code [binary!] /local name register offset][
		foreach [name register] promoted-locals [
			offset: stack-offset name
			unless integer? offset [return fail-selection 'x64-unresolved-promoted-local]
			emit-frame-load code register offset
		]
		yes
	]

	call-source?: func [pairs [block!] source [word!] /local position][
		position: pairs
		while [not tail? position][
			if position/1 = source [return yes]
			position: skip position 3
		]
		no
	]

	emit-call-stack-arguments: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands argument-index operand offset source type
	][
		operands: pick instruction rs-o2-ir/ins-operands
		argument-index: 0
		foreach operand next operands [
			argument-index: argument-index + 1
			offset: call-stack-argument-offset instruction argument-index
			if integer? offset [
				source: materialize-value code allocation operand/2
				unless source [return none]
				type: rs-o2-ir/vreg-type operand/2
				either supported-float? type [
					emit-xmm-rsp-store code type offset source
				][emit-gpr-rsp-store code type offset source]
			]
		]
		yes
	]

	emit-call-argument-moves: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands pairs spill-loads argument-index operand source target type position
			candidate-position scratch scratch-candidate scratch-candidates id offset
	][
		operands: pick instruction rs-o2-ir/ins-operands
		pairs: make block! 8
		spill-loads: make block! 4
		argument-index: 0
		foreach operand next operands [
			argument-index: argument-index + 1
			target: call-argument-register instruction argument-index
			if target [
				source: allocation-register allocation operand/2
				type: rs-o2-ir/vreg-type operand/2
				unless source [return fail-selection 'x64-call-argument-register]
				either source = 'spill [
					repend spill-loads [operand/2 target type]
				][
					unless source = target [repend pairs [source target type]]
				]
			]
		]
		while [not empty? pairs][
			candidate-position: none
			position: pairs
			while [not tail? position][
				target: position/2
				unless call-source? pairs target [
					candidate-position: position
					break
				]
				position: skip position 3
			]
			either candidate-position [
				source: candidate-position/1
				target: candidate-position/2
				type: candidate-position/3
				either supported-float? type [
					emit-xmm-move code type target source
				][emit-gpr-move code type target source]
				remove/part candidate-position 3
			][
				source: pairs/1
				type: pairs/3
				scratch: none
				scratch-candidates: either supported-float? type [
					either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
						[xmm5 xmm4 xmm3 xmm2 xmm1 xmm0]
					][
						[
							xmm15 xmm14 xmm13 xmm12 xmm11 xmm10 xmm9 xmm8
							xmm7 xmm6 xmm5 xmm4 xmm3 xmm2 xmm1 xmm0
						]
					]
				][
					[eax ecx edx r8d r9d r10d r11d]
				]
				foreach scratch-candidate scratch-candidates [
					unless any [
						find promoted-registers scratch-candidate
						find pairs scratch-candidate
					][
						scratch: scratch-candidate
						break
					]
				]
				unless scratch [return fail-selection 'x64-call-argument-cycle]
				either supported-float? type [
					emit-xmm-move code type scratch source
				][emit-gpr-move code type scratch source]
				poke pairs 1 scratch
			]
		]
		; Load spills after parallel copies so an ABI target cannot overwrite a
		; register that is still a source for another argument.
		foreach [id target type] spill-loads [
			offset: spill-offset id
			unless integer? offset [return fail-selection 'x64-call-argument-spill]
			either supported-float? type [
				emit-xmm-frame-load code type target offset
			][emit-gpr-frame-load code type target offset]
		]
		yes
	]

	binary-opcode: func [opcode [word!]][
		case [
			opcode = rs-o2-ir/add-op [1]
			opcode = rs-o2-ir/subtract-op [41]
			opcode = 'and [33]
			opcode = 'or [9]
			opcode = 'xor [49]
			true [none]
		]
	]

	binary-memory-opcode: func [opcode [word!]][
		case [
			opcode = rs-o2-ir/add-op [3]
			opcode = rs-o2-ir/subtract-op [43]
			opcode = 'and [35]
			opcode = 'or [11]
			opcode = 'xor [51]
			true [none]
		]
	]

	immediate-group: func [opcode [word!]][
		case [
			opcode = rs-o2-ir/add-op [0]
			opcode = 'or [1]
			opcode = 'and [4]
			opcode = rs-o2-ir/subtract-op [5]
			opcode = 'xor [6]
			true [none]
		]
	]

	immediate-use?: func [instruction [block!] index [integer!] /local opcode][
		opcode: pick instruction rs-o2-ir/ins-opcode
		any [
			all [opcode = 'return index = 1]
			all [supported-binary? opcode index = 2]
			all [rs-o2-ir/comparison-op? opcode index = 2]
			all [rs-o2-ir/commutative-op? opcode index = 1]
		]
	]

	constant-use-info: func [
		/local values candidates block instruction opcode result operands index operand found
	][
		values: make block! 8
		candidates: make block! 8
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				result: pick instruction rs-o2-ir/ins-result
				operands: pick instruction rs-o2-ir/ins-operands
				if all [opcode = 'const result][
					rs-o2-ir/set-table-value values result operands/1/2
					append candidates result
				]
			]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				index: 0
				foreach operand pick instruction rs-o2-ir/ins-operands [
					index: index + 1
					if all [operand/1 = 'vreg found: find candidates operand/2][
						unless immediate-use? instruction index [remove found]
					]
				]
			]
		]
		reduce [values candidates]
	]

	emit-binary-immediate: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left [word!]
		value [integer!]
		/local dst lhs group short?
	][
		dst: register-code destination
		lhs: register-code left
		short?: all [value >= -128 value <= 127]
		either opcode = rs-o2-ir/multiply-op [
			emit-rex code no dst none lhs
			append-byte code either short? [107][105]
			emit-modrm code 192 dst lhs
		][
			emit-mov-register code destination left
			group: immediate-group opcode
			unless integer? group [return fail-selection 'x64-immediate-encoding]
			emit-rex code no none none dst
			append-byte code either short? [131][129]
			emit-modrm code 192 group dst
		]
		append code either short? [int-to-bin/to-bin8 value][int-to-bin/to-bin32 value]
	]

	emit-binary: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left [word!]
		right [word!]
		/local dst rhs byte swap
	][
		if all [destination = right destination <> left][
			unless rs-o2-ir/commutative-op? opcode [
				return fail-selection 'x64-two-address-conflict
			]
			swap: left
			left: right
			right: swap
		]
		case [
			opcode = rs-o2-ir/add-op [
				dst: register-code destination
				rhs: register-code right
				byte: register-code left
				emit-rex code no dst rhs byte
				append-byte code 141
				emit-modrm code 0 dst 4
				append-byte code (((rhs and 7) * 8) + (byte and 7))
			]
			opcode = rs-o2-ir/multiply-op [
			emit-mov-register code destination left
			dst: register-code destination
			rhs: register-code right
			emit-rex code no dst none rhs
			append-byte code 15
			append-byte code 175
			emit-modrm code 192 dst rhs
			]
			true [
			emit-mov-register code destination left
			dst: register-code destination
			rhs: register-code right
			byte: binary-opcode opcode
			unless byte [return fail-selection 'x64-binary-encoding]
			emit-rex code no rhs none dst
			append-byte code byte
			emit-modrm code 192 rhs dst
			]
		]
	]

	emit-binary-memory: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left [word!]
		offset [integer!]
		/local dst byte
	][
		emit-mov-register code destination left
		dst: register-code destination
		either opcode = rs-o2-ir/multiply-op [
			emit-rex code no dst none 5
			append-byte code 15
			append-byte code 175
			emit-frame-modrm code dst offset
		][
			byte: binary-memory-opcode opcode
			unless byte [return fail-selection 'x64-binary-memory-encoding]
			emit-rex code no dst none 5
			append-byte code byte
			emit-frame-modrm code dst offset
		]
	]

	emit-compare-registers: func [
		code [binary!]
		left [word!]
		right [word!]
		/local lhs rhs
	][
		lhs: register-code left
		rhs: register-code right
		emit-rex code no rhs none lhs
		append-byte code 57
		emit-modrm code 192 rhs lhs
	]

	emit-compare-memory: func [
		code [binary!]
		left [word!]
		offset [integer!]
		/local lhs
	][
		lhs: register-code left
		emit-rex code no lhs none 5
		append-byte code 59
		emit-frame-modrm code lhs offset
	]

	emit-compare-memory-immediate: func [
		code [binary!]
		offset [integer!]
		value [integer!]
		/local short?
	][
		short?: all [value >= -128 value <= 127]
		append-byte code either short? [131][129]
		emit-frame-modrm code 7 offset
		append code either short? [int-to-bin/to-bin8 value][int-to-bin/to-bin32 value]
	]

	emit-direct-call: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local patch id result type source
	][
		unless emit-promoted-local-stores code [return none]
		unless emit-call-stack-arguments code instruction allocation [return none]
		unless emit-call-argument-moves code instruction allocation [return none]
		append-byte code 232
		patch: (length? code) + 1
		append code #{00000000}
		id: pick instruction rs-o2-ir/ins-id
		rs-o2-ir/set-table-value encoded-call-patches id patch
		result: pick instruction rs-o2-ir/ins-result
		if result [
			type: pick instruction rs-o2-ir/ins-type
			source: return-register type
			unless emit-spilled-result code allocation result source [return none]
		]
		unless emit-promoted-local-reloads code [return none]
		yes
	]

	emit-compare-immediate: func [
		code [binary!]
		left [word!]
		value [integer!]
		/local lhs short?
	][
		lhs: register-code left
		either zero? value [
			emit-rex code no lhs none lhs
			append-byte code 133
			emit-modrm code 192 lhs lhs
		][
			short?: all [value >= -128 value <= 127]
			emit-rex code no none none lhs
			append-byte code either short? [131][129]
			emit-modrm code 192 7 lhs
			append code either short? [int-to-bin/to-bin8 value][int-to-bin/to-bin32 value]
		]
	]

	condition-code: func [opcode [word! none!] /local code][
		code: case [
			opcode = rs-o2-ir/equal-op [4]
			opcode = rs-o2-ir/not-equal-op [5]
			opcode = rs-o2-ir/less-op [12]
			opcode = rs-o2-ir/greater-op [15]
			opcode = rs-o2-ir/less-or-equal-op [14]
			opcode = rs-o2-ir/greater-or-equal-op [13]
			true [none]
		]
		code
	]

	emit-materialized-condition: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		/local condition dst
	][
		condition: condition-code opcode
		unless integer? condition [return fail-selection 'x64-condition-code]
		dst: register-code destination
		; SETcc writes one byte; MOVZX makes the Red/System logic representation
		; an explicit 32-bit 0/1 without disturbing the comparison flags first.
		if find [esi edi] destination [append-byte code 64]
		emit-rex code no none none dst
		append-byte code 15
		append-byte code 144 + condition
		emit-modrm code 192 0 dst
		if find [esi edi] destination [append-byte code 64]
		emit-rex code no dst none dst
		append-byte code 15
		append-byte code 182
		emit-modrm code 192 dst dst
		yes
	]

	emit-near-jump: func [
		code [binary!]
		fixups [block!]
		target [integer!]
		instruction-id [integer!]
		/local patch relaxation-id
	][
		relaxation-id: (instruction-id * 2) + 1
		either find relaxed-branches relaxation-id [
			append-byte code 235
			patch: (length? code) + 1
			append-byte code 0
			append/only fixups reduce [patch target length? code 1 relaxation-id 3]
		][
			append-byte code 233
			patch: (length? code) + 1
			append code #{00000000}
			append/only fixups reduce [patch target length? code 4 relaxation-id 3]
		]
	]

	emit-near-condition: func [
		code [binary!]
		fixups [block!]
		condition [integer!]
		target [integer!]
		instruction-id [integer!]
		/local patch relaxation-id
	][
		relaxation-id: instruction-id * 2
		either find relaxed-branches relaxation-id [
			append-byte code 112 + condition
			patch: (length? code) + 1
			append-byte code 0
			append/only fixups reduce [patch target length? code 1 relaxation-id 4]
		][
			append-byte code 15
			append-byte code 128 + condition
			patch: (length? code) + 1
			append code #{00000000}
			append/only fixups reduce [patch target length? code 4 relaxation-id 4]
		]
	]

	emit-branch-control: func [
		code [binary!]
		fixups [block!]
		instruction [block!]
		next-id [integer! none!]
		/local operands metadata opcode condition true-id false-id instruction-id
	][
		operands: pick instruction rs-o2-ir/ins-operands
		metadata: pick instruction rs-o2-ir/ins-metadata
		opcode: select metadata 'condition
		condition: condition-code opcode
		unless integer? condition [return fail-selection 'x64-condition-code]
		instruction-id: pick instruction rs-o2-ir/ins-id
		true-id: operands/2/2
		false-id: operands/3/2
		case [
			true-id = false-id [
				unless true-id = next-id [emit-near-jump code fixups true-id instruction-id]
			]
			true-id = next-id [
				emit-near-condition code fixups (condition xor 1) false-id instruction-id
			]
			false-id = next-id [
				emit-near-condition code fixups condition true-id instruction-id
			]
			true [
				emit-near-condition code fixups condition true-id instruction-id
				emit-near-jump code fixups false-id instruction-id
			]
		]
		yes
	]

	patch-relative-branches: func [
		code [binary!]
		labels [block!]
		fixups [block!]
		/local fixup target displacement short-displacement
	][
		foreach fixup fixups [
			target: rs-o2-ir/table-value labels fixup/2
			unless integer? target [return fail-selection 'x64-missing-label]
			displacement: target - fixup/3
			either fixup/4 = 1 [
				unless all [displacement >= -128 displacement <= 127][
					return fail-selection 'x64-short-branch-range
				]
				change/part at code fixup/1 int-to-bin/to-bin8 displacement 1
			][
				change/part at code fixup/1 int-to-bin/to-bin32 displacement 4
				short-displacement: either target < fixup/3 [
					displacement + fixup/6
				][displacement]
				if all [
					short-displacement >= -128
					short-displacement <= 127
					not find relaxed-branches fixup/5
				][
					append relaxed-branches fixup/5
					branch-relaxation-changed?: yes
				]
			]
		]
		code
	]

	append-layout-block: func [
		id [integer!]
		blocks [block!]
		visited [block!]
		layout [block!]
		/local block instruction opcode operands successor
	][
		if find visited id [return none]
		append visited id
		block: pick blocks id
		append/only layout block
		instruction: last pick block rs-o2-ir/bb-instructions
		opcode: pick instruction rs-o2-ir/ins-opcode
		operands: pick instruction rs-o2-ir/ins-operands
		case [
			opcode = 'jump [
				append-layout-block operands/1/2 blocks visited layout
			]
			opcode = 'branch [
				append-layout-block operands/2/2 blocks visited layout
				append-layout-block operands/3/2 blocks visited layout
			]
			true [
				foreach successor pick block rs-o2-ir/bb-successors [
					append-layout-block successor blocks visited layout
				]
			]
		]
	]

	layout-current-blocks: func [/local blocks layout visited block id][
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		layout: make block! length? blocks
		visited: make block! length? blocks
		append-layout-block 1 blocks visited layout
		foreach block blocks [
			id: pick block rs-o2-ir/bb-id
			unless find visited id [append-layout-block id blocks visited layout]
		]
		layout
	]

	encode-body: func [
		allocation [block!]
		/local code blocks block block-index block-id next-block next-id last-id labels fixups
			instruction opcode operands result destination source left right offset local-register
			constant-info constant-values immediate-constants left-value right-value target
			memory-name left-memory-name memory-offset type source-type
	][
		code: make binary! 128
		clear encoded-call-patches
		clear encoded-instruction-offsets
		labels: make block! 16
		fixups: make block! 16
		constant-info: constant-use-info
		constant-values: constant-info/1
		immediate-constants: constant-info/2
		unless emit-spill-frame-reserve code [return none]
		unless emit-promoted-local-loads code [return none]
		blocks: layout-current-blocks
		last-id: pick last blocks rs-o2-ir/bb-id
		block-index: 0
		foreach block blocks [
			block-index: block-index + 1
			block-id: pick block rs-o2-ir/bb-id
			next-id: either block-index < length? blocks [
				next-block: pick blocks (block-index + 1)
				pick next-block rs-o2-ir/bb-id
			][none]
			rs-o2-ir/set-table-value labels block-id length? code
			foreach instruction pick block rs-o2-ir/bb-instructions [
				rs-o2-ir/set-table-value encoded-instruction-offsets
					pick instruction rs-o2-ir/ins-id
					length? code
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				result: pick instruction rs-o2-ir/ins-result
				type: pick instruction rs-o2-ir/ins-type
				case [
					opcode = 'const [
						unless find immediate-constants result [
							destination: result-register allocation result
							emit-mov-immediate code destination operands/1/2
							unless emit-spilled-result code allocation result destination [return none]
						]
					]
					opcode = 'copy [
						destination: result-register allocation result
						source: materialize-value code allocation operands/1/2
						unless all [destination source][return none]
						either supported-float? type [
							emit-xmm-move code type destination source
						][emit-gpr-move code type destination source]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'load-local [
						case [
							folded-load-name result []
							local-register: promoted-register operands/1/2 [
								destination: result-register allocation result
								emit-gpr-move code type destination local-register
								unless emit-spilled-result code allocation result destination [return none]
							]
							frameless? []
							true [
								destination: result-register allocation result
								offset: stack-offset operands/1/2
								either supported-float? type [
									emit-xmm-frame-load code type destination offset
								][emit-gpr-frame-load code type destination offset]
								unless emit-spilled-result code allocation result destination [return none]
							]
						]
					]
					opcode = 'store-local [
						source: materialize-value code allocation operands/2/2
						unless source [return none]
						source-type: rs-o2-ir/vreg-type operands/2/2
						local-register: promoted-register operands/1/2
						either local-register [
							emit-gpr-move code source-type local-register source
						][
							offset: stack-offset operands/1/2
							either supported-float? source-type [
								emit-xmm-frame-store code source-type offset source
							][emit-gpr-frame-store code source-type offset source]
						]
					]
					supported-binary-operation? opcode [
						destination: result-register allocation result
						unless destination [return none]
						either supported-float? type [
							left-memory-name: folded-load-name operands/1/2
							memory-name: folded-load-name operands/2/2
							memory-offset: none
							case [
								memory-name [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									memory-offset: stack-offset memory-name
									unless emit-xmm-binary-memory code type opcode destination left memory-offset [
										return none
									]
								]
								left-memory-name [
									right: materialize-value code allocation operands/2/2
									unless right [return none]
									memory-offset: stack-offset left-memory-name
									unless emit-xmm-binary-memory code type opcode destination right memory-offset [
										return none
									]
								]
								(allocation-register allocation operands/2/2) = 'spill [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									memory-offset: spill-offset operands/2/2
									unless emit-xmm-binary-memory code type opcode destination left memory-offset [
										return none
									]
								]
								true [
									left: materialize-value code allocation operands/1/2
									right: materialize-value code allocation operands/2/2
									unless all [left right][return none]
									unless emit-xmm-binary code type opcode destination left right [return none]
								]
							]
						][
							left-memory-name: folded-load-name operands/1/2
							memory-name: folded-load-name operands/2/2
							memory-offset: none
							unless memory-name [
								if (allocation-register allocation operands/2/2) = 'spill [
									memory-offset: spill-offset operands/2/2
								]
							]
							left-value: all [
								find immediate-constants operands/1/2
								rs-o2-ir/table-value constant-values operands/1/2
							]
							right-value: all [
								find immediate-constants operands/2/2
								rs-o2-ir/table-value constant-values operands/2/2
							]
							case [
								memory-name [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									memory-offset: stack-offset memory-name
									emit-binary-memory code opcode destination left memory-offset
								]
								left-memory-name [
									memory-offset: stack-offset left-memory-name
									either not none? right-value [
										emit-frame-load code destination memory-offset
										emit-binary-immediate code opcode destination destination right-value
									][
										right: materialize-value code allocation operands/2/2
										unless right [return none]
										emit-binary-memory code opcode destination right memory-offset
									]
								]
								integer? memory-offset [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									emit-binary-memory code opcode destination left memory-offset
								]
								not none? right-value [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									emit-binary-immediate code opcode destination left right-value
								]
								all [not none? left-value rs-o2-ir/commutative-op? opcode][
									right: materialize-value code allocation operands/2/2
									unless right [return none]
									emit-binary-immediate code opcode destination right left-value
								]
								true [
									left: materialize-value code allocation operands/1/2
									right: materialize-value code allocation operands/2/2
									unless all [left right][return none]
									emit-binary code opcode destination left right
								]
							]
						]
						unless emit-spilled-result code allocation result destination [return none]
					]
					rs-o2-ir/comparison-op? opcode [
						memory-name: folded-load-name operands/2/2
						memory-offset: none
						unless memory-name [
							if (allocation-register allocation operands/2/2) = 'spill [
								memory-offset: spill-offset operands/2/2
							]
						]
						left-value: all [
							find immediate-constants operands/1/2
							rs-o2-ir/table-value constant-values operands/1/2
						]
						right-value: all [
							find immediate-constants operands/2/2
							rs-o2-ir/table-value constant-values operands/2/2
						]
						case [
							all [not none? left-value memory-name] [
								memory-offset: stack-offset memory-name
								emit-compare-memory-immediate code memory-offset left-value
							]
							all [not none? left-value integer? memory-offset] [
								emit-compare-memory-immediate code memory-offset left-value
							]
							not none? left-value [
								right: materialize-value code allocation operands/2/2
								unless right [return none]
								emit-compare-immediate code right left-value
							]
							true [
								left: materialize-value code allocation operands/1/2
								unless left [return none]
								case [
									memory-name [
										memory-offset: stack-offset memory-name
										emit-compare-memory code left memory-offset
									]
									integer? memory-offset [emit-compare-memory code left memory-offset]
									not none? right-value [emit-compare-immediate code left right-value]
									true [
										right: materialize-value code allocation operands/2/2
										unless right [return none]
										emit-compare-registers code left right
									]
								]
							]
						]
						if comparison-value-used? result [
							destination: result-register allocation result
							unless destination [return none]
							unless emit-materialized-condition code opcode destination [return none]
							unless emit-spilled-result code allocation result destination [return none]
						]
					]
					opcode = 'call [
						unless emit-direct-call code instruction allocation [return none]
					]
					opcode = 'jump [
						target: operands/1/2
						unless target = next-id [
							emit-near-jump code fixups target pick instruction rs-o2-ir/ins-id
						]
					]
					opcode = 'branch [
						unless emit-branch-control code fixups instruction next-id [return none]
					]
					opcode = 'return [
						unless empty? operands [
							source-type: rs-o2-ir/vreg-type operands/1/2
							either supported-float? source-type [
								source: materialize-value code allocation operands/1/2
								unless source [return none]
								emit-xmm-move code source-type 'xmm0 source
							][
								left-value: all [
									find immediate-constants operands/1/2
									rs-o2-ir/table-value constant-values operands/1/2
								]
								either not none? left-value [
									emit-mov-immediate code 'eax left-value
								][
									source: materialize-value code allocation operands/1/2
									unless source [return none]
									emit-gpr-move code source-type 'eax source
								]
							]
						]
						if all [not frameless? block-id <> last-id][
							emit-near-jump code fixups 0 pick instruction rs-o2-ir/ins-id
						]
					]
					true [return fail-selection 'x64-unsupported-opcode]
				]
			]
		]
		rs-o2-ir/set-table-value labels 0 length? code
		patch-relative-branches code labels fixups
	]

	rewrite-debug-lines: func [
		debug-lines [block!]
		direct-chunk [block!]
		/local records files before generated after position address line source file-position file-index
			old-start old-end base offset instruction id last-address last-line last-file removed? blocks block
	][
		unless all [
			(length? debug-lines) >= 4
			block? debug-lines/2
			any-block? debug-lines/4
			(length? direct-chunk) >= 3
			integer? direct-chunk/3
		][return fail-selection 'x64-debug-line-shape]
		records: debug-lines/2
		files: debug-lines/4
		unless zero? ((length? records) // 3) [return fail-selection 'x64-debug-line-records]
		old-start: direct-chunk/3
		old-end: old-start + (length? direct-chunk/1)
		before: make block! length? records
		after: make block! length? records
		removed?: no
		position: records
		while [not tail? position][
			address: position/1
			unless integer? address [return fail-selection 'x64-debug-line-address]
			either address < old-start [
				append before copy/part position 3
			][
				either address >= old-end [
					append after copy/part position 3
				][removed?: yes]
			]
			position: skip position 3
		]
		unless removed? [return yes]
		generated: make block! 16
		base: either frameless? [
			old-start
		][old-start + (pick rs-o2-ir/current rs-o2-ir/fn-body-start)]
		last-address: none
		last-line: none
		last-file: none
		blocks: layout-current-blocks
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				id: pick instruction rs-o2-ir/ins-id
				offset: rs-o2-ir/table-value encoded-instruction-offsets id
				line: pick instruction rs-o2-ir/ins-source-line
				source: pick instruction rs-o2-ir/ins-source-file
				if all [
					integer? offset
					integer? line
					line > 0
					any [file? source string? source]
				][
					file-position: find files source
					unless file-position [
						append files source
						file-position: find files source
					]
					file-index: index? file-position
					address: base + offset
					case [
						all [integer? last-address address = last-address][
							poke generated ((length? generated) - 1) line
							poke generated (length? generated) file-index
							last-line: line
							last-file: file-index
						]
						all [integer? last-line line = last-line file-index = last-file] []
						true [
							repend generated [address line file-index]
							last-address: address
							last-line: line
							last-file: file-index
						]
					]
				]
			]
		]
		if empty? generated [return fail-selection 'x64-debug-line-map]
		clear records
		append records before
		append records generated
		append records after
		yes
	]

	apply-call-relocations: func [direct-chunk [block!] /local start id ref patch][
		if empty? call-relocations [return yes]
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		foreach [id ref] call-relocations [
			patch: rs-o2-ir/table-value encoded-call-patches id
			unless integer? patch [return fail-selection 'x64-missing-call-patch]
			ref/1: direct-chunk/3 + start + patch - 1
		]
		yes
	]

	replace-body: func [direct-chunk [block!] body [binary!] /local bytes start ending selected][
		bytes: direct-chunk/1
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		ending: pick rs-o2-ir/current rs-o2-ir/fn-body-end
		selected: copy direct-chunk
		if frameless? [
			bytes: copy body
			append-byte bytes 195
			poke selected 1 bytes
			unless apply-gc-bitmap selected [return none]
			return selected
		]
		bytes: make binary! (start + (length? body) + ((length? bytes) - ending))
		append bytes copy/part direct-chunk/1 start
		append bytes body
		append bytes skip direct-chunk/1 ending
		poke selected 1 bytes
		unless apply-gc-bitmap selected [return none]
		selected
	]

	select-current: func [direct-chunk [block!] /local intervals allocation body pass][
		unless validate-current direct-chunk [return none]
		plan-folded-loads
		intervals: build-intervals
		unless intervals [return none]
		unless plan-call-spills intervals [return none]
		allocation: allocate-intervals intervals
		unless allocation [return none]
		plan-spill-slots intervals
		unless plan-gc-metadata intervals allocation direct-chunk [return none]
		clear relaxed-branches
		repeat pass 8 [
			branch-relaxation-changed?: no
			body: encode-body allocation
			unless binary? body [return none]
			unless branch-relaxation-changed? [break]
		]
		if branch-relaxation-changed? [return fail-selection 'x64-branch-relaxation-limit]
		unless apply-call-relocations direct-chunk [return none]
		replace-body direct-chunk body
	]
]
