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
	interval-call-live: 7
	interval-call-fixed: 8

	integer-registers: [eax ecx edx r8d r9d r10d r11d]
	frameless?: no
	promoted-locals: make block! 8
	promoted-registers: make block! 4
	promoted-entry-loads: make block! 4
	loop-blocks: make block! 8
	aligned-loop-blocks: make block! 4
	folded-loads: make block! 8
	planned-relocations: make block! 8
	selected-relocation-refs: make block! 8
	dropped-relocation-refs: make block! 8
	encoded-relocation-patches: make block! 8
	encoded-instruction-offsets: make block! 16
	relaxed-branches: make block! 8
	branch-relaxation-changed?: no
	spilled-values: make block! 8
	call-spilled-values: make block! 8
	call-split-values: make block! 8
	call-split-points: make block! 8
	call-argument-locations: make block! 8
	aggregate-temp-offsets: make block! 8
	used-callee-save-registers: make block! 4
	callee-save-offsets: make block! 8
	spill-frame-bytes: 0
	outgoing-frame-bytes: 0
	fixed-shadow-frame-merge?: no
	released-call-argument-fixed?: no
	spill-gpr-scratch: none
	spill-xmm-scratch: none
	gc-bitmap-list: none
	gc-bitmap-original: none
	gc-bitmap-offset: none
	copy-cell-xmm-scratch: none
	phi-edge-copies: make block! 8
	jump-table-patches: make block! 8
	function-has-switch?: no
	function-has-pointer-arithmetic?: no
	function-needs-shift-count-register?: no
	function-needs-division-registers?: no
	function-needs-float-constant-scratch?: no
	function-needs-import-variable-scratch?: no
	function-has-atomic-memory?: no
	function-needs-atomic-value-scratch?: no
	function-needs-atomic-accumulator?: no
	function-needs-atomic-loop-scratch?: no
	function-has-custom-call?: no
	function-has-dynamic-custom-call?: no
	pointer-index-scratch: 'r11d

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

	supported-narrow-gpr?: func [type][
		all [
			rs-o2-ir/valid-type? type
			find [i8 i16] type/1
			find [1 2] type/2
			type/3 = 'gpr
		]
	]

	supported-wide-gpr?: func [type][
		to logic! all [
			rs-o2-ir/valid-type? type
			find [i64 ptr agg] type/1
			type/2 = 8
			type/3 = 'gpr
		]
	]

	supported-gpr-scalar?: func [type][
		any [supported-i32? type supported-logic? type supported-wide-gpr? type]
	]

	r11-scratch-reserved?: does [
		any [
			function-has-switch?
			function-has-pointer-arithmetic?
			function-needs-float-constant-scratch?
			function-needs-import-variable-scratch?
			function-has-custom-call?
			function-has-pack-aggregate?
			function-has-copy-aggregate?
			function-has-typed-list?
			function-has-composite-aggregate-slot?
			function-has-atomic-memory?
		]
	]

	atomic-reserved-gpr-register?: func [register [word!]][
		any [
			all [function-needs-atomic-accumulator? register = 'eax]
			all [function-needs-atomic-loop-scratch? register = 'edx]
			all [function-needs-atomic-value-scratch? register = 'r10d]
			all [function-has-atomic-memory? register = 'r11d]
		]
	]

	reserved-gpr-register?: func [register [word!]][
		any [
			all [function-needs-shift-count-register? register = 'ecx]
			all [function-needs-division-registers? find [eax ecx edx] register]
			atomic-reserved-gpr-register? register
			all [r11-scratch-reserved? register = 'r11d]
			all [function-has-dynamic-custom-call? find [r12d r13d r14d] register]
		]
	]

	callee-save-register-list: func [/local abi][
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		either abi = 'win64 [
			copy [ebx esi edi r12d r13d r14d r15d]
		][
			copy [ebx r12d r13d r14d r15d]
		]
	]

	callee-saved-register?: func [register [word!]][
		find callee-save-register-list register
	]

	take-callee-save-register: func [free [block!] /local register position][
		foreach register callee-save-register-list [
			if all [not reserved-gpr-register? register position: find free register][
				remove position
				return register
			]
		]
		none
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

	local-loaded?: func [name [word!] /local block instruction operands][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'load-local [
					operands: pick instruction rs-o2-ir/ins-operands
					if all [not empty? operands operands/1/2 = name][return yes]
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
				if find [call custom-call resolve-series] pick instruction rs-o2-ir/ins-opcode [return yes]
			]
		]
		no
	]

	function-has-fixed-shadow-space?: func [
		/local block instruction opcode operands spec
	][
		unless (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [return no]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				if find [call copy-cell resolve-node resolve-series] opcode [
					operands: pick instruction rs-o2-ir/ins-operands
					spec: all [not empty? operands select emitter/symbols operands/1/2]
					if all [
						spec
						spec/1 = 'native
						any [opcode <> 'call ((length? operands) - 1) <= 4]
					][return yes]
				]
			]
		]
		no
	]

	function-has-copy-cell?: func [/local block instruction][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'copy-cell [return yes]
			]
		]
		no
	]

	function-has-pack-aggregate?: func [/local block instruction][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'pack-aggregate [return yes]
			]
		]
		no
	]

	function-has-copy-aggregate?: func [/local block instruction][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'copy-aggregate [return yes]
			]
		]
		no
	]

	function-has-typed-list?: func [/local block instruction][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'typed-list [return yes]
			]
		]
		no
	]

	function-has-composite-aggregate-slot?: func [
		/local block instruction metadata width
	][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'load-aggregate-slot [
					metadata: pick instruction rs-o2-ir/ins-metadata
					width: all [block? metadata select metadata 'width]
					if all [integer? width none? find [1 2 4 8] width][return yes]
				]
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

	loop-has-global-store?: func [/local block instruction][
		plan-loop-blocks
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			if find loop-blocks pick block rs-o2-ir/bb-id [
				foreach instruction pick block rs-o2-ir/bb-instructions [
					if (pick instruction rs-o2-ir/ins-opcode) = 'store-global [return yes]
				]
			]
		]
		no
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

	flags-used-by-overflow-branch?: func [id [integer! none!] /local block instruction metadata condition][
		unless id [return no]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if all [
					(pick instruction rs-o2-ir/ins-opcode) = 'branch
					(pick instruction rs-o2-ir/ins-flags-in) = id
					metadata: pick instruction rs-o2-ir/ins-metadata
					condition: select metadata 'condition
					find [overflow carry] condition
				][return yes]
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
			all [
				supported-float? type
				rs-o2-ir/comparison-op? opcode
				operand-index = 2
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
		registers: either has-call? [
			callee-save-register-list
		][
			copy [r8d r9d r10d r11d]
		]
		if function-has-dynamic-custom-call? [
			foreach register [r12d r13d r14d][
				if position: find registers register [remove position]
			]
		]
		if all [not has-call? r11-scratch-reserved?][remove find registers 'r11d]
		candidates: make block! 8
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			name: pick stack-entry rs-o2-ir/stack-name
			type: pick stack-entry rs-o2-ir/stack-type
			if all [
				any [
					all [
						supported-i32? type
						(pick stack-entry rs-o2-ir/stack-gc-kind) = 'none
					]
					all [not has-call? valid-pointer-type? type]
				]
				not pick stack-entry rs-o2-ir/stack-escaped?
				integer? pick stack-entry rs-o2-ir/stack-frame-offset
				local-referenced? name
				local-loaded? name
				any [not has-call? local-written? name]
			][
				score: local-reference-score name
				if score > 1 [append/only candidates reduce [stack-entry score]]
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
			if pick stack-entry rs-o2-ir/stack-escaped? [return no]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				if find [call custom-call resolve-series] opcode [return no]
				if opcode = 'address-local [return no]
				if opcode = 'store-local [return no]
				if all [
					opcode = 'load-local
					none? argument-register operands/1/2
				][return no]
			]
		]
		yes
	]

	dense-switch-instruction?: func [
		instruction [block!]
		/local operands position count value min-value max-value span
	][
		operands: pick instruction rs-o2-ir/ins-operands
		position: next operands
		count: 0
		min-value: none
		max-value: none
		while [(length? position) > 1][
			value: position/1/2
			unless integer? value [return no]
			min-value: either none? min-value [value][min min-value value]
			max-value: either none? max-value [value][max max-value value]
			count: count + 1
			position: skip position 2
		]
		unless all [count >= 5 not negative? min-value] [return no]
		span: max-value - min-value
		all [span <= 255 (span + 1) <= (count * 2)]
	]

	frameless-single-exit-control?: func [
		/local blocks block instruction opcode return-count return-block layout saw-switch?
	][
		return-count: 0
		return-block: none
		saw-switch?: no
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				if opcode = 'switch [
					unless dense-switch-instruction? instruction [return no]
					saw-switch?: yes
				]
				if opcode = 'return [
					return-count: return-count + 1
					if return-count > 1 [return no]
					return-block: pick block rs-o2-ir/bb-id
				]
			]
		]
		unless return-count = 1 [return no]
		layout: layout-current-blocks
		all [
			saw-switch?
			not empty? layout
			(pick last layout rs-o2-ir/bb-id) = return-block
		]
	]

	available-registers: has [registers register position][
		registers: either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
			copy [eax ecx edx r8d r9d r10d r11d]
		][
			copy [eax ecx edx esi edi r8d r9d r10d r11d]
		]
		if function-has-call? [append registers callee-save-register-list]
		foreach register promoted-registers [
			if position: find registers register [remove position]
		]
		foreach register copy registers [
			if all [reserved-gpr-register? register position: find registers register][
				remove position
			]
		]
		registers
	]

	available-xmm-registers: has [registers position][
		registers: either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
			copy [xmm0 xmm1 xmm2 xmm3 xmm4 xmm5]
		][
			copy [
				xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7
				xmm8 xmm9 xmm10 xmm11 xmm12 xmm13 xmm14 xmm15
			]
		]
		if all [
			copy-cell-xmm-scratch
			position: find registers copy-cell-xmm-scratch
		][remove position]
		registers
	]

	call-argument-location: func [
		instruction [block!]
		argument-index [integer!]
		/local locations
	][
		locations: rs-o2-ir/table-value call-argument-locations
			pick instruction rs-o2-ir/ins-id
		all [
			block? locations
			argument-index >= 1
			argument-index <= length? locations
			pick locations argument-index
		]
	]

	call-argument-register: func [instruction [block!] argument-index [integer!] /local location][
		location: call-argument-location instruction argument-index
		all [word? location location]
	]

	call-stack-argument-offset: func [instruction [block!] argument-index [integer!] /local location][
		location: call-argument-location instruction argument-index
		all [integer? location location]
	]

	call-aggregate-group-at: func [groups [block!] argument-index [integer!] /local group][
		foreach group groups [
			if (select group 'start) = argument-index [return group]
		]
		none
	]

	plan-one-call-arguments: func [
		instruction [block!]
		/local operands arguments abi metadata groups locations index operand type target registers
			integer-count float-count stack-count group count classes mode class
			integer-needed float-needed registers?
	][
		operands: pick instruction rs-o2-ir/ins-operands
		arguments: next operands
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		metadata: pick instruction rs-o2-ir/ins-metadata
		groups: any [all [block? metadata select metadata 'aggregate-groups] copy []]
		locations: make block! length? arguments
		if abi = 'win64 [
			repeat index length? arguments [
				operand: pick arguments index
				type: rs-o2-ir/vreg-type operand/2
				registers: either supported-float? type [
					[xmm0 xmm1 xmm2 xmm3]
				][[ecx edx r8d r9d]]
				target: all [index <= 4 pick registers index]
				either target [append locations target][append locations (index - 1) * 8]
			]
			rs-o2-ir/set-table-value call-argument-locations
				pick instruction rs-o2-ir/ins-id locations
			return yes
		]

		integer-count: 0
		float-count: 0
		stack-count: 0
		index: 1
		while [index <= length? arguments][
			group: call-aggregate-group-at groups index
			either group [
				count: select group 'count
				classes: select group 'classes
				mode: select group 'mode
				integer-needed: 0
				float-needed: 0
				foreach class classes [
					either class = 'sse [
						float-needed: float-needed + 1
					][integer-needed: integer-needed + 1]
				]
				registers?: all [
					mode = 'register-or-stack
					(integer-count + integer-needed) <= 6
					(float-count + float-needed) <= 8
				]
				either registers? [
					foreach class classes [
						either class = 'sse [
							float-count: float-count + 1
							append locations pick [
								xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7
							] float-count
						][
							integer-count: integer-count + 1
							append locations pick [edi esi edx ecx r8d r9d] integer-count
						]
					]
				][
					loop count [
						append locations stack-count * 8
						stack-count: stack-count + 1
					]
				]
				index: index + count
			][
				operand: pick arguments index
				type: rs-o2-ir/vreg-type operand/2
				either supported-float? type [
					float-count: float-count + 1
					target: pick [xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7]
						float-count
				][
					integer-count: integer-count + 1
					target: pick [edi esi edx ecx r8d r9d] integer-count
				]
				either target [append locations target][
					append locations stack-count * 8
					stack-count: stack-count + 1
				]
				index: index + 1
			]
		]
		rs-o2-ir/set-table-value call-argument-locations
			pick instruction rs-o2-ir/ins-id locations
		yes
	]

	plan-call-argument-locations: func [/local block instruction opcode][
		clear call-argument-locations
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				if find [call copy-cell resolve-node resolve-series] opcode [
					unless plan-one-call-arguments instruction [return no]
				]
			]
		]
		yes
	]

	maximum-outgoing-frame-bytes: func [
		/local maximum abi block instruction operands argument-index operand offset
			metadata size width opcode aggregate-result? aggregate-mode temp-required?
			typed-size typed-offset
	][
		clear aggregate-temp-offsets
		typed-size: 0
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		maximum: either all [
			abi = 'win64
			function-has-call?
			not function-has-fixed-shadow-space?
		][32][0]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if find [call resolve-series] pick instruction rs-o2-ir/ins-opcode [
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
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				metadata: pick instruction rs-o2-ir/ins-metadata
				aggregate-result?: all [
					opcode = 'call
					block? metadata
					select metadata 'aggregate-result
				]
				aggregate-mode: all [aggregate-result? select metadata 'aggregate-mode]
					temp-required?: any [
						opcode = 'pack-aggregate
						opcode = 'aggregate-temp
						find [register sysv-register] aggregate-mode
				]
				if temp-required? [
					if abi = 'win64 [maximum: max maximum 32]
					maximum: round/to/ceiling maximum 16
					size: select metadata 'size
					if opcode = 'call [size: select metadata 'aggregate-size]
					rs-o2-ir/set-table-value aggregate-temp-offsets
						pick instruction rs-o2-ir/ins-id
						maximum
					maximum: maximum + round/to/ceiling size 16
				]
			]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'typed-list [
					metadata: pick instruction rs-o2-ir/ins-metadata
					size: select metadata 'size
					typed-size: max typed-size size
				]
			]
		]
		if positive? typed-size [
			if abi = 'win64 [maximum: max maximum 32]
			maximum: round/to/ceiling maximum 16
			typed-offset: maximum
			foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
				foreach instruction pick block rs-o2-ir/bb-instructions [
					if (pick instruction rs-o2-ir/ins-opcode) = 'typed-list [
						rs-o2-ir/set-table-value aggregate-temp-offsets
							pick instruction rs-o2-ir/ins-id
							typed-offset
					]
				]
			]
			maximum: maximum + round/to/ceiling typed-size 16
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

	supported-shift?: func [opcode [word!]][
		any [
			opcode = rs-o2-ir/left-shift-op
			opcode = rs-o2-ir/right-shift-op
			opcode = rs-o2-ir/unsigned-right-shift-op
		]
	]

	supported-integer-division?: func [opcode [word!]][
		rs-o2-ir/integer-division-op? opcode
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
		any [
			supported-binary? opcode
			supported-shift? opcode
			supported-integer-division? opcode
			supported-float-binary? opcode
		]
	]

	supported-conversion?: func [source [block!] target [block!]][
		any [
			all [supported-i32? source supported-float? target]
			all [supported-float? source supported-i32? target]
			all [supported-float? source supported-float? target source/1 <> target/1]
			all [supported-narrow-gpr? source supported-i32? target]
			all [supported-i32? source supported-narrow-gpr? target]
		]
	]

	constant-vreg-value: func [id [integer!] /local definition operands opcode seen][
		seen: make block! 4
		while [not find seen id][
			append seen id
			definition: rs-o2-ir/find-vreg-definition id
			unless definition [return none]
			opcode: pick definition rs-o2-ir/ins-opcode
			operands: pick definition rs-o2-ir/ins-operands
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

	signed-division-magic: func [
		divisor [integer!]
		/local odd shift
	][
		; Keep this first strength-reduction table deliberately small and audited.
		; These positive odd bases cover the date/loop divisors that dominate the
		; current generated-code profiles; all other constants retain IDIV.
		unless divisor > 1 [return none]
		odd: divisor
		shift: 0
		while [zero? (odd and 1)] [
			odd: odd / 2
			shift: shift + 1
		]
		case [
			odd = 3 [reduce [1431655766 shift]]
			odd = 5 [reduce [1717986919 shift + 1]]
			odd = 9 [reduce [954437177 shift + 1]]
			odd = 25 [reduce [1374389535 shift + 3]]
			true [none]
		]
	]

	scaled-pointer-offset: func [
		opcode [word!]
		value [integer!]
		scale [integer!]
		/local offset
	][
		unless all [scale > 0][return none]
		unless all [
			not all [value > 0 value > (2147483647 / scale)]
			not all [value < 0 value < (-2147483648 / scale)]
		][return none]
		offset: value * scale
		if opcode = rs-o2-ir/subtract-op [
			; -2147483648 cannot be negated in the Red/System integer domain;
			; let the register form handle that one representable displacement.
			if offset = -2147483648 [return none]
			offset: negate offset
		]
		offset
	]

	supported-pointer-arithmetic?: func [
		instruction [block!]
		/local opcode operands result type left-type right-type
	][
		opcode: pick instruction rs-o2-ir/ins-opcode
		operands: pick instruction rs-o2-ir/ins-operands
		result: pick instruction rs-o2-ir/ins-result
		type: pick instruction rs-o2-ir/ins-type
		unless all [
			result
			(length? operands) = 2
			operands/1/1 = 'vreg
			operands/2/1 = 'vreg
			any [opcode = rs-o2-ir/add-op opcode = rs-o2-ir/subtract-op]
		][return no]
		left-type: rs-o2-ir/vreg-type operands/1/2
		right-type: rs-o2-ir/vreg-type operands/2/2
		to logic! all [
			valid-pointer-type? type
			type = left-type
			supported-i32? right-type
			right-type/5 = 0
			type/5 > 0
		]
	]

	valid-pointer-type?: func [type][
		all [
			rs-o2-ir/valid-type? type
			type/1 = 'ptr
			type/2 = 8
			type/3 = 'gpr
		]
	]

	valid-address-base-type?: func [type][
		all [
			rs-o2-ir/valid-type? type
			type/2 = 8
			type/3 = 'gpr
			any [type/1 = 'ptr type/1 = 'agg]
		]
	]

	last-symbol-spec: func [name [word!] /local entry][
		entry: find/last emitter/symbols name
		all [entry entry/2]
	]

	return-register: func [type][
		either supported-float? type ['xmm0]['eax]
	]

	validate-call-aggregate-groups: func [
		instruction [block!]
		operands [block!]
		metadata [block!]
		/local groups arguments previous-end group start count mode classes size
			index operand type class abi
	][
		groups: select metadata 'aggregate-groups
		unless block? groups [return fail-selection 'x64-call-aggregate-groups]
		if empty? groups [return yes]
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		unless abi = 'sysv [return fail-selection 'x64-call-aggregate-group-abi]
		arguments: next operands
		previous-end: 0
		foreach group groups [
			unless block? group [return fail-selection 'x64-call-aggregate-group]
			start: select group 'start
			count: select group 'count
			mode: select group 'mode
			classes: select group 'classes
			size: select group 'size
			unless all [
				integer? start
				integer? count
				integer? size
				start > previous-end
				count > 0
				size > 0
				(start + count - 1) <= length? arguments
				find [register-or-stack stack] mode
				block? classes
				(length? classes) = count
				any [mode = 'stack size <= 16]
			][return fail-selection 'x64-call-aggregate-group]
			repeat index count [
				class: pick classes index
				operand: pick arguments (start + index - 1)
				type: rs-o2-ir/vreg-type operand/2
				unless either class = 'sse [
					supported-float? type
				][
					all [class = 'integer supported-wide-gpr? type type/1 = 'i64]
				][return fail-selection 'x64-call-aggregate-group-type]
			]
			previous-end: start + count - 1
		]
		yes
	]

	validate-operands: func [
		instruction [block!]
		/local opcode operands stack-entry name result type operand left-type right-type position
			resolver-name metadata condition-kind condition-type variadic? spec count-kind
			pointer-operation? pointer-constant shift-constant base-type value-type size width
			count count-value type-ids value
			aggregate-result? aggregate-mode aggregate-size aggregate-temp aggregate-classes definition
			hidden-argument hidden-definition hidden-operands
	][
		opcode: pick instruction rs-o2-ir/ins-opcode
		operands: pick instruction rs-o2-ir/ins-operands
		result: pick instruction rs-o2-ir/ins-result
		type: pick instruction rs-o2-ir/ins-type
		if all [
			result
			not any [
				supported-gpr-scalar? type
				supported-narrow-gpr? type
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
			not any [
				rs-o2-ir/comparison-op? opcode
				all [
					any [
						opcode = rs-o2-ir/add-op
						opcode = rs-o2-ir/subtract-op
						opcode = rs-o2-ir/multiply-op
					]
					flags-used-by-overflow-branch?
						pick instruction rs-o2-ir/ins-flags-out
				]
			]
		][return fail-selection 'x64-live-flags]
		case [
			opcode = 'const [
				unless all [
					result
					(length? operands) = 1
					operands/1/1 = 'imm
					any [
						all [
							any [
								supported-i32? type
								supported-logic? type
								supported-narrow-gpr? type
								all [supported-wide-gpr? type find [i64 ptr] type/1]
							]
							integer? operands/1/2
						]
						all [
							binary? operands/1/2
							(length? operands/1/2) = type/2
							any [
								supported-i32? type
								all [supported-wide-gpr? type find [i64 ptr] type/1]
							]
						]
						all [supported-float? type float? operands/1/2]
					]
				][return fail-selection 'x64-constant-shape]
				if supported-float? type [function-needs-float-constant-scratch?: yes]
			]
			opcode = 'copy [
				unless all [result (length? operands) = 1 operands/1/1 = 'vreg][
					return fail-selection 'x64-copy-shape
				]
			]
			opcode = 'bitcast [
				unless all [result (length? operands) = 1 operands/1/1 = 'vreg][
					return fail-selection 'x64-bitcast-shape
				]
				operand: rs-o2-ir/vreg-type operands/1/2
				unless any [
					all [
						supported-gpr-scalar? type
						supported-gpr-scalar? operand
						type/2 = operand/2
					]
					all [supported-float? type supported-i32? operand type/1 = 'f32]
					all [supported-i32? type supported-float? operand operand/1 = 'f32]
				][return fail-selection 'x64-bitcast-type]
			]
			opcode = 'convert [
				unless all [result (length? operands) = 1 operands/1/1 = 'vreg][
					return fail-selection 'x64-convert-shape
				]
				operand: rs-o2-ir/vreg-type operands/1/2
				unless all [operand supported-conversion? operand type][
					return fail-selection 'x64-convert-type
				]
			]
			opcode = 'log-b [
				unless all [result (length? operands) = 1 operands/1/1 = 'vreg][
					return fail-selection 'x64-log-b-shape
				]
				operand: rs-o2-ir/vreg-type operands/1/2
				unless all [supported-i32? type supported-i32? operand][
					return fail-selection 'x64-log-b-type
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
					(pick stack-entry rs-o2-ir/stack-type) = type
					any [
						supported-gpr-scalar? type
						supported-narrow-gpr? type
						supported-float? type
					]
					any [
						integer? pick stack-entry rs-o2-ir/stack-frame-offset
						argument-register name
					]
				][return fail-selection 'x64-unresolved-stack-offset]
			]
			opcode = 'address-local [
				unless all [
					result
					(length? operands) = 1
					operands/1/1 = 'local
					any [type/1 = 'agg valid-pointer-type? type]
				][return fail-selection 'x64-address-local-shape]
				name: operands/1/2
				stack-entry: find-stack-object name
				unless all [
					stack-entry
					integer? pick stack-entry rs-o2-ir/stack-frame-offset
				][return fail-selection 'x64-unresolved-stack-offset]
			]
			opcode = 'address-global [
				unless all [
					result
					valid-pointer-type? type
					(length? operands) = 1
					operands/1/1 = 'global
					word? operands/1/2
					spec: select emitter/symbols operands/1/2
					spec/1 = 'global
				][return fail-selection 'x64-address-global-shape]
			]
			opcode = 'address-symbol [
				unless all [
					result
					valid-pointer-type? type
					(length? operands) = 1
					operands/1/1 = 'symbol
					word? operands/1/2
					spec: last-symbol-spec operands/1/2
					spec/1 = 'native-ref
				][return fail-selection 'x64-address-symbol-shape]
			]
			opcode = 'load-aggregate-slot [
				metadata: pick instruction rs-o2-ir/ins-metadata
				width: all [block? metadata select metadata 'width]
				value-type: all [block? metadata select metadata 'class]
				unless all [
					result
					find [integer sse] value-type
					either value-type = 'sse [
						all [supported-float? type find [4 8] width type/2 = width]
					][all [supported-wide-gpr? type type/1 = 'i64]]
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'imm
					integer? operands/2/2
					width >= 1
					width <= 8
					base-type: rs-o2-ir/vreg-type operands/1/2
					valid-address-base-type? base-type
				][return fail-selection 'x64-aggregate-slot-shape]
			]
			opcode = 'pack-aggregate [
				metadata: pick instruction rs-o2-ir/ins-metadata
				size: all [block? metadata select metadata 'size]
				unless all [
					result
					type/1 = 'ptr
					integer? size
					size > 0
					(length? operands) = 1
					operands/1/1 = 'vreg
					base-type: rs-o2-ir/vreg-type operands/1/2
					valid-address-base-type? base-type
				][return fail-selection 'x64-pack-aggregate-shape]
			]
			opcode = 'aggregate-temp [
				metadata: pick instruction rs-o2-ir/ins-metadata
				size: all [block? metadata select metadata 'size]
				unless all [
					result
					type/1 = 'agg
					integer? size
					size > 0
					type/5 = size
					empty? operands
				][return fail-selection 'x64-aggregate-temp-shape]
			]
			opcode = 'typed-list [
				metadata: pick instruction rs-o2-ir/ins-metadata
				count: all [block? metadata select metadata 'count]
				size: all [block? metadata select metadata 'size]
				type-ids: all [block? metadata select metadata 'type-ids]
				unless all [
					result
					type/1 = 'ptr
					type/2 = 8
					type/5 = 24
					type/6 = 'none
					integer? count
					count >= 0
					count = length? operands
					block? type-ids
					count = length? type-ids
					integer? size
					size = (max 8 (count * 24))
				][return fail-selection 'x64-typed-list-shape]
				foreach value type-ids [
					unless integer? value [return fail-selection 'x64-typed-list-type-id]
				]
				foreach operand operands [
					unless operand/1 = 'vreg [return fail-selection 'x64-typed-list-operand]
					value-type: rs-o2-ir/vreg-type operand/2
					unless any [
						supported-gpr-scalar? value-type
						supported-narrow-gpr? value-type
						supported-float? value-type
					][return fail-selection 'x64-typed-list-type]
				]
			]
			opcode = 'keepalive [
				unless none? result [return fail-selection 'x64-keepalive-result]
				foreach operand operands [
					unless operand/1 = 'vreg [return fail-selection 'x64-keepalive-operand]
				]
			]
			opcode = 'copy-aggregate [
				metadata: pick instruction rs-o2-ir/ins-metadata
				size: all [block? metadata select metadata 'size]
				unless all [
					result
					type/1 = 'agg
					integer? size
					size > 0
					type/5 = size
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'vreg
				][return fail-selection 'x64-copy-aggregate-shape]
				left-type: rs-o2-ir/vreg-type operands/1/2
				right-type: rs-o2-ir/vreg-type operands/2/2
				unless all [
					valid-address-base-type? left-type
					valid-address-base-type? right-type
					left-type/1 = 'agg
					right-type/1 = 'agg
					left-type/5 = size
					right-type/5 = size
				][return fail-selection 'x64-copy-aggregate-type]
			]
			opcode = 'store-local [
				unless all [
					(length? operands) = 2
					operands/1/1 = 'local
					operands/2/1 = 'vreg
				][return fail-selection 'x64-store-shape]
				name: operands/1/2
				stack-entry: find-stack-object name
				operand: rs-o2-ir/vreg-type operands/2/2
				unless all [
					stack-entry
					operand = pick stack-entry rs-o2-ir/stack-type
					any [
						supported-gpr-scalar? operand
						supported-narrow-gpr? operand
						supported-float? operand
					]
					integer? pick stack-entry rs-o2-ir/stack-frame-offset
				][return fail-selection 'x64-unresolved-stack-offset]
			]
			opcode = 'load-global [
				unless all [
					result
					(length? operands) = 1
					operands/1/1 = 'global
				][return fail-selection 'x64-global-load-shape]
				spec: select emitter/symbols operands/1/2
				if all [
					spec
					spec/1 = 'import-var
					supported-float? type
				][function-needs-import-variable-scratch?: yes]
			]
			opcode = 'store-global [
				unless all [
					(length? operands) = 2
					operands/1/1 = 'global
					operands/2/1 = 'vreg
				][return fail-selection 'x64-global-store-shape]
				operand: rs-o2-ir/vreg-type operands/2/2
				unless any [
					supported-gpr-scalar? operand
					supported-narrow-gpr? operand
					supported-float? operand
				][
					return fail-selection 'x64-global-store-type
				]
				spec: select emitter/symbols operands/1/2
				if all [spec spec/1 = 'import-var][
					function-needs-import-variable-scratch?: yes
				]
			]
			opcode = 'load-indirect [
				unless all [
					result
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'imm
					integer? operands/2/2
				][return fail-selection 'x64-indirect-load-shape]
				base-type: rs-o2-ir/vreg-type operands/1/2
				unless valid-address-base-type? base-type [
					return fail-selection 'x64-indirect-base-type
				]
			]
			opcode = 'address-indirect [
				unless all [
					result
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'imm
					integer? operands/2/2
				][return fail-selection 'x64-indirect-address-shape]
				base-type: rs-o2-ir/vreg-type operands/1/2
				unless all [
					supported-wide-gpr? base-type
					base-type/1 = 'ptr
					supported-wide-gpr? type
					type/1 = 'ptr
				][return fail-selection 'x64-indirect-address-type]
			]
			opcode = 'store-indirect [
				unless all [
					none? result
					(length? operands) = 3
					operands/1/1 = 'vreg
					operands/2/1 = 'imm
					integer? operands/2/2
					operands/3/1 = 'vreg
				][return fail-selection 'x64-indirect-store-shape]
				base-type: rs-o2-ir/vreg-type operands/1/2
				value-type: rs-o2-ir/vreg-type operands/3/2
				unless valid-address-base-type? base-type [
					return fail-selection 'x64-indirect-base-type
				]
				unless any [
					supported-gpr-scalar? value-type
					supported-narrow-gpr? value-type
					supported-float? value-type
				][
					return fail-selection 'x64-indirect-store-type
				]
			]
			find [atomic-load atomic-store atomic-math atomic-cas atomic-fence] opcode [
				unless rs-o2-ir/valid-atomic-metadata? instruction [
					return fail-selection 'x64-atomic-metadata
				]
				metadata: pick instruction rs-o2-ir/ins-metadata
				if opcode <> 'atomic-fence [
					base-type: rs-o2-ir/vreg-type operands/1/2
					unless valid-pointer-type? base-type [
						return fail-selection 'x64-atomic-pointer-type
					]
					function-has-atomic-memory?: yes
				]
				if find [atomic-store atomic-math atomic-cas] opcode [
					value-type: select metadata 'value-type
					unless supported-i32? value-type [
						return fail-selection 'x64-atomic-value-type
					]
					function-needs-atomic-value-scratch?: yes
				]
				if any [
					opcode = 'atomic-cas
					all [opcode = 'atomic-math select metadata 'returns?]
				][function-needs-atomic-accumulator?: yes]
				if all [
					opcode = 'atomic-math
					select metadata 'returns?
					find [or xor and] select metadata 'operation
				][function-needs-atomic-loop-scratch?: yes]
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
				if supported-shift? opcode [
					shift-constant: constant-vreg-value operands/2/2
					unless integer? shift-constant [
						function-needs-shift-count-register?: yes
					]
				]
				if all [supported-i32? type supported-integer-division? opcode][
					function-needs-division-registers?: yes
				]
				pointer-operation?: supported-pointer-arithmetic? instruction
				if pointer-operation? [
					function-has-pointer-arithmetic?: yes
					pointer-constant: constant-vreg-value operands/2/2
					if all [
						not none? pointer-constant
						none? scaled-pointer-offset opcode pointer-constant type/5
					][return fail-selection 'x64-pointer-immediate-range]
				]
				either pointer-operation? [
					; Pointer arithmetic has its own width and scale checks above.
				][
					unless either supported-float? type [
						all [
							supported-float-binary? opcode
							left-type = type
							right-type = type
						]
					][
						all [
							supported-i32? type
							any [
								supported-binary? opcode
								supported-shift? opcode
								supported-integer-division? opcode
							]
							supported-i32? left-type
							supported-i32? right-type
							any [
								not supported-integer-division? opcode
								all [type/4 left-type/4 right-type/4]
							]
						]
					][return fail-selection 'x64-binary-type]
				]
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
				unless any [
					all [supported-i32? left-type supported-i32? right-type]
					all [supported-logic? left-type supported-logic? right-type]
					all [supported-float? left-type left-type = right-type]
					all [valid-pointer-type? left-type left-type = right-type]
				][
					return fail-selection 'x64-comparison-type
				]
			]
			opcode = 'phi [
				unless all [result not empty? operands even? length? operands][
					return fail-selection 'x64-phi-shape
				]
				position: operands
				while [not tail? position][
					unless all [
						position/1/1 = 'block
						position/2/1 = 'vreg
						(rs-o2-ir/vreg-type position/2/2) = type
					][return fail-selection 'x64-phi-input]
					position: skip position 2
				]
			]
			opcode = 'switch [
				function-has-switch?: yes
				operand: last operands
				left-type: rs-o2-ir/vreg-type operands/1/2
				unless all [
					none? result
					(length? operands) >= 4
					even? length? operands
					operands/1/1 = 'vreg
					operand/1 = 'block
					supported-i32? left-type
				][return fail-selection 'x64-switch-shape]
				position: next operands
				while [(length? position) > 1][
					unless all [
						position/1/1 = 'imm
						integer? position/1/2
						position/2/1 = 'block
					][return fail-selection 'x64-switch-case]
					position: skip position 2
				]
			]
			opcode = 'stack-push [
				unless all [
					none? result
					none? type
					(length? operands) = 1
					operands/1/1 = 'vreg
					value-type: rs-o2-ir/vreg-type operands/1/2
					any [
						supported-gpr-scalar? value-type
						supported-narrow-gpr? value-type
						supported-float? value-type
					]
				][return fail-selection 'x64-stack-push-shape]
			]
			opcode = 'stack-pop [
				unless all [
					result
					supported-i32? type
					empty? operands
				][return fail-selection 'x64-stack-pop-shape]
			]
			opcode = 'custom-call [
				function-has-custom-call?: yes
				unless rs-o2-ir/valid-custom-call-metadata? instruction [
					return fail-selection 'x64-custom-call-metadata
				]
				metadata: pick instruction rs-o2-ir/ins-metadata
				count-kind: select metadata 'count-kind
				count: select metadata 'stack-count
				unless all [
					find [static dynamic] count-kind
					integer? pick instruction rs-o2-ir/ins-stack-in
					either count-kind = 'static [
						all [
							integer? count
							count-value: constant-vreg-value operands/2/2
							integer? count-value
							count-value = count
							count >= 0
							count <= pick instruction rs-o2-ir/ins-stack-in
						]
					][none? count]
				][return fail-selection 'x64-custom-call-stack-count]
				if count-kind = 'dynamic [function-has-dynamic-custom-call?: yes]
				either (select metadata 'target-kind) = 'direct [
					spec: select emitter/symbols operands/1/2
					unless all [spec find [native import] spec/1][
						return fail-selection 'x64-custom-call-symbol
					]
				][
					base-type: rs-o2-ir/vreg-type operands/1/2
					unless valid-pointer-type? base-type [
						return fail-selection 'x64-custom-call-target
					]
				]
				unless any [
					none? type
					supported-gpr-scalar? type
					supported-narrow-gpr? type
					supported-float? type
				][return fail-selection 'x64-custom-call-result]
			]
			opcode = 'call [
				unless all [
					not empty? operands
					operands/1/1 = 'symbol
				][return fail-selection 'x64-call-shape]
				foreach operand next operands [
					unless operand/1 = 'vreg [return fail-selection 'x64-call-argument]
				]
				metadata: pick instruction rs-o2-ir/ins-metadata
				unless all [
					block? metadata
					find metadata 'variadic
					find metadata 'aggregate-result
					find metadata 'aggregate-groups
					find metadata 'aggregate-classes
				][return fail-selection 'x64-call-metadata]
				unless validate-call-aggregate-groups instruction operands metadata [return no]
				variadic?: select metadata 'variadic
				aggregate-result?: select metadata 'aggregate-result
				aggregate-classes: select metadata 'aggregate-classes
				unless all [logic? variadic? logic? aggregate-result?][
					return fail-selection 'x64-call-metadata
				]
				either aggregate-result? [
					aggregate-mode: select metadata 'aggregate-mode
					aggregate-size: select metadata 'aggregate-size
					aggregate-temp: select metadata 'aggregate-temp
					unless all [
						result
						type/1 = 'agg
						integer? aggregate-size
						aggregate-size > 0
						type/5 = aggregate-size
						find [register hidden sysv-register] aggregate-mode
					][return fail-selection 'x64-call-aggregate-result]
					either find [register sysv-register] aggregate-mode [
						unless all [aggregate-size <= 16 none? aggregate-temp][
							return fail-selection 'x64-call-aggregate-register
						]
						if aggregate-mode = 'sysv-register [
							unless all [
								(pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'sysv
								block? aggregate-classes
								(length? aggregate-classes) =
									to integer! round/ceiling (aggregate-size / 8)
							][return fail-selection 'x64-call-sysv-aggregate-classes]
							foreach value-type aggregate-classes [
								unless find [integer sse] value-type [
									return fail-selection 'x64-call-sysv-aggregate-class
								]
							]
						]
					][
						unless all [
							integer? aggregate-temp
							(length? operands) >= 2
						][return fail-selection 'x64-call-aggregate-hidden]
						definition: rs-o2-ir/find-vreg-definition aggregate-temp
						unless all [
							definition
							(pick definition rs-o2-ir/ins-opcode) = 'aggregate-temp
							(select (pick definition rs-o2-ir/ins-metadata) 'size) = aggregate-size
						][return fail-selection 'x64-call-aggregate-hidden-temp]
						hidden-argument: operands/2/2
						hidden-definition: rs-o2-ir/find-vreg-definition hidden-argument
						hidden-operands: all [
							hidden-definition
							pick hidden-definition rs-o2-ir/ins-operands
						]
						unless all [
							hidden-definition
							(pick hidden-definition rs-o2-ir/ins-opcode) = 'bitcast
							(length? hidden-operands) = 1
							hidden-operands/1/1 = 'vreg
							hidden-operands/1/2 = aggregate-temp
							valid-pointer-type? rs-o2-ir/vreg-type hidden-argument
						][return fail-selection 'x64-call-aggregate-hidden-argument]
					]
				][
					if all [result type/1 = 'agg][
						return fail-selection 'x64-call-aggregate-metadata
					]
				]
				if all [
					(pick instruction rs-o2-ir/ins-stack-in) <> 0
					aggregate-result?
				][return fail-selection 'x64-active-stack-aggregate-call]
			]
			find [resolve-node resolve-series] opcode [
				resolver-name: either opcode = 'resolve-node [
					'red>resolve-node
				]['red>resolve-series]
				unless all [
					result
					(length? operands) = 2
					operands/1/1 = 'symbol
					operands/2/1 = 'vreg
					operands/1/2 = resolver-name
					supported-wide-gpr? type
					type/1 = 'ptr
				][return fail-selection 'x64-resolver-shape]
				left-type: rs-o2-ir/vreg-type operands/2/2
				unless supported-i32? left-type [
					return fail-selection 'x64-resolver-handle-type
				]
			]
			opcode = 'copy-cell [
				unless all [
					result
					(length? operands) = 3
					operands/1 = reduce ['symbol 'red>copy-cell]
					operands/2/1 = 'vreg
					operands/3/1 = 'vreg
					supported-wide-gpr? type
					type/1 = 'ptr
				][return fail-selection 'x64-copy-cell-shape]
				left-type: rs-o2-ir/vreg-type operands/2/2
				right-type: rs-o2-ir/vreg-type operands/3/2
				unless all [
					supported-wide-gpr? left-type
					supported-wide-gpr? right-type
					left-type/1 = 'ptr
					right-type/1 = 'ptr
				][return fail-selection 'x64-copy-cell-type]
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
				][return fail-selection 'x64-branch-shape]
				metadata: pick instruction rs-o2-ir/ins-metadata
				condition-kind: select metadata 'condition
				condition-type: rs-o2-ir/vreg-type operands/1/2
				unless any [
					all [
						pick instruction rs-o2-ir/ins-flags-in
						rs-o2-ir/comparison-op? condition-kind
					]
					all [
						pick instruction rs-o2-ir/ins-flags-in
						find [overflow carry] condition-kind
						supported-i32? condition-type
					]
					all [
						none? pick instruction rs-o2-ir/ins-flags-in
						condition-kind = 'truthy
						supported-logic? condition-type
					]
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

	plan-relocations: func [
		direct-chunk [block!]
		/local ir-relocations refs relocation retained-ordinals source-ordinals ordinal
			index id kind name addend instruction opcode spec ref candidate relative start
			ending valid-symbol? matched-symbol? in-range-symbol?
	][
		clear planned-relocations
		clear selected-relocation-refs
		clear dropped-relocation-refs
		ir-relocations: pick rs-o2-ir/current rs-o2-ir/fn-relocations
		refs: direct-chunk/2
		if not empty? ir-relocations [
			unless all [(length? direct-chunk) >= 3 integer? direct-chunk/3][
				return fail-selection 'x64-relocation-base
			]
		]
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		ending: pick rs-o2-ir/current rs-o2-ir/fn-body-end
		retained-ordinals: make block! length? ir-relocations
		source-ordinals: make block! length? ir-relocations
		foreach relocation ir-relocations [
			id: relocation/1
			kind: relocation/2
			name: relocation/3
			addend: relocation/4
			ordinal: relocation/5
			unless all [
				ordinal >= 1
				none? find source-ordinals ordinal
			][return fail-selection 'x64-relocation-ordinal]
			append source-ordinals ordinal
			unless zero? addend [return fail-selection 'x64-relocation-addend]
			instruction: rs-o2-ir/find-instruction id
			unless instruction [return fail-selection 'x64-relocation-instruction]
			opcode: pick instruction rs-o2-ir/ins-opcode
			spec: either all [kind = 'rip-rel32 opcode = 'address-symbol][
				last-symbol-spec name
			][select emitter/symbols name]
			unless all [
				spec
				block? spec/3
			][return fail-selection 'x64-relocation-symbol]
			valid-symbol?: case [
				kind = 'call-rel32 [
					any [
						all [find [call custom-call] opcode find [native import] spec/1]
						all [
							opcode = 'resolve-series
							name = 'red>resolve-series
							spec/1 = 'native
						]
					]
				]
				kind = 'rip-rel32 [
					case [
						opcode = 'store-global [find [global import-var] spec/1]
						opcode = 'load-global [find [global constant import-var] spec/1]
						opcode = 'address-global [spec/1 = 'global]
						opcode = 'address-symbol [spec/1 = 'native-ref]
						find [resolve-node resolve-series] opcode [
							all [name = 'red>node-registry spec/1 = 'global]
						]
						true [no]
					]
				]
				true [no]
			]
			unless valid-symbol? [return fail-selection 'x64-relocation-symbol-type]
			; Direct lowering can register an outer call or assignment destination
			; before lowering nested operands. Match by the owning symbol list, not
			; by the IR evaluation-order ordinal.
			ref: none
			index: 0
			matched-symbol?: no
			in-range-symbol?: no
			foreach candidate refs [
				index: index + 1
				if all [
					block? candidate
					not tail? candidate
					same? head candidate spec/3
				][
					matched-symbol?: yes
					relative: candidate/1 - direct-chunk/3 + 1
					if all [relative > start relative <= ending][
						in-range-symbol?: yes
						if none? find retained-ordinals index [
							ref: candidate
							break
						]
					]
				]
			]
			unless ref [
				unless matched-symbol? [return fail-selection 'x64-relocation-symbol]
				unless in-range-symbol? [return fail-selection 'x64-relocation-range]
				return fail-selection 'x64-relocation-ordinal
			]
			append retained-ordinals index
			append/only planned-relocations reduce [id ref]
			append/only selected-relocation-refs ref
		]
		index: 0
		foreach ref refs [
			index: index + 1
			unless find retained-ordinals index [
				unless all [block? ref not tail? ref][
					return fail-selection 'x64-dropped-relocation-ref
				]
				append/only dropped-relocation-refs ref
			]
		]
		yes
	]

	validate-current: func [direct-chunk [block!] /local blocks block instruction start ending type][
		frameless?: no
		clear promoted-locals
		clear promoted-registers
		clear promoted-entry-loads
		clear loop-blocks
		clear aligned-loop-blocks
		clear folded-loads
		clear planned-relocations
		clear selected-relocation-refs
		clear dropped-relocation-refs
		clear encoded-relocation-patches
		clear spilled-values
		clear call-spilled-values
		clear call-split-values
		clear call-split-points
		clear call-argument-locations
		clear aggregate-temp-offsets
		clear used-callee-save-registers
		clear callee-save-offsets
		spill-frame-bytes: 0
		outgoing-frame-bytes: 0
		fixed-shadow-frame-merge?: no
		released-call-argument-fixed?: no
		spill-gpr-scratch: none
		spill-xmm-scratch: none
		gc-bitmap-list: none
		gc-bitmap-original: none
		gc-bitmap-offset: none
		copy-cell-xmm-scratch: none
		clear phi-edge-copies
		clear jump-table-patches
		function-has-switch?: no
		function-has-pointer-arithmetic?: no
		function-needs-shift-count-register?: no
		function-needs-division-registers?: no
		function-needs-float-constant-scratch?: no
		function-needs-import-variable-scratch?: no
		function-has-atomic-memory?: no
		function-needs-atomic-value-scratch?: no
		function-needs-atomic-accumulator?: no
		function-needs-atomic-loop-scratch?: no
		function-has-custom-call?: no
		function-has-dynamic-custom-call?: no
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
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
		if function-has-copy-cell? [
			copy-cell-xmm-scratch: either (pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'win64 [
				'xmm5
			]['xmm15]
		]
		if loop-has-global-store? [return fail-selection 'x64-global-store-loop]
		unless plan-relocations direct-chunk [return no]
		frameless?: all [
			not function-needs-shift-count-register?
			not function-needs-division-registers?
			any [
				(length? blocks) = 1
				all [function-has-switch? frameless-single-exit-control?]
			]
			frameless-eligible?
		]
		unless frameless? [plan-promoted-locals]
		yes
	]

	find-interval: func [intervals [block!] id [integer!] /local interval][
		foreach interval intervals [
			if (pick interval interval-id) = id [return interval]
		]
		none
	]

	store-target-coalescing-safe?: func [
		block [block!]
		store [block!]
		name [word!]
		result [integer!]
		/local instruction opcode operands definition-seen? store-id
	][
		definition-seen?: no
		store-id: pick store rs-o2-ir/ins-id
		foreach instruction pick block rs-o2-ir/bb-instructions [
			if (pick instruction rs-o2-ir/ins-id) = store-id [return definition-seen?]
			opcode: pick instruction rs-o2-ir/ins-opcode
			operands: pick instruction rs-o2-ir/ins-operands
			if all [
				definition-seen?
				find [load-local store-local] opcode
				not empty? operands
				operands/1/1 = 'local
				operands/1/2 = name
			][return no]
			if (pick instruction rs-o2-ir/ins-result) = result [definition-seen?: yes]
		]
		no
	]

	build-intervals: func [
		/local intervals blocks block instruction use-position definition-position operand interval
			result opcode operands preferred fixed
			store-targets register existing existing-fixed argument-index call-operand
			position predecessor terminal phi-interval phi-preferred
	][
		intervals: make block! 16
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		; Block creation order is not definition order for nested control flow:
		; a join block can be allocated before the blocks that feed its phis.
		; Seed every definition before extending intervals at their use sites.
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				result: pick instruction rs-o2-ir/ins-result
				if all [result none? folded-load-name result][
					definition-position: ((pick instruction rs-o2-ir/ins-id) * 2) + 1
					unless find-interval intervals result [
						append/only intervals reduce [
							result definition-position definition-position none none none no no
						]
					]
				]
			]
		]
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				use-position: (pick instruction rs-o2-ir/ins-id) * 2
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				either opcode = 'phi [
					position: operands
					while [not tail? position][
						predecessor: pick blocks position/1/2
						terminal: last pick predecessor rs-o2-ir/bb-instructions
						use-position: (pick terminal rs-o2-ir/ins-id) * 2
						interval: find-interval intervals position/2/2
						unless interval [return fail-selection 'x64-undefined-phi-input]
						if use-position > pick interval interval-end [
							poke interval interval-end use-position
						]
						position: skip position 2
					]
				][
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
				]
				result: pick instruction rs-o2-ir/ins-result
				if all [result none? folded-load-name result][
					definition-position: use-position + 1
					preferred: none
					fixed: none
					if opcode = 'load-local [
						fixed: either frameless? [
							preferred: argument-register operands/1/2
							either all [preferred not atomic-reserved-gpr-register? preferred][preferred][none]
						][
							promoted-register operands/1/2
						]
					]
					if find [call custom-call copy-cell resolve-node resolve-series] opcode [
						preferred: return-register pick instruction rs-o2-ir/ins-type
						unless all [preferred atomic-reserved-gpr-register? preferred][fixed: preferred]
					]
					if all [opcode = 'phi (length? operands) >= 2][
						preferred: operands/2/2
					]
					if all [
						any [
							find [copy bitcast log-b address-indirect copy-aggregate] opcode
							supported-binary-operation? opcode
						]
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
							result definition-position definition-position none preferred fixed no no
						]
					]
				]
				if find [call copy-cell resolve-node resolve-series] opcode [
					argument-index: 0
					foreach call-operand next operands [
						argument-index: argument-index + 1
						interval: find-interval intervals call-operand/2
						unless interval [return fail-selection 'x64-call-undefined-argument]
						fixed: call-argument-register instruction argument-index
						if all [
							fixed
							not find promoted-registers fixed
							not atomic-reserved-gpr-register? fixed
							not all [
								function-needs-shift-count-register?
								fixed = 'ecx
							]
							not all [
								function-needs-division-registers?
								find [eax ecx edx] fixed
							]
						][
							existing-fixed: pick interval interval-fixed
							unless existing-fixed [
								poke interval interval-fixed fixed
								poke interval interval-call-fixed yes
							]
						]
					]
				]
			]
		]
		store-targets: make block! 8
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'store-local [
					operands: pick instruction rs-o2-ir/ins-operands
					register: promoted-register operands/1/2
					result: operands/2/2
					if all [
						register
						store-target-coalescing-safe?
							block instruction operands/1/2 result
					][
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
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'return [
					operands: pick instruction rs-o2-ir/ins-operands
					unless empty? operands [
						interval: find-interval intervals operands/1/2
						if interval [
							if all [
								none? pick interval interval-fixed
								not atomic-reserved-gpr-register? (return-register rs-o2-ir/vreg-type operands/1/2)
							][
								poke interval
									interval-fixed
									return-register rs-o2-ir/vreg-type operands/1/2
							]
							poke interval
								interval-preferred
								return-register rs-o2-ir/vreg-type operands/1/2
						]
					]
				]
			]
		]
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'phi [
					phi-interval: find-interval intervals pick instruction rs-o2-ir/ins-result
					fixed: all [phi-interval pick phi-interval interval-fixed]
					phi-preferred: all [phi-interval pick phi-interval interval-preferred]
					if any [fixed phi-preferred][
						operands: pick instruction rs-o2-ir/ins-operands
						position: operands
						while [not tail? position][
							interval: find-interval intervals position/2/2
							if interval [
								if all [fixed none? pick interval interval-fixed][
									poke interval interval-fixed fixed
								]
								if all [phi-preferred none? pick interval interval-preferred][
									poke interval interval-preferred phi-preferred
								]
							]
							position: skip position 2
						]
					]
				]
			]
		]
		mark-call-live-intervals intervals
	]

	mark-call-live-intervals: func [
		intervals [block!]
		/local block instruction position interval type definition opcode
	][
		foreach interval intervals [poke interval interval-call-live no]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if find [call custom-call resolve-series] pick instruction rs-o2-ir/ins-opcode [
					position: (pick instruction rs-o2-ir/ins-id) * 2
					foreach interval intervals [
						if all [
							(pick interval interval-start) < position
							(pick interval interval-end) > position
						][poke interval interval-call-live yes]
					]
				]
			]
		]
		; ABI argument registers are profitable hints, not whole-interval
		; constraints. Keep a value that crosses an earlier call in a callee-save
		; register and move it into the ABI register at its actual call site.
		foreach interval intervals [
			if pick interval interval-call-live [
				if pick interval interval-call-fixed [
					poke interval interval-fixed none
					poke interval interval-call-fixed no
					type: rs-o2-ir/vreg-type pick interval interval-id
					if all [
						rs-o2-ir/valid-type? type
						type/3 = 'gpr
						type/6 = 'none
					][released-call-argument-fixed?: yes]
				]
				if all [
					pick interval interval-fixed
					none? find promoted-registers pick interval interval-fixed
				][poke interval interval-fixed none]
				definition: rs-o2-ir/find-vreg-definition pick interval interval-id
				opcode: all [definition pick definition rs-o2-ir/ins-opcode]
				if find [call custom-call copy-cell resolve-node resolve-series] opcode [
					; A call result is precolored only at its definition. Moving it
					; out of the ABI return register lets the remaining interval use
					; a callee-save register or a split call-boundary spill.
					poke interval interval-fixed none
				]
			]
		]
		intervals
	]

	division-register-liveness-valid?: func [
		intervals [block!]
		/local block instruction position interval fixed
	][
		unless function-needs-division-registers? [return yes]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if all [
					supported-i32? pick instruction rs-o2-ir/ins-type
					supported-integer-division? pick instruction rs-o2-ir/ins-opcode
				][
					position: (pick instruction rs-o2-ir/ins-id) * 2
					foreach interval intervals [
						fixed: pick interval interval-fixed
						if all [
							fixed
							find [eax ecx edx] fixed
							(pick interval interval-start) < position
							(pick interval interval-end) > position
						][return fail-selection 'x64-division-fixed-register-live]
					]
				]
			]
		]
		yes
	]

	plan-call-spills: func [
		intervals [block!]
		/local interval id type fixed block instruction position live
	][
		clear call-spilled-values
		clear call-split-values
		clear call-split-points
		foreach interval intervals [
			if all [
				pick interval interval-call-live
				not find promoted-registers pick interval interval-fixed
			][
				id: pick interval interval-id
				type: rs-o2-ir/vreg-type id
				unless rs-o2-ir/valid-type? type [
					return fail-selection 'x64-call-live-type
				]
				fixed: pick interval interval-fixed
				either all [
					none? fixed
					any [type/3 = 'xmm type/6 <> 'none]
				][
					append call-split-values id
				][
					if any [
						type/3 <> 'gpr
						type/6 <> 'none
						all [fixed not callee-saved-register? fixed]
					][
						append call-spilled-values id
					]
				]
			]
		]
		unless empty? call-split-values [
			foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
				foreach instruction pick block rs-o2-ir/bb-instructions [
					if find [call custom-call resolve-series] pick instruction rs-o2-ir/ins-opcode [
						position: (pick instruction rs-o2-ir/ins-id) * 2
						live: make block! 4
						foreach interval intervals [
							id: pick interval interval-id
							if all [
								find call-split-values id
								(pick interval interval-start) < position
								(pick interval interval-end) > position
							][append live id]
						]
						unless empty? live [
							rs-o2-ir/set-table-value
								call-split-points
								pick instruction rs-o2-ir/ins-id
								live
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
			register-class = 'gpr [
				copy [r11d r10d r9d r8d edx ecx eax]
			]
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
				reserved-gpr-register? candidate
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
			victim-position victim call-live?
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
			call-live?: to logic! all [
				register-class = 'gpr
				pick interval interval-call-live
				none? find call-split-values id
			]
			start: pick interval interval-start
			position: active
			while [not tail? position][
				active-interval: position/1
				either (pick active-interval interval-end) < start [
					register: pick active-interval interval-register
					unless any [find free register reserved-gpr-register? register][
						insert free register
					]
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
						either all [none? occupant reserved-gpr-register? register][
							; A fixed interval may use an otherwise reserved register while idle.
						][
							unless all [
								occupant
								none? pick occupant interval-fixed
								reserve-spill-scratch register-class intervals allocation free active
								spill-active-register active register allocation
							][return fail-selection 'x64-fixed-register-conflict]
						]
					]
				]
			][
				preferred: pick interval interval-preferred
				if preferred [
					preferred-register: either word? preferred [
						preferred
					][allocation-register allocation preferred]
					if all [
						preferred-register
						any [not call-live? callee-saved-register? preferred-register]
						free-position: find free preferred-register
					][
						register: free-position/1
						remove free-position
					]
				]
			]
			if all [none? register call-live?][
				register: take-callee-save-register free
			]
			if none? register [
				either call-live? [
					unless reserve-spill-scratch register-class intervals allocation free active [
						return fail-selection 'x64-spill-scratch
					]
					register: 'spill
				][either empty? free [
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
				][register: take free]]
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
		/local minimum stack-entry offset interval id type size name slot count total register
			fixed-shadow?
	][
		clear spilled-values
		clear used-callee-save-registers
		clear callee-save-offsets
		spill-frame-bytes: 0
		foreach register promoted-registers [
			if all [
				callee-saved-register? register
				not find used-callee-save-registers register
			][append used-callee-save-registers register]
		]
		if function-has-dynamic-custom-call? [
			foreach register [r12d r13d r14d][
				unless find used-callee-save-registers register [
					append used-callee-save-registers register
				]
			]
		]
		foreach interval intervals [
			register: pick interval interval-register
			if all [
				word? register
				register <> 'spill
				callee-saved-register? register
				not find used-callee-save-registers register
			][append used-callee-save-registers register]
		]
		minimum: -32
		foreach stack-entry pick rs-o2-ir/current rs-o2-ir/fn-stack-objects [
			offset: pick stack-entry rs-o2-ir/stack-frame-offset
			if all [integer? offset offset < minimum][minimum: offset]
		]
		fixed-shadow?: function-has-fixed-shadow-space?
		; A fixed Win64 shadow area already occupies the 32 bytes below the
		; legacy frame. Moving RSP down exposes its old high slots for O2 saves;
		; do not reserve another 48-byte gap before the first slot.
		slot: either fixed-shadow? [minimum - 8][minimum - 48]
		count: 0
		foreach register used-callee-save-registers [
			repend callee-save-offsets [register slot]
			slot: slot - 8
			count: count + 8
		]
		foreach interval intervals [
			if any [
				(pick interval interval-register) = 'spill
				find call-split-values pick interval interval-id
			][
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
		if positive? count [
			total: total + count
			unless fixed-shadow? [total: total + 48]
		]
		unless zero? total [
			spill-frame-bytes: round/to/ceiling total 16
			frameless?: no
		]
	]

	plan-fixed-shadow-frame-merge: func [
		direct-chunk [block!]
		/local bytes start prefix
	][
		fixed-shadow-frame-merge?: no
		unless all [
			positive? spill-frame-bytes
			spill-frame-bytes <= 95
			function-has-fixed-shadow-space?
			(length? direct-chunk) >= 1
			binary? direct-chunk/1
		][return yes]
		bytes: direct-chunk/1
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		unless all [
			integer? start
			start >= 4
			start <= length? bytes
		][return yes]
		prefix: copy/part at bytes (start - 3) 4
		if prefix = #{4883EC20} [fixed-shadow-frame-merge?: yes]
		yes
	]

	plan-phi-edge-copies: func [
		allocation [block!]
		/local blocks block block-id instruction result type operands position
			predecessor-id predecessor successors source existing source-location result-location
	][
		clear phi-edge-copies
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		foreach block blocks [
			block-id: pick block rs-o2-ir/bb-id
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'phi [
					result: pick instruction rs-o2-ir/ins-result
					type: pick instruction rs-o2-ir/ins-type
					result-location: allocation-register allocation result
					unless result-location [return fail-selection 'x64-phi-result-allocation]
					operands: pick instruction rs-o2-ir/ins-operands
					position: operands
					while [not tail? position][
						predecessor-id: position/1/2
						predecessor: pick blocks predecessor-id
						successors: pick predecessor rs-o2-ir/bb-successors
						unless all [(length? successors) = 1 successors/1 = block-id][
							return fail-selection 'x64-phi-critical-edge
						]
						source: position/2/2
						source-location: allocation-register allocation source
						unless source-location [return fail-selection 'x64-phi-source-allocation]
						unless all [
							source-location = result-location
							source-location <> 'spill
						][
							existing: rs-o2-ir/table-value phi-edge-copies predecessor-id
							if existing [return fail-selection 'x64-multiple-phi-edge-copies]
							rs-o2-ir/set-table-value
								phi-edge-copies
								predecessor-id
								reduce [source result copy/deep type]
						]
						position: skip position 2
					]
				]
			]
		]
		yes
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
			local-index required-local-slots word-index bit-index word bytes register
	][
		safepoints: pick rs-o2-ir/current rs-o2-ir/fn-safepoints
		clear safepoints
		root-spills: make block! 4
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if find [call custom-call resolve-series] pick instruction rs-o2-ir/ins-opcode [
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
								unless any [
									location = 'spill
									find call-split-values id
								][
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
		foreach [register offset] callee-save-offsets [
			unless all [offset < 0 zero? offset // 8][
				return fail-selection 'x64-callee-save-alignment
			]
			local-index: ((to integer! ((absolute offset) / 8)) - 5) - arg-slots
			if local-index < 0 [return fail-selection 'x64-callee-save-range]
			required-local-slots: max required-local-slots local-index + 1
			word-index: (to integer! (local-index / 31)) + 1
			while [(length? local-words) < word-index][append local-words 0]
		]
		foreach id root-spills [
			type: rs-o2-ir/vreg-type id
			unless rs-o2-ir/valid-type? type [
				return fail-selection 'x64-gc-spill-type
			]
			offset: spill-offset id
			unless all [offset < 0 zero? offset // 8][
				return fail-selection 'x64-gc-spill-alignment
			]
			local-index: ((to integer! ((absolute offset) / 8)) - 5) - arg-slots
			if local-index < 0 [return fail-selection 'x64-gc-spill-range]
			required-local-slots: max required-local-slots local-index + 1
			word-index: (to integer! (local-index / 31)) + 1
			while [(length? local-words) < word-index][append local-words 0]
			if type/6 = 'pointer [
				bit-index: local-index // 31
				word: (pick local-words word-index) and 7FFFFFFFh
				word: word or (shift/left 1 bit-index)
				poke local-words word-index word
			]
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

	find-safepoint: func [safepoints [block!] instruction-id [integer!] /local safepoint][
		foreach safepoint safepoints [
			if safepoint/1 = instruction-id [return safepoint]
		]
		none
	]

	find-safepoint-root: func [roots [block!] id [integer!] /local root][
		foreach root roots [
			if all [block? root (length? root) = 5 root/2 = id][return root]
		]
		none
	]

	verify-planned-safepoints: func [
		intervals [block!]
		/local safepoints expected block instruction opcode instruction-id position
			safepoint roots interval id type root offset
	][
		safepoints: pick rs-o2-ir/current rs-o2-ir/fn-safepoints
		expected: make block! 4
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				if find [call custom-call resolve-series] opcode [
					instruction-id: pick instruction rs-o2-ir/ins-id
					append expected instruction-id
					safepoint: find-safepoint safepoints instruction-id
					unless safepoint [return fail-selection 'x64-gc-missing-safepoint]
					roots: safepoint/2
					position: instruction-id * 2
					foreach interval intervals [
						if all [
							(pick interval interval-start) < position
							(pick interval interval-end) > position
						][
							id: pick interval interval-id
							type: rs-o2-ir/vreg-type id
							if all [rs-o2-ir/valid-type? type type/6 <> 'none][
								root: find-safepoint-root roots id
								unless root [return fail-selection 'x64-gc-missing-root]
								offset: spill-offset id
								unless all [
									integer? offset
									root/3 = 'frame
									root/4 = offset
									root/5 = type/6
								][return fail-selection 'x64-gc-root-location]
							]
						]
					]
					foreach root roots [
						id: root/2
						interval: find-interval intervals id
						unless all [
							interval
							(pick interval interval-start) < position
							(pick interval interval-end) > position
						][return fail-selection 'x64-gc-extra-root]
					]
				]
			]
		]
		foreach safepoint safepoints [
			unless find expected safepoint/1 [return fail-selection 'x64-gc-extra-safepoint]
		]
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
		select [
			eax 0 ecx 1 edx 2 ebx 3 esi 6 edi 7
			r8d 8 r9d 9 r10d 10 r11d 11
			r12d 12 r13d 13 r14d 14 r15d 15
		] register
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
		/force
		/local rex
	][
		rex: 64
		if wide? [rex: rex or 8]
		if all [reg-field reg-field >= 8][rex: rex or 4]
		if all [index-field index-field >= 8][rex: rex or 2]
		if all [base-field base-field >= 8][rex: rex or 1]
		if any [force rex <> 64][append-byte code rex]
	]

	emit-modrm: func [code [binary!] mode [integer!] reg [integer!] rm [integer!]][
		append-byte code mode + (((reg and 7) * 8) + (rm and 7))
	]

	emit-mov-immediate: func [
		code [binary!]
		destination [word!]
		value [integer! binary!]
		/local dst
	][
		dst: register-code destination
		emit-rex code no none none dst
		append-byte code 184 + (dst and 7)
		append code either binary? value [value][int-to-bin/to-bin32 value]
	]

	emit-mov-immediate-wide: func [
		code [binary!]
		destination [word!]
		value [integer! binary!]
		/local dst
	][
		dst: register-code destination
		emit-rex code yes none none dst
		append-byte code 184 + (dst and 7)
		append code either binary? value [value][int-to-bin/to-bin64 value]
	]

	flags-consumed-after?: func [instruction-id [integer!] /local block instruction][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if all [
					(pick instruction rs-o2-ir/ins-id) > instruction-id
					pick instruction rs-o2-ir/ins-flags-in
				][return yes]
			]
		]
		no
	]

	emit-constant-immediate: func [
		code [binary!]
		instruction [block!]
		destination [word!]
		value [integer! binary!]
		type [block!]
	][
		case [
			supported-wide-gpr? type [
				emit-mov-immediate-wide code destination value
			]
			all [
			supported-i32? type
			destination = 'eax
			value = 1
			empty? loop-blocks
			not flags-consumed-after? pick instruction rs-o2-ir/ins-id
			][
			append code #{31C0FFC0}                 ;-- XOR EAX,EAX / INC EAX
			]
			true [emit-mov-immediate code destination value]
		]
	]

	emit-float-constant: func [
		code [binary!]
		destination [word!]
		value [float!]
		type [block!]
		/local bytes wide? dst src
	][
		wide?: type/1 = 'f64
		bytes: either wide? [
			ieee-754/to-binary64/rev value
		][ieee-754/to-binary32/rev value]
		unless all [binary? bytes (length? bytes) = either wide? [8][4]][
			return fail-selection 'x64-float-constant-bits
		]
		src: register-code pointer-index-scratch
		emit-rex code wide? none none src
		append-byte code 184 + (src and 7)
		append code bytes

		dst: xmm-register-code destination
		append-byte code 102
		emit-rex code wide? dst none src
		append code #{0F6E}
		emit-modrm code 192 dst src
		yes
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

	emit-movsxd-register: func [
		code [binary!]
		destination [word!]
		source [word!]
		/local dst src
	][
		dst: register-code destination
		src: register-code source
		unless all [integer? dst integer? src][return fail-selection 'x64-pointer-register]
		emit-rex code yes dst none src
		append-byte code 99
		emit-modrm code 192 dst src
		yes
	]

	emit-lea-base-displacement: func [
		code [binary!]
		destination [word!]
		base [word!]
		offset [integer!]
		/local dst base-code low-base mode
	][
		dst: register-code destination
		base-code: register-code base
		unless all [integer? dst integer? base-code][return fail-selection 'x64-pointer-register]
		low-base: base-code and 7
		mode: case [
			all [zero? offset low-base <> 5] [0]
			all [offset >= -128 offset <= 127] [64]
			true [128]
		]
		emit-rex code yes dst none base-code
		append-byte code 141
		emit-modrm code mode dst either low-base = 4 [4][base-code]
		if low-base = 4 [append-byte code (32 + low-base)]
		case [
			mode = 64 [append code int-to-bin/to-bin8 offset]
			mode = 128 [append code int-to-bin/to-bin32 offset]
			true []
		]
		yes
	]

	emit-lea-indexed: func [
		code [binary!]
		destination [word!]
		base [word!]
		index [word!]
		scale [integer!]
		/local dst base-code index-code low-base scale-bits mode
	][
		dst: register-code destination
		base-code: register-code base
		index-code: register-code index
		scale-bits: select [1 0 2 1 4 2 8 3] scale
		unless all [
			integer? dst
			integer? base-code
			integer? index-code
			integer? scale-bits
			(index-code and 7) <> 4
		][return fail-selection 'x64-pointer-register]
		low-base: base-code and 7
		mode: either low-base = 5 [64][0]
		emit-rex code yes dst index-code base-code
		append-byte code 141
		emit-modrm code mode dst 4
		append-byte code (
			(scale-bits * 64) + (((index-code and 7) * 8) + low-base)
		)
		if mode = 64 [append-byte code 0]
		yes
	]

	emit-scale-pointer-index: func [
		code [binary!]
		register [word!]
		scale [integer!]
		/local reg shift short?
	][
		if scale = 1 [return yes]
		reg: register-code register
		unless integer? reg [return fail-selection 'x64-pointer-register]
		shift: select [2 1 4 2 8 3 16 4 32 5 64 6 128 7] scale
		either integer? shift [
			emit-rex code yes none none reg
			append-byte code 193
			emit-modrm code 192 4 reg
			append-byte code shift
		][
			short?: scale <= 127
			emit-rex code yes reg none reg
			append-byte code either short? [107][105]
			emit-modrm code 192 reg reg
			append code either short? [
				int-to-bin/to-bin8 scale
			][int-to-bin/to-bin32 scale]
		]
		yes
	]

	emit-pointer-arithmetic-widened: func [
		code [binary!]
		opcode [word!]
		type [block!]
		destination [word!]
		base [word!]
		scratch [word!]
		/local scale scale-bits dst src
	][
		scale: type/5
		either opcode = rs-o2-ir/add-op [
			scale-bits: select [1 0 2 1 4 2 8 3] scale
			either integer? scale-bits [
				unless emit-lea-indexed code destination base scratch scale [return none]
			][
				unless emit-scale-pointer-index code scratch scale [return none]
				unless emit-lea-indexed code destination base scratch 1 [return none]
			]
		][
			unless emit-scale-pointer-index code scratch scale [return none]
			emit-gpr-move code type destination base
			dst: register-code destination
			src: register-code scratch
			emit-rex code yes src none dst
			append-byte code 41
			emit-modrm code 192 src dst
		]
		yes
	]

	emit-pointer-arithmetic-register: func [
		code [binary!]
		opcode [word!]
		type [block!]
		right-type [block!]
		destination [word!]
		base [word!]
		index [word!]
		/local scratch
	][
		scratch: pointer-index-scratch
		either right-type/4 [
			unless emit-movsxd-register code scratch index [return none]
		][emit-mov-register code scratch index]
		emit-pointer-arithmetic-widened code opcode type destination base scratch
	]

	emit-test-register: func [code [binary!] register [word!] /local reg][
		reg: register-code register
		emit-rex code no reg none reg
		append-byte code 133
		emit-modrm code 192 reg reg
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

	emit-movsxd-frame: func [
		code [binary!]
		destination [word!]
		offset [integer!]
		/local dst
	][
		dst: register-code destination
		unless integer? dst [return fail-selection 'x64-pointer-register]
		emit-rex code yes dst none 5
		append-byte code 99
		emit-frame-modrm code dst offset
		yes
	]

	emit-pointer-arithmetic-memory: func [
		code [binary!]
		opcode [word!]
		type [block!]
		destination [word!]
		base [word!]
		offset [integer!]
		/local scratch
	][
		scratch: pointer-index-scratch
		unless emit-movsxd-frame code scratch offset [return none]
		emit-pointer-arithmetic-widened code opcode type destination base scratch
	]

	emit-frame-load: func [code [binary!] destination [word!] offset [integer!] /local dst][
		dst: register-code destination
		emit-rex code no dst none 5
		append-byte code 139
		emit-frame-modrm code dst offset
	]

	emit-frame-address: func [code [binary!] destination [word!] offset [integer!] /local dst][
		dst: register-code destination
		emit-rex code yes dst none 5
		append-byte code 141
		emit-frame-modrm code dst offset
	]

	emit-frame-store: func [code [binary!] offset [integer!] source [word!] /local src][
		src: register-code source
		emit-rex code no src none 5
		append-byte code 137
		emit-frame-modrm code src offset
	]

	emit-frame-load-wide: func [code [binary!] destination [word!] offset [integer!] /local dst][
		dst: register-code destination
		emit-rex code yes dst none 5
		append-byte code 139
		emit-frame-modrm code dst offset
	]

	emit-frame-store-wide: func [code [binary!] offset [integer!] source [word!] /local src][
		src: register-code source
		emit-rex code yes src none 5
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
		case [
			type/1 = 'i8 [
				emit-rex code no dst none 5
				append-byte code 15
				append-byte code either type/4 [190][182]
			]
			type/1 = 'i16 [
				emit-rex code no dst none 5
				append-byte code 15
				append-byte code either type/4 [191][183]
			]
			true [
				emit-rex code supported-wide-gpr? type dst none 5
				append-byte code 139
			]
		]
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
		case [
			type/1 = 'i8 [
				emit-rex/force code no src none 5
				append-byte code 136
			]
			type/1 = 'i16 [
				append-byte code 102
				emit-rex code no src none 5
				append-byte code 137
			]
			true [
				emit-rex code supported-wide-gpr? type src none 5
				append-byte code 137
			]
		]
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

	emit-rsp-adjust: func [
		code [binary!]
		subtract? [logic!]
		bytes [integer!]
		/local short?
	][
		if zero? bytes [return yes]
		unless all [bytes > 0 bytes <= 2147483647][
			return fail-selection 'x64-stack-adjustment
		]
		short?: bytes <= 127
		append code case [
			all [subtract? short?] [#{4883EC}]
			subtract? [#{4881EC}]
			short? [#{4883C4}]
			true [#{4881C4}]
		]
		append code either short? [
			int-to-bin/to-bin8 bytes
		][int-to-bin/to-bin32 bytes]
		yes
	]

	emit-push-register: func [code [binary!] source [word!] /local src][
		src: register-code source
		unless integer? src [return fail-selection 'x64-stack-register]
		emit-rex code no none none src
		append-byte code 80 + (src and 7)
		yes
	]

	emit-pop-register: func [code [binary!] destination [word!] /local dst][
		dst: register-code destination
		unless integer? dst [return fail-selection 'x64-stack-register]
		emit-rex code no none none dst
		append-byte code 88 + (dst and 7)
		yes
	]

	emit-gpr-rsp-load-wide: func [
		code [binary!]
		destination [word!]
		offset [integer!]
		/local dst
	][
		dst: register-code destination
		emit-rex code yes dst none 4
		append-byte code 139
		emit-rsp-modrm code dst offset
	]

	emit-gpr-rsp-load32: func [
		code [binary!]
		destination [word!]
		offset [integer!]
		/local dst
	][
		dst: register-code destination
		emit-rex code no dst none 4
		append-byte code 139
		emit-rsp-modrm code dst offset
	]

	emit-gpr-rsp-store32: func [
		code [binary!]
		offset [integer!]
		source [word!]
		/local src
	][
		src: register-code source
		emit-rex code no src none 4
		append-byte code 137
		emit-rsp-modrm code src offset
	]

	emit-rsp-immediate32-store: func [
		code [binary!]
		offset [integer!]
		value [integer!]
	][
		append-byte code 199
		emit-rsp-modrm code 0 offset
		append code int-to-bin/to-bin32 value
	]

	emit-gpr-rsp-store: func [
		code [binary!]
		type [block!]
		offset [integer!]
		source [word!]
		/local src
	][
		src: register-code source
		;-- Scalar ABI stack arguments occupy eight-byte slots. A full-slot store
		;-- also forwards to the callee's qword slot copy without a width mismatch.
		emit-rex code yes src none 4
		append-byte code 137
		emit-rsp-modrm code src offset
	]

	emit-aggregate-rsp-store: func [
		code [binary!]
		width [integer!]
		offset [integer!]
		source [word!]
		/local src
	][
		if width = 8 [
			emit-gpr-rsp-store code rs-o2-ir/make-type 'i64 8 'gpr no 0 'none offset source
			return yes
		]
		src: register-code source
		if width = 2 [append-byte code 102]
		emit-rex code no src none 4
		append-byte code either width = 1 [136][137]
		emit-rsp-modrm code src offset
		yes
	]

	emit-rsp-address: func [
		code [binary!]
		destination [word!]
		offset [integer!]
		/local dst
	][
		dst: register-code destination
		emit-rex code yes dst none 4
		append-byte code 141
		emit-rsp-modrm code dst offset
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

	emit-xmm-to-gpr-bits: func [
		code [binary!]
		type [block!]
		destination [word!]
		source [word!]
		/local dst src
	][
		dst: register-code destination
		src: xmm-register-code source
		append-byte code 102
		emit-rex code type/1 = 'f64 src none dst
		append code #{0F7E}
		emit-modrm code 192 src dst
	]

	emit-gpr-to-xmm-bits: func [
		code [binary!]
		type [block!]
		destination [word!]
		source [word!]
		/local dst src
	][
		dst: xmm-register-code destination
		src: register-code source
		append-byte code 102
		emit-rex code type/1 = 'f64 dst none src
		append code #{0F6E}
		emit-modrm code 192 dst src
	]

	emit-normalize-narrow-register: func [
		code [binary!]
		type [block!]
		destination [word!]
		source [word!]
		/local dst src opcode
	][
		unless supported-narrow-gpr? type [
			return fail-selection 'x64-narrow-conversion-type
		]
		dst: register-code destination
		src: register-code source
		either type/2 = 1 [
			emit-rex/force code no dst none src
			opcode: either type/4 [190][182]       ;-- MOVSX/MOVZX r32, r8
		][
			emit-rex code no dst none src
			opcode: either type/4 [191][183]       ;-- MOVSX/MOVZX r32, r16
		]
		append-byte code 15
		append-byte code opcode
		emit-modrm code 192 dst src
		yes
	]

	emit-scalar-conversion: func [
		code [binary!]
		target-type [block!]
		destination [word!]
		source-type [block!]
		source [word!]
		/local dst src
	][
		case [
			all [supported-i32? target-type supported-narrow-gpr? source-type][
				unless emit-normalize-narrow-register
					code source-type destination source
				[return none]
			]
			all [supported-narrow-gpr? target-type supported-i32? source-type][
				unless emit-normalize-narrow-register
					code target-type destination source
				[return none]
			]
			all [supported-float? target-type supported-i32? source-type][
				dst: xmm-register-code destination
				src: register-code source
				append-byte code float-prefix target-type
				emit-rex code no dst none src
				append code #{0F2A}
				emit-modrm code 192 dst src
			]
			all [supported-i32? target-type supported-float? source-type][
				dst: register-code destination
				src: xmm-register-code source
				append-byte code float-prefix source-type
				emit-rex code no dst none src
				append code #{0F2C}
				emit-modrm code 192 dst src
			]
			all [supported-float? target-type supported-float? source-type][
				dst: xmm-register-code destination
				src: xmm-register-code source
				append-byte code float-prefix source-type
				emit-rex code no dst none src
				append code #{0F5A}
				emit-modrm code 192 dst src
			]
			true [return fail-selection 'x64-convert-encoding]
		]
		yes
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

	emit-pointer-displacement-modrm: func [
		code [binary!]
		reg [integer!]
		base [integer!]
		offset [integer!]
		/local low-base mode
	][
		low-base: base and 7
		mode: case [
			all [zero? offset low-base <> 5] [0]
			all [offset >= -128 offset <= 127] [64]
			true [128]
		]
		emit-modrm code mode reg either low-base = 4 [4][base]
		if low-base = 4 [append-byte code (32 + low-base)]
		case [
			mode = 64 [append code int-to-bin/to-bin8 offset]
			mode = 128 [append code int-to-bin/to-bin32 offset]
			true []
		]
	]

	emit-pointer-modrm: func [code [binary!] reg [integer!] base [integer!]][
		emit-pointer-displacement-modrm code reg base 0
	]

	emit-gpr-pointer-load: func [
		code [binary!]
		type [block!]
		destination [word!]
		base [word!]
		offset [integer!]
		/local dst src
	][
		dst: register-code destination
		src: register-code base
		case [
			type/1 = 'logic [
				emit-rex code no dst none src
				append code #{0FB6}
			]
			type/1 = 'i8 [
				emit-rex code no dst none src
				append-byte code 15
				append-byte code either type/4 [190][182]
			]
			type/1 = 'i16 [
				emit-rex code no dst none src
				append-byte code 15
				append-byte code either type/4 [191][183]
			]
			true [
				emit-rex code supported-wide-gpr? type dst none src
				append-byte code 139
			]
		]
		emit-pointer-displacement-modrm code dst src offset
	]

	emit-aggregate-slot-load: func [
		code [binary!]
		width [integer!]
		destination [word!]
		base [word!]
		offset [integer!]
		/local dst src type lower-width upper-width shift
	][
		case [
			width = 8 [
				type: rs-o2-ir/make-type 'i64 8 'gpr no 0 'none
				emit-gpr-pointer-load code type destination base offset
			]
			width = 4 [
				type: rs-o2-ir/make-type 'i32 4 'gpr no 0 'none
				emit-gpr-pointer-load code type destination base offset
			]
			find [1 2] width [
				dst: register-code destination
				src: register-code base
				emit-rex code no dst none src
				append-byte code 15
				append-byte code either width = 1 [182][183]
				emit-pointer-displacement-modrm code dst src offset
			]
			all [width >= 3 width <= 7][
				unless all [destination <> 'r11d base <> 'r11d][
					return fail-selection 'x64-aggregate-slot-scratch
				]
				lower-width: either width = 3 [2][4]
				upper-width: case [
					find [3 5] width [2]
					find [6 7] width [4]
				]
				unless emit-aggregate-slot-load
					code upper-width 'r11d base (offset + width - upper-width)
				[return none]
				unless emit-aggregate-slot-load
					code lower-width destination base offset
				[return none]
				shift: (width - upper-width) * 8
				dst: register-code 'r11d
				emit-rex code yes none none dst
				append-byte code 193
				emit-modrm code 192 4 dst
				append-byte code shift
				src: register-code 'r11d
				dst: register-code destination
				emit-rex code yes src none dst
				append-byte code 9
				emit-modrm code 192 src dst
			]
			true [return fail-selection 'x64-aggregate-slot-width]
		]
		yes
	]

	emit-gpr-pointer-store: func [
		code [binary!]
		type [block!]
		base [word!]
		offset [integer!]
		source [word!]
		/local dst src
	][
		dst: register-code base
		src: register-code source
		case [
			find [i8 logic] type/1 [
				emit-rex/force code no src none dst
				append-byte code 136
			]
			type/1 = 'i16 [
				append-byte code 102
				emit-rex code no src none dst
				append-byte code 137
			]
			true [
				emit-rex code supported-wide-gpr? type src none dst
				append-byte code 137
			]
		]
		emit-pointer-displacement-modrm code src dst offset
	]

	emit-atomic-memory-register: func [
		code [binary!]
		opcode [word!]
		base [word!]
		source [word!]
		/local base-code source-code byte
	][
		byte: select [add 1 sub 41 or 9 xor 49 and 33] opcode
		base-code: register-code base
		source-code: register-code source
		unless all [integer? byte integer? base-code integer? source-code][
			return fail-selection 'x64-atomic-math-encoding
		]
		append-byte code 240                         ;-- LOCK
		emit-rex code no source-code none base-code
		append-byte code byte
		emit-pointer-modrm code source-code base-code
		yes
	]

	emit-atomic-xadd: func [
		code [binary!]
		base [word!]
		source [word!]
		/local base-code source-code
	][
		base-code: register-code base
		source-code: register-code source
		unless all [integer? base-code integer? source-code][
			return fail-selection 'x64-atomic-xadd-register
		]
		append-byte code 240                         ;-- LOCK
		emit-rex code no source-code none base-code
		append code #{0FC1}
		emit-pointer-modrm code source-code base-code
		yes
	]

	emit-atomic-cmpxchg: func [
		code [binary!]
		base [word!]
		source [word!]
		/local base-code source-code
	][
		base-code: register-code base
		source-code: register-code source
		unless all [integer? base-code integer? source-code][
			return fail-selection 'x64-atomic-cmpxchg-register
		]
		append-byte code 240                         ;-- LOCK
		emit-rex code no source-code none base-code
		append code #{0FB1}
		emit-pointer-modrm code source-code base-code
		yes
	]

	emit-neg-register: func [code [binary!] register [word!] /local value][
		value: register-code register
		unless integer? value [return fail-selection 'x64-neg-register]
		emit-rex code no none none value
		append-byte code 247
		emit-modrm code 192 3 value
		yes
	]

	emit-xmm-scalar-pointer-load: func [
		code [binary!]
		type [block!]
		destination [word!]
		base [word!]
		offset [integer!]
		/local dst src
	][
		dst: xmm-register-code destination
		src: register-code base
		append-byte code float-prefix type
		emit-rex code no dst none src
		append code #{0F10}
		emit-pointer-displacement-modrm code dst src offset
	]

	emit-xmm-scalar-pointer-store: func [
		code [binary!]
		type [block!]
		base [word!]
		offset [integer!]
		source [word!]
		/local dst src
	][
		dst: register-code base
		src: xmm-register-code source
		append-byte code float-prefix type
		emit-rex code no src none dst
		append code #{0F11}
		emit-pointer-displacement-modrm code src dst offset
	]

	emit-xmm-pointer-load: func [
		code [binary!]
		destination [word!]
		base [word!]
		/local dst src
	][
		dst: xmm-register-code destination
		src: register-code base
		emit-rex code no dst none src
		append code #{0F10}                       ;-- MOVUPS xmm, [base]
		emit-pointer-modrm code dst src
	]

	emit-xmm-pointer-store: func [
		code [binary!]
		base [word!]
		source [word!]
		/local dst src
	][
		dst: register-code base
		src: xmm-register-code source
		emit-rex code no src none dst
		append code #{0F11}                       ;-- MOVUPS [base], xmm
		emit-pointer-modrm code src dst
	]

	emit-rip-load: func [
		code [binary!]
		type [block!]
		destination [word!]
		/local dst patch
	][
		either supported-float? type [
			dst: xmm-register-code destination
			append-byte code float-prefix type
			emit-rex code no dst none 5
			append code #{0F10}
		][either type/1 = 'logic [
			dst: register-code destination
			emit-rex code no dst none 5
			append code #{0FB6}
		][either type/1 = 'i8 [
			dst: register-code destination
			emit-rex code no dst none 5
			append-byte code 15
			append-byte code either type/4 [190][182]
		][either type/1 = 'i16 [
			dst: register-code destination
			emit-rex code no dst none 5
			append-byte code 15
			append-byte code either type/4 [191][183]
		][
			dst: register-code destination
			emit-rex code supported-wide-gpr? type dst none 5
			append-byte code 139
		]]]]
		emit-modrm code 0 dst 5
		patch: (length? code) + 1
		append code #{00000000}
		patch
	]

	emit-rip-address: func [
		code [binary!]
		destination [word!]
		/local dst patch
	][
		dst: register-code destination
		unless integer? dst [return fail-selection 'x64-address-symbol-register]
		emit-rex code yes dst none 5
		append-byte code 141                       ;-- LEA r64, [RIP+disp32]
		emit-modrm code 0 dst 5
		patch: (length? code) + 1
		append code #{00000000}
		patch
	]

	emit-rip-store: func [
		code [binary!]
		type [block!]
		source [word!]
		/local src patch
	][
		either supported-float? type [
			src: xmm-register-code source
			append-byte code float-prefix type
			emit-rex code no src none 5
			append code #{0F11}
		][either any [type/1 = 'logic type/1 = 'i8][
			src: register-code source
			emit-rex/force code no src none 5
			append-byte code 136
		][either type/1 = 'i16 [
			src: register-code source
			append-byte code 102
			emit-rex code no src none 5
			append-byte code 137
		][
			src: register-code source
			emit-rex code supported-wide-gpr? type src none 5
			append-byte code 137
		]]]
		emit-modrm code 0 src 5
		patch: (length? code) + 1
		append code #{00000000}
		patch
	]

	emit-import-variable-address: func [
		code [binary!]
		destination [word!]
		/local pointer-type
	][
		pointer-type: rs-o2-ir/make-type 'ptr 8 'gpr no 1 'none
		emit-rip-load code pointer-type destination
	]

	record-encoded-relocation-patch: func [
		instruction-id [integer!]
		patch [integer!]
		/local patches
	][
		patches: rs-o2-ir/table-value encoded-relocation-patches instruction-id
		either patches [
			append patches patch
		][
			rs-o2-ir/set-table-value
				encoded-relocation-patches
				instruction-id
				reduce [patch]
		]
		patch
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

	materialize-value-into: func [
		code [binary!]
		allocation [block!]
		id [integer!]
		destination [word!]
		/local location type offset
	][
		location: allocation-register allocation id
		unless location [return fail-selection 'x64-missing-atomic-allocation]
		type: rs-o2-ir/vreg-type id
		unless all [rs-o2-ir/valid-type? type type/3 = 'gpr][
			return fail-selection 'x64-atomic-register-type
		]
		either location = 'spill [
			offset: spill-offset id
			unless integer? offset [return fail-selection 'x64-missing-atomic-spill]
			emit-gpr-frame-load code type destination offset
		][emit-gpr-move code type destination location]
		yes
	]

	emit-atomic-instruction: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local opcode operands result type metadata operation old? returns? value-type destination source
			loop-start displacement
	][
		opcode: pick instruction rs-o2-ir/ins-opcode
		operands: pick instruction rs-o2-ir/ins-operands
		result: pick instruction rs-o2-ir/ins-result
		type: pick instruction rs-o2-ir/ins-type
		metadata: pick instruction rs-o2-ir/ins-metadata
		operation: select metadata 'operation
		old?: select metadata 'old?
		returns?: select metadata 'returns?
		value-type: select metadata 'value-type
		case [
			opcode = 'atomic-fence [append code #{0FAEF0}]
			opcode = 'atomic-load [
				unless materialize-value-into code allocation operands/1/2 'r11d [return none]
				destination: result-register allocation result
				unless destination [return none]
				emit-gpr-pointer-load code type destination 'r11d 0
				unless emit-spilled-result code allocation result destination [return none]
			]
			opcode = 'atomic-store [
				unless materialize-value-into code allocation operands/1/2 'r11d [return none]
				unless materialize-value-into code allocation operands/2/2 'r10d [return none]
				emit-gpr-pointer-store code value-type 'r11d 0 'r10d
				append code #{0FAEF0}                    ;-- MFENCE
			]
			opcode = 'atomic-math [
				unless materialize-value-into code allocation operands/1/2 'r11d [return none]
				unless materialize-value-into code allocation operands/2/2 'r10d [return none]
				case [
					not returns? [
						unless emit-atomic-memory-register code operation 'r11d 'r10d [return none]
					]
					find [add sub] operation [
						emit-mov-register code 'eax 'r10d
						if operation = 'sub [unless emit-neg-register code 'eax [return none]]
						unless emit-atomic-xadd code 'r11d 'eax [return none]
						source: 'eax
						unless old? [
							unless emit-binary
								code either operation = 'add [rs-o2-ir/add-op][rs-o2-ir/subtract-op]
								'eax 'eax 'r10d
							[return none]
						]
						destination: result-register allocation result
						unless destination [return none]
						emit-gpr-move code type destination source
						unless emit-spilled-result code allocation result destination [return none]
					]
					true [
						emit-gpr-pointer-load code value-type 'eax 'r11d 0
						loop-start: length? code
						emit-mov-register code 'edx 'eax
						unless emit-binary code operation 'edx 'edx 'r10d [return none]
						unless emit-atomic-cmpxchg code 'r11d 'edx [return none]
						append-byte code 117                  ;-- JNE retry
						displacement: loop-start - ((length? code) + 1)
						unless all [displacement >= -128 displacement <= 127][
							return fail-selection 'x64-atomic-loop-range
						]
						append code int-to-bin/to-bin8 displacement
						source: either old? ['eax]['edx]
						destination: result-register allocation result
						unless destination [return none]
						emit-gpr-move code type destination source
						unless emit-spilled-result code allocation result destination [return none]
					]
				]
			]
			opcode = 'atomic-cas [
				unless materialize-value-into code allocation operands/1/2 'r11d [return none]
				unless materialize-value-into code allocation operands/2/2 'eax [return none]
				unless materialize-value-into code allocation operands/3/2 'r10d [return none]
				unless emit-atomic-cmpxchg code 'r11d 'r10d [return none]
				if returns? [
					destination: result-register allocation result
					unless destination [return none]
					emit-set-condition code 4 destination
					unless emit-spilled-result code allocation result destination [return none]
				]
			]
			true [return fail-selection 'x64-atomic-opcode]
		]
		yes
	]

	emit-phi-edge-copy: func [
		code [binary!]
		allocation [block!]
		block-id [integer!]
		/local copy-info source destination type
	][
		copy-info: rs-o2-ir/table-value phi-edge-copies block-id
		unless copy-info [return yes]
		source: materialize-value code allocation copy-info/1
		destination: result-register allocation copy-info/2
		unless all [source destination][return none]
		type: copy-info/3
		either supported-float? type [
			emit-xmm-move code type destination source
		][emit-gpr-move code type destination source]
		emit-spilled-result code allocation copy-info/2 destination
	]

	emit-spill-frame-reserve: func [code [binary!] /local short?][
		if all [
			(pick rs-o2-ir/current rs-o2-ir/fn-abi) = 'sysv
			function-has-call?
		][
			; The legacy SysV emitter can enter native functions with either stack
			; parity. Align once here so every selected outgoing call satisfies the
			; ABI without per-call stack adjustments.
			append code #{4883E4F0}
		]
		if fixed-shadow-frame-merge? [return yes]
		if zero? spill-frame-bytes [return yes]
		short?: spill-frame-bytes <= 127
		append code either short? [#{4883EC}][#{4881EC}]
		append code either short? [
			int-to-bin/to-bin8 spill-frame-bytes
		][int-to-bin/to-bin32 spill-frame-bytes]
		yes
	]

	emit-callee-save-registers: func [code [binary!] /local register offset][
		foreach [register offset] callee-save-offsets [
			unless integer? offset [return fail-selection 'x64-callee-save-offset]
			emit-frame-store-wide code offset register
		]
		yes
	]

	emit-callee-restore-registers: func [code [binary!] /local register offset][
		foreach [register offset] callee-save-offsets [
			unless integer? offset [return fail-selection 'x64-callee-save-offset]
			emit-frame-load-wide code register offset
		]
		yes
	]

	emit-promoted-local-loads: func [
		code [binary!]
		/local name register offset stack-entry type
	][
		foreach [name register] promoted-locals [
			if find promoted-entry-loads name [
				offset: stack-offset name
				stack-entry: find-stack-object name
				unless all [integer? offset stack-entry][
					return fail-selection 'x64-unresolved-promoted-local
				]
				type: pick stack-entry rs-o2-ir/stack-type
				emit-gpr-frame-load code type register offset
			]
		]
		yes
	]

	emit-promoted-local-stores: func [
		code [binary!]
		/local name register offset stack-entry type
	][
		foreach [name register] promoted-locals [
			unless callee-saved-register? register [
				offset: stack-offset name
				stack-entry: find-stack-object name
				unless all [integer? offset stack-entry][
					return fail-selection 'x64-unresolved-promoted-local
				]
				type: pick stack-entry rs-o2-ir/stack-type
				emit-gpr-frame-store code type offset register
			]
		]
		yes
	]

	emit-promoted-local-reloads: func [
		code [binary!]
		/local name register offset stack-entry type
	][
		foreach [name register] promoted-locals [
			unless callee-saved-register? register [
				offset: stack-offset name
				stack-entry: find-stack-object name
				unless all [integer? offset stack-entry][
					return fail-selection 'x64-unresolved-promoted-local
				]
				type: pick stack-entry rs-o2-ir/stack-type
				emit-gpr-frame-load code type register offset
			]
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

	emit-pack-aggregate: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local offset operands source result destination metadata size qwords remainder
			copy-offset width index
	][
		offset: rs-o2-ir/table-value aggregate-temp-offsets
			pick instruction rs-o2-ir/ins-id
		unless integer? offset [return fail-selection 'x64-pack-aggregate-offset]
		operands: pick instruction rs-o2-ir/ins-operands
		source: materialize-value code allocation operands/1/2
		unless source [return none]
		metadata: pick instruction rs-o2-ir/ins-metadata
		size: select metadata 'size
		qwords: to integer! (size / 8)
		copy-offset: 0
		repeat index qwords [
			unless emit-aggregate-slot-load code 8 'r11d source copy-offset [return none]
			emit-aggregate-rsp-store code 8 (offset + copy-offset) 'r11d
			copy-offset: copy-offset + 8
		]
		remainder: size // 8
		foreach width [4 2 1] [
			if remainder >= width [
				unless emit-aggregate-slot-load code width 'r11d source copy-offset [return none]
				emit-aggregate-rsp-store code width (offset + copy-offset) 'r11d
				copy-offset: copy-offset + width
				remainder: remainder - width
			]
		]
		result: pick instruction rs-o2-ir/ins-result
		destination: result-register allocation result
		unless destination [return none]
		emit-rsp-address code destination offset
		emit-spilled-result code allocation result destination
	]

	emit-aggregate-temp: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local offset result destination
	][
		offset: rs-o2-ir/table-value aggregate-temp-offsets
			pick instruction rs-o2-ir/ins-id
		unless integer? offset [return fail-selection 'x64-aggregate-temp-offset]
		result: pick instruction rs-o2-ir/ins-result
		destination: result-register allocation result
		unless destination [return none]
		emit-rsp-address code destination offset
		emit-spilled-result code allocation result destination
	]

	emit-typed-list: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local offset operands metadata type-ids index operand source type record-offset
			result destination
	][
		offset: rs-o2-ir/table-value aggregate-temp-offsets
			pick instruction rs-o2-ir/ins-id
		unless integer? offset [return fail-selection 'x64-typed-list-offset]
		operands: pick instruction rs-o2-ir/ins-operands
		metadata: pick instruction rs-o2-ir/ins-metadata
		type-ids: select metadata 'type-ids
		index: 0
		foreach operand operands [
			index: index + 1
			record-offset: offset + ((index - 1) * 24)
			emit-rsp-immediate32-store code record-offset pick type-ids index
			emit-rsp-immediate32-store code (record-offset + 4) 0
			source: materialize-value code allocation operand/2
			unless source [return none]
			type: rs-o2-ir/vreg-type operand/2
			either supported-float? type [
				emit-xmm-rsp-store code type (record-offset + 8) source
			][
				emit-gpr-rsp-store code type (record-offset + 8) source
			]
			either type/1 = 'i64 [
				emit-gpr-rsp-load32 code 'r11d (record-offset + 12)
				emit-gpr-rsp-store32 code (record-offset + 16) 'r11d
			][
				emit-rsp-immediate32-store code (record-offset + 16) 0
			]
			emit-rsp-immediate32-store code (record-offset + 20) 0
		]
		result: pick instruction rs-o2-ir/ins-result
		destination: result-register allocation result
		unless destination [return none]
		emit-rsp-address code destination offset
		emit-spilled-result code allocation result destination
	]

	emit-copy-aggregate: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands destination-id source-id destination-location source-location
			destination source result result-location metadata size qwords remainder
			copy-offset width index type address-type dual-spill? source-offset load-base
	][
		operands: pick instruction rs-o2-ir/ins-operands
		destination-id: operands/1/2
		source-id: operands/2/2
		destination-location: allocation-register allocation destination-id
		source-location: allocation-register allocation source-id
		unless all [destination-location source-location][
			return fail-selection 'x64-copy-aggregate-allocation
		]
		dual-spill?: all [
			destination-id <> source-id
			destination-location = 'spill
			source-location = 'spill
		]
		destination: materialize-value code allocation destination-id
		unless destination [return none]
		either destination-id = source-id [
			source: destination
		][either dual-spill? [
				source: none
				source-offset: spill-offset source-id
				unless integer? source-offset [
					return fail-selection 'x64-copy-aggregate-source-spill
				]
				address-type: rs-o2-ir/make-type 'i64 8 'gpr no 0 'none
			][
				source: materialize-value code allocation source-id
				unless source [return none]
			]
		]
		unless all [not dual-spill? destination = source][
			metadata: pick instruction rs-o2-ir/ins-metadata
			size: select metadata 'size
			qwords: to integer! (size / 8)
			copy-offset: 0
			repeat index qwords [
				load-base: source
				if dual-spill? [
					emit-gpr-frame-load code address-type 'r11d source-offset
					load-base: 'r11d
				]
				unless emit-aggregate-slot-load code 8 'r11d load-base copy-offset [return none]
				type: rs-o2-ir/make-type 'i64 8 'gpr no 0 'none
				emit-gpr-pointer-store code type destination copy-offset 'r11d
				copy-offset: copy-offset + 8
			]
			remainder: size // 8
			foreach width [4 2 1] [
				if remainder >= width [
					load-base: source
					if dual-spill? [
						emit-gpr-frame-load code address-type 'r11d source-offset
						load-base: 'r11d
					]
					unless emit-aggregate-slot-load code width 'r11d load-base copy-offset [return none]
					type: case [
						width = 4 [rs-o2-ir/make-type 'i32 4 'gpr no 0 'none]
						width = 2 [rs-o2-ir/make-type 'i16 2 'gpr no 0 'none]
						width = 1 [rs-o2-ir/make-type 'i8 1 'gpr no 0 'none]
						true [return fail-selection 'x64-copy-aggregate-width]
					]
					emit-gpr-pointer-store code type destination copy-offset 'r11d
					copy-offset: copy-offset + width
					remainder: remainder - width
				]
			]
		]
		result: pick instruction rs-o2-ir/ins-result
		result-location: result-register allocation result
		unless result-location [return none]
		emit-gpr-move code pick instruction rs-o2-ir/ins-type result-location destination
		emit-spilled-result code allocation result result-location
	]

	aggregate-call-result-offset: func [
		instruction [block!]
		/local metadata mode temp definition id
	][
		metadata: pick instruction rs-o2-ir/ins-metadata
		mode: select metadata 'aggregate-mode
		id: either find [register sysv-register] mode [
			pick instruction rs-o2-ir/ins-id
		][
			temp: select metadata 'aggregate-temp
			definition: rs-o2-ir/find-vreg-definition temp
			all [definition pick definition rs-o2-ir/ins-id]
		]
		all [integer? id rs-o2-ir/table-value aggregate-temp-offsets id]
	]

	emit-sysv-aggregate-result: func [
		code [binary!]
		offset [integer!]
		size [integer!]
		classes [block!]
		/local integer-index float-index index class width register type
	][
		integer-index: 0
		float-index: 0
		index: 0
		foreach class classes [
			width: min 8 (size - (index * 8))
			either class = 'sse [
				float-index: float-index + 1
				register: pick [xmm0 xmm1] float-index
				type: rs-o2-ir/make-type either width <= 4 ['f32]['f64]
					either width <= 4 [4][8] 'xmm yes 0 'none
				emit-xmm-rsp-store code type (offset + (index * 8)) register
			][
				integer-index: integer-index + 1
				register: pick [eax edx] integer-index
				emit-aggregate-rsp-store code 8 (offset + (index * 8)) register
			]
			index: index + 1
		]
		yes
	]

	emit-variadic-call-state: func [
		code [binary!]
		instruction [block!]
		/local metadata operands arguments abi index count operand type source target registers
	][
		metadata: pick instruction rs-o2-ir/ins-metadata
		unless all [block? metadata select metadata 'variadic][return yes]
		operands: pick instruction rs-o2-ir/ins-operands
		arguments: next operands
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		either abi = 'win64 [
			registers: [ecx edx r8d r9d]
			count: min 4 (length? arguments)
			repeat index count [
				operand: pick arguments index
				type: rs-o2-ir/vreg-type operand/2
				if supported-float? type [
					source: call-argument-register instruction index
					target: pick registers index
					unless all [source target][return fail-selection 'x64-variadic-register]
					emit-xmm-to-gpr-bits code type target source
				]
			]
		][
			count: 0
			repeat index length? arguments [
				operand: pick arguments index
				type: rs-o2-ir/vreg-type operand/2
				if all [supported-float? type call-argument-register instruction index][
					count: count + 1
				]
			]
			append-byte code 176
			append-byte code count
		]
		yes
	]

	emit-copy-cell-intrinsic: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands result type source destination result-location
	][
		unless copy-cell-xmm-scratch [return fail-selection 'x64-copy-cell-scratch]
		unless emit-call-argument-moves code instruction allocation [return none]
		operands: pick instruction rs-o2-ir/ins-operands
		result: pick instruction rs-o2-ir/ins-result
		type: pick instruction rs-o2-ir/ins-type
		source: call-argument-register instruction 1
		destination: call-argument-register instruction 2
		result-location: result-register allocation result
		unless all [source destination result-location][
			return fail-selection 'x64-copy-cell-registers
		]
		emit-xmm-pointer-load code copy-cell-xmm-scratch source
		emit-xmm-pointer-store code destination copy-cell-xmm-scratch
		emit-gpr-move code type result-location destination
		emit-spilled-result code allocation result result-location
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

	immediate-use?: func [instruction [block!] index [integer!] /local opcode metadata][
		opcode: pick instruction rs-o2-ir/ins-opcode
		any [
			all [opcode = 'return index = 1]
			all [opcode = 'stack-push index = 1]
			all [
				opcode = 'custom-call
				index = 2
				metadata: pick instruction rs-o2-ir/ins-metadata
				(select metadata 'count-kind) = 'static
			]
			all [supported-binary? opcode index = 2]
			all [supported-shift? opcode index = 2]
			all [
				supported-i32? pick instruction rs-o2-ir/ins-type
				supported-integer-division? opcode
				index = 2
			]
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
				if all [opcode = 'const result integer? operands/1/2][
					rs-o2-ir/set-table-value values result operands/1/2
					append candidates result
				]
			]
		]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				if all [
					supported-binary? opcode
					rs-o2-ir/commutative-op? opcode
					(length? operands) = 2
					operands/1/1 = 'vreg
					operands/2/1 = 'vreg
					find candidates operands/1/2
					find candidates operands/2/2
				][
					; x64 binary encodings have only one immediate operand.
					; Keep the left constant materialized and encode the right one.
					remove find candidates operands/1/2
				]
				index: 0
				foreach operand operands [
					index: index + 1
					if all [operand/1 = 'vreg found: find candidates operand/2][
						unless immediate-use? instruction index [remove found]
					]
				]
			]
		]
		reduce [values candidates]
	]

	shift-group: func [opcode [word!] left-type [block!]][
		case [
			opcode = rs-o2-ir/left-shift-op [4]
			opcode = rs-o2-ir/unsigned-right-shift-op [5]
			opcode = rs-o2-ir/right-shift-op [either left-type/4 [7][5]]
			true [none]
		]
	]

	emit-shift-immediate: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left [word!]
		value [integer!]
		left-type [block!]
		/local dst group
	][
		emit-mov-register code destination left
		dst: register-code destination
		group: shift-group opcode left-type
		unless integer? group [return fail-selection 'x64-shift-immediate-encoding]
		emit-rex code no none none dst
		append-byte code 193
		emit-modrm code 192 group dst
		append code int-to-bin/to-bin8 value
	]

	emit-shift-register-count: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left-type [block!]
		/local dst group
	][
		dst: register-code destination
		group: shift-group opcode left-type
		unless all [integer? dst integer? group][
			return fail-selection 'x64-shift-register-encoding
		]
		emit-rex code no none none dst
		append-byte code 211
		emit-modrm code 192 group dst
	]

	emit-signed-i32-division: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left [word!]
	][
		if find [ecx edx] destination [
			return fail-selection 'x64-division-result-register
		]
		emit-mov-register code 'eax left
		append code #{99F7F9}                         ;-- CDQ / IDIV ECX
		if rs-o2-ir/remainder-result-op? opcode [
			append code #{89D0}                         ;-- MOV EAX, EDX
		]
		if rs-o2-ir/modulus-op? opcode [
			; Match the direct backend's non-negative modulus for signed operands.
			append code #{85C0790885C97902F7D901C8}
		]
		emit-mov-register code destination 'eax
		yes
	]

	emit-signed-i32-magic-division: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		left [word!]
		divisor [integer!]
		magic [block!]
		/local shift
	][
		if find [ecx edx] destination [
			return fail-selection 'x64-division-result-register
		]
		; The original dividend must survive the EAX/EDX multiply sequence.
		if find [eax ecx edx] left [
			return fail-selection 'x64-magic-left-register
		]
		unless all [(length? magic) >= 2 integer? magic/1 integer? magic/2][
			return fail-selection 'x64-magic-constant
		]
		shift: magic/2
		emit-mov-register code 'eax left
		emit-mov-immediate code 'ecx magic/1
		append code #{F7E9}                         ;-- IMUL ECX, signed EDX:EAX
		append code #{89D0}                         ;-- MOV EAX, EDX
		unless zero? shift [
			append code #{C1F8}                       ;-- SAR EAX, shift
			append-byte code shift
		]
		emit-mov-register code 'edx left
		append code #{C1FA1F}                       ;-- SAR EDX, 31
		append code #{29D0}                         ;-- SUB EAX, EDX
		if rs-o2-ir/remainder-result-op? opcode [
			emit-mov-immediate code 'ecx divisor
			append code #{0FAFC1}                     ;-- IMUL EAX, ECX
			emit-mov-register code 'edx left
			append code #{29C2}                       ;-- SUB EDX, EAX
			append code #{89D0}                       ;-- MOV EAX, EDX
			if rs-o2-ir/modulus-op? opcode [
				; Convert signed remainder to Red/System's non-negative // result.
				append code #{89C2C1FA1F21CA01D0}
			]
		]
		emit-mov-register code destination 'eax
		yes
	]

	emit-log-b: func [
		code [binary!]
		destination [word!]
		source [word!]
		/local dst
	][
		emit-mov-register code destination source
		dst: register-code destination
		unless integer? dst [return fail-selection 'x64-log-b-encoding]
		emit-rex code no dst none dst
		append code #{0FBD}
		emit-modrm code 192 dst dst
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
		wide? [logic!]
		left [word!]
		right [word!]
		/local lhs rhs
	][
		lhs: register-code left
		rhs: register-code right
		emit-rex code wide? rhs none lhs
		append-byte code 57
		emit-modrm code 192 rhs lhs
	]

	emit-compare-memory: func [
		code [binary!]
		wide? [logic!]
		left [word!]
		offset [integer!]
		/local lhs
	][
		lhs: register-code left
		emit-rex code wide? lhs none 5
		append-byte code 59
		emit-frame-modrm code lhs offset
	]

	emit-xmm-compare: func [
		code [binary!]
		type [block!]
		left [word!]
		right [word!]
		/local lhs rhs
	][
		lhs: xmm-register-code left
		rhs: xmm-register-code right
		if type/1 = 'f64 [append-byte code 102]
		emit-rex code no lhs none rhs
		append code #{0F2E}
		emit-modrm code 192 lhs rhs
	]

	emit-xmm-compare-memory: func [
		code [binary!]
		type [block!]
		left [word!]
		offset [integer!]
		/local lhs
	][
		lhs: xmm-register-code left
		if type/1 = 'f64 [append-byte code 102]
		emit-rex code no lhs none 5
		append code #{0F2E}
		emit-frame-modrm code lhs offset
	]

	emit-compare-memory-immediate: func [
		code [binary!]
		wide? [logic!]
		offset [integer!]
		value [integer!]
		/local short?
	][
		short?: all [value >= -128 value <= 127]
		emit-rex code wide? none none 5
		append-byte code either short? [131][129]
		emit-frame-modrm code 7 offset
		append code either short? [int-to-bin/to-bin8 value][int-to-bin/to-bin32 value]
	]

	call-split-values-at: func [instruction [block!]][
		rs-o2-ir/table-value call-split-points pick instruction rs-o2-ir/ins-id
	]

	emit-call-split-spills: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local values id location type offset
	][
		values: call-split-values-at instruction
		if none? values [return yes]
		foreach id values [
			location: allocation-register allocation id
			unless location [return fail-selection 'x64-call-split-allocation]
			unless location = 'spill [
				type: rs-o2-ir/vreg-type id
				offset: spill-offset id
				unless integer? offset [return fail-selection 'x64-call-split-offset]
				either supported-float? type [
					emit-xmm-frame-store code type offset location
				][emit-gpr-frame-store code type offset location]
			]
		]
		yes
	]

	emit-call-split-reloads: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local values id location type offset
	][
		values: call-split-values-at instruction
		if none? values [return yes]
		foreach id values [
			location: allocation-register allocation id
			unless location [return fail-selection 'x64-call-split-allocation]
			if all [
				location <> 'spill
				any [supported-float? rs-o2-ir/vreg-type id not callee-saved-register? location]
			][
				type: rs-o2-ir/vreg-type id
				offset: spill-offset id
				unless integer? offset [return fail-selection 'x64-call-split-offset]
				either supported-float? type [
					emit-xmm-frame-load code type location offset
				][emit-gpr-frame-load code type location offset]
			]
		]
		yes
	]

	emit-stack-push-instruction: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands id value type source
	][
		operands: pick instruction rs-o2-ir/ins-operands
		id: operands/1/2
		value: constant-vreg-value id
		if integer? value [
			either all [value >= -128 value <= 127][
				append-byte code 106                    ;-- PUSH sign-extended imm8
				append code int-to-bin/to-bin8 value
			][
				append-byte code 104                    ;-- PUSH sign-extended imm32
				append code int-to-bin/to-bin32 value
			]
			return yes
		]
		type: rs-o2-ir/vreg-type id
		source: materialize-value code allocation id
		unless source [return none]
		either supported-float? type [
			unless emit-rsp-adjust code yes 8 [return none]
			emit-xmm-rsp-store code type 0 source
		][
			unless emit-push-register code source [return none]
		]
		yes
	]

	emit-stack-pop-instruction: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local result destination
	][
		result: pick instruction rs-o2-ir/ins-result
		destination: result-register allocation result
		unless destination [return none]
		unless emit-pop-register code destination [return none]
		emit-spilled-result code allocation result destination
	]

	emit-custom-target-call: func [
		code [binary!]
		instruction [block!]
		target-kind [word!]
		/local operands abi callee spec patch
	][
		operands: pick instruction rs-o2-ir/ins-operands
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		either target-kind = 'direct [
			callee: operands/1/2
			spec: select emitter/symbols callee
			either all [abi = 'win64 spec spec/1 = 'import][
				append code #{FF15}
			][append-byte code 232]
			patch: (length? code) + 1
			append code #{00000000}
			record-encoded-relocation-patch
				pick instruction rs-o2-ir/ins-id patch
		][append code #{41FFD3}]                    ;-- CALL r11
		yes
	]

	emit-custom-call-result: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local result type source location destination
	][
		result: pick instruction rs-o2-ir/ins-result
		if none? result [return yes]
		type: pick instruction rs-o2-ir/ins-type
		if supported-narrow-gpr? type [
			unless emit-normalize-narrow-register code type 'eax 'eax [return none]
		]
		source: return-register type
		location: allocation-register allocation result
		unless location [return fail-selection 'x64-custom-call-result-allocation]
		either location = 'spill [
			emit-spilled-result code allocation result source
		][
			destination: result-register allocation result
			either supported-float? type [
				emit-xmm-move code type destination source
			][emit-gpr-move code type destination source]
			yes
		]
	]

	emit-custom-dynamic-register-loads: func [
		code [binary!]
		registers [block!]
		slot-type [block!]
		/local patches index patch target
	][
		patches: make block! length? registers
		repeat index length? registers [
			emit-compare-immediate code no 'r14d index
			append code #{0F8C}                       ;-- JL done
			patch: (length? code) + 1
			append code #{00000000}
			append patches patch
			target: pick registers index
			emit-gpr-pointer-load code slot-type target 'r13d ((index - 1) * 8)
		]
		foreach patch patches [
			patch-switch-local-rel32 code patch length? code
		]
		yes
	]

	emit-custom-dynamic-call-instruction: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands metadata target-kind abi registers register-limit input-depth
			shadow-slots source source-type count-source count-type nonnegative-patch
			overflow-patch pad-patch copy-loop copy-done copy-back source-offset
			target-offset slot-type
	][
		unless emit-call-split-spills code instruction allocation [return none]
		unless emit-promoted-local-stores code [return none]
		operands: pick instruction rs-o2-ir/ins-operands
		metadata: pick instruction rs-o2-ir/ins-metadata
		target-kind: select metadata 'target-kind
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		input-depth: pick instruction rs-o2-ir/ins-stack-in

		if target-kind = 'indirect [
			source: materialize-value code allocation operands/1/2
			unless source [return none]
			source-type: rs-o2-ir/vreg-type operands/1/2
			emit-gpr-move code source-type 'r11d source
		]
		count-source: materialize-value code allocation operands/2/2
		unless count-source [return none]
		count-type: rs-o2-ir/vreg-type operands/2/2
		emit-gpr-move code count-type 'r14d count-source
		emit-test-register code 'r14d
		append code #{0F8D}                         ;-- JGE nonnegative
		nonnegative-patch: (length? code) + 1
		append code #{00000000}
		append code #{4531F6}                       ;-- XOR r14d, r14d
		patch-switch-local-rel32 code nonnegative-patch length? code

		append code #{4989E5}                       ;-- MOV r13, rsp
		unless emit-movsxd-register code 'eax 'r14d [return none]
		unless emit-lea-indexed code 'r12d 'r13d 'eax 8 [return none]

		registers: either abi = 'win64 [
			[ecx edx r8d r9d]
		][
			[edi esi edx ecx r8d r9d]
		]
		register-limit: length? registers
		emit-mov-register code 'r10d 'r14d
		append code #{4183EA}
		append-byte code register-limit             ;-- SUB r10d, register-limit
		emit-test-register code 'r10d
		append code #{0F8D}                         ;-- JGE overflow-ready
		overflow-patch: (length? code) + 1
		append code #{00000000}
		append code #{4531D2}                       ;-- XOR r10d, r10d
		patch-switch-local-rel32 code overflow-patch length? code

		shadow-slots: either abi = 'win64 [4][0]
		emit-mov-register code 'eax 'r10d
		if positive? shadow-slots [
			append code #{83C0}
			append-byte code shadow-slots              ;-- ADD eax, shadow-slots
		]
		append code #{41F6C201}                     ;-- TEST r10b, 1
		append code either even? input-depth [#{0F84}][#{0F85}]
		pad-patch: (length? code) + 1
		append code #{00000000}
		append code #{FFC0}                         ;-- INC eax (alignment slot)
		patch-switch-local-rel32 code pad-patch length? code
		append code #{48C1E0034829C4}               ;-- SHL rax,3 / SUB rsp,rax

		slot-type: rs-o2-ir/make-type 'i64 8 'gpr no 0 'none
		source-offset: register-limit * 8
		target-offset: shadow-slots * 8
		append code #{31C9}                         ;-- XOR ecx, ecx
		copy-loop: length? code
		append code #{4439D1}                       ;-- CMP ecx, r10d
		append code #{0F8D}                         ;-- JGE copy-done
		copy-done: (length? code) + 1
		append code #{00000000}
		append code #{498B44CD}
		append-byte code source-offset              ;-- MOV rax, [r13+rcx*8+source]
		append code #{488944CC}
		append-byte code target-offset              ;-- MOV [rsp+rcx*8+target], rax
		append code #{FFC1E9}                       ;-- INC ecx / JMP copy-loop
		copy-back: (length? code) + 1
		append code #{00000000}
		patch-switch-local-rel32 code copy-back copy-loop
		patch-switch-local-rel32 code copy-done length? code

		unless emit-custom-dynamic-register-loads code registers slot-type [return none]
		unless emit-custom-target-call code instruction target-kind [return none]
		append code #{4C89E4}                       ;-- MOV rsp, r12
		unless emit-custom-call-result code instruction allocation [return none]
		unless emit-call-split-reloads code instruction allocation [return none]
		unless emit-promoted-local-reloads code [return none]
		yes
	]

	emit-custom-call-instruction: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local operands metadata target-kind count count-kind abi registers register-count overflow
			residual pad? pad-slots shadow-slots cleanup-bytes index source source-type
			source-offset target-offset slot-type callee spec patch result type destination location
	][
		operands: pick instruction rs-o2-ir/ins-operands
		metadata: pick instruction rs-o2-ir/ins-metadata
		target-kind: select metadata 'target-kind
		count-kind: select metadata 'count-kind
		if count-kind = 'dynamic [
			return emit-custom-dynamic-call-instruction code instruction allocation
		]
		unless emit-call-split-spills code instruction allocation [return none]
		unless emit-promoted-local-stores code [return none]
		count: select metadata 'stack-count
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi

		if target-kind = 'indirect [
			source: materialize-value code allocation operands/1/2
			unless source [return none]
			source-type: rs-o2-ir/vreg-type operands/1/2
			emit-gpr-move code source-type 'r11d source
		]

		registers: either abi = 'win64 [
			[ecx edx r8d r9d]
		][
			[edi esi edx ecx r8d r9d]
		]
		register-count: min count length? registers
		repeat index register-count [
			unless emit-pop-register code pick registers index [return none]
		]

		overflow: count - register-count
		residual: pick instruction rs-o2-ir/ins-stack-out
		pad?: odd? (residual + overflow)
		pad-slots: either pad? [1][0]
		slot-type: rs-o2-ir/make-type 'i64 8 'gpr no 0 'none
		if pad? [
			unless emit-rsp-adjust code yes 8 [return none]
			repeat index overflow [
				source-offset: index * 8
				target-offset: (index - 1) * 8
				emit-gpr-rsp-load-wide code 'eax source-offset
				emit-gpr-rsp-store code slot-type target-offset 'eax
			]
		]

		shadow-slots: either abi = 'win64 [4][0]
		if positive? shadow-slots [
			unless emit-rsp-adjust code yes (shadow-slots * 8) [return none]
		]

		either target-kind = 'direct [
			callee: operands/1/2
			spec: select emitter/symbols callee
			either all [abi = 'win64 spec spec/1 = 'import][
				append code #{FF15}
			][append-byte code 232]
			patch: (length? code) + 1
			append code #{00000000}
			record-encoded-relocation-patch
				pick instruction rs-o2-ir/ins-id patch
		][append code #{41FFD3}]                    ;-- CALL r11

		cleanup-bytes: ((overflow + pad-slots) + shadow-slots) * 8
		unless emit-rsp-adjust code no cleanup-bytes [return none]
		result: pick instruction rs-o2-ir/ins-result
		if result [
			type: pick instruction rs-o2-ir/ins-type
			if supported-narrow-gpr? type [
				unless emit-normalize-narrow-register code type 'eax 'eax [return none]
			]
			source: return-register type
			location: allocation-register allocation result
			unless location [return fail-selection 'x64-custom-call-result-allocation]
			either location = 'spill [
				unless emit-spilled-result code allocation result source [return none]
			][
				destination: result-register allocation result
				either supported-float? type [
					emit-xmm-move code type destination source
				][emit-gpr-move code type destination source]
			]
		]
		unless emit-call-split-reloads code instruction allocation [return none]
		unless emit-promoted-local-reloads code [return none]
		yes
	]

	active-call-reserve-bytes: func [instruction [block!] /local depth bytes slots abi][
		depth: pick instruction rs-o2-ir/ins-stack-in
		if zero? depth [return 0]
		unless integer? depth [return fail-selection 'x64-dynamic-active-call-stack]
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		bytes: outgoing-frame-bytes
		if abi = 'win64 [bytes: max 32 bytes]
		bytes: round/to/ceiling bytes 8
		slots: bytes / 8
		if odd? (depth + slots) [bytes: bytes + 8]
		bytes
	]

	emit-direct-call: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local patch id result type source destination location operands callee spec abi
			metadata aggregate-result? aggregate-mode aggregate-size aggregate-offset aggregate-classes
			active-stack-bytes
	][
		unless emit-call-split-spills code instruction allocation [return none]
		unless emit-promoted-local-stores code [return none]
		active-stack-bytes: active-call-reserve-bytes instruction
		unless integer? active-stack-bytes [return none]
		if positive? active-stack-bytes [
			unless emit-rsp-adjust code yes active-stack-bytes [return none]
		]
		unless emit-call-stack-arguments code instruction allocation [return none]
		unless emit-call-argument-moves code instruction allocation [return none]
		unless emit-variadic-call-state code instruction [return none]
		operands: pick instruction rs-o2-ir/ins-operands
		callee: operands/1/2
		spec: select emitter/symbols callee
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		either all [abi = 'win64 spec spec/1 = 'import] [
			append code #{FF15}
		][append-byte code 232]
		patch: (length? code) + 1
		append code #{00000000}
		id: pick instruction rs-o2-ir/ins-id
		record-encoded-relocation-patch id patch
		if positive? active-stack-bytes [
			unless emit-rsp-adjust code no active-stack-bytes [return none]
		]
		result: pick instruction rs-o2-ir/ins-result
		if result [
			type: pick instruction rs-o2-ir/ins-type
			metadata: pick instruction rs-o2-ir/ins-metadata
			aggregate-result?: select metadata 'aggregate-result
			either aggregate-result? [
				aggregate-mode: select metadata 'aggregate-mode
				aggregate-size: select metadata 'aggregate-size
				aggregate-offset: aggregate-call-result-offset instruction
				unless integer? aggregate-offset [
					return fail-selection 'x64-call-aggregate-result-offset
				]
				case [
					aggregate-mode = 'register [
						emit-aggregate-rsp-store code 8 aggregate-offset 'eax
						if aggregate-size > 8 [
							emit-aggregate-rsp-store code 8 (aggregate-offset + 8) 'edx
						]
					]
					aggregate-mode = 'sysv-register [
						aggregate-classes: select metadata 'aggregate-classes
						unless emit-sysv-aggregate-result
							code aggregate-offset aggregate-size aggregate-classes
						[return none]
					]
					true []
				]
				destination: result-register allocation result
				unless destination [return none]
				emit-rsp-address code destination aggregate-offset
				unless emit-spilled-result code allocation result destination [return none]
			][
				source: return-register type
				location: allocation-register allocation result
				unless location [return fail-selection 'x64-call-result-allocation]
				either location = 'spill [
					unless emit-spilled-result code allocation result source [return none]
				][
					destination: result-register allocation result
					either supported-float? type [
						emit-xmm-move code type destination source
					][emit-gpr-move code type destination source]
				]
			]
		]
		unless emit-call-split-reloads code instruction allocation [return none]
		unless emit-promoted-local-reloads code [return none]
		yes
	]

	emit-resolver-intrinsic: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		series? [logic!]
		/local instruction-id result result-location abi handle expected-handle
			result-register-value type global-patch patch slow-patches done-patch slow-target done-target
	][
		unless emit-call-split-spills code instruction allocation [return none]
		unless emit-call-argument-moves code instruction allocation [return none]
		instruction-id: pick instruction rs-o2-ir/ins-id
		result: pick instruction rs-o2-ir/ins-result
		result-location: allocation-register allocation result
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		handle: call-argument-register instruction 1
		expected-handle: either abi = 'win64 ['ecx]['edi]
		unless all [
			handle = expected-handle
			result-location
		][return fail-selection 'x64-resolver-registers]

		slow-patches: make block! 3
		append code either abi = 'win64 [#{85C9}][#{85FF}] ;-- TEST handle, handle
		append code #{0F84}                              ;-- JZ slow/null
		patch: (length? code) + 1
		append code #{00000000}
		append slow-patches patch

		append code #{488B05}                            ;-- MOV rax, [RIP+node-registry]
		global-patch: (length? code) + 1
		append code #{00000000}
		record-encoded-relocation-patch instruction-id global-patch
		append code either abi = 'win64 [
			#{3B4814}                                     ;-- CMP ecx, [rax+next]
		][
			#{3B7814}                                     ;-- CMP edi, [rax+next]
		]
		append code #{0F83}                              ;-- JAE slow/null
		patch: (length? code) + 1
		append code #{00000000}
		append slow-patches patch
		append code #{488B00}                            ;-- MOV rax, [rax+entries]
		append code either abi = 'win64 [
			#{4863C9488B44C8F8}                         ;-- Resolve entry in rax
		][
			#{4863FF488B44F8F8}
		]
		if series? [
			append code #{4885C0}                          ;-- TEST rax, rax
			append code #{0F84}                            ;-- JZ slow
			patch: (length? code) + 1
			append code #{00000000}
			append slow-patches patch
			append code #{488B00}                          ;-- MOV rax, [rax+node/value]
		]

		append-byte code 233                            ;-- JMP done
		done-patch: (length? code) + 1
		append code #{00000000}
		slow-target: length? code
		foreach patch slow-patches [
			patch-switch-local-rel32 code patch slow-target
		]
		either series? [
			unless emit-promoted-local-stores code [return none]
			append-byte code 232                          ;-- CALL resolve-series
			patch: (length? code) + 1
			append code #{00000000}
			record-encoded-relocation-patch instruction-id patch
			unless emit-promoted-local-reloads code [return none]
		][
			append code #{31C0}                           ;-- XOR eax, eax
		]
		done-target: length? code
		patch-switch-local-rel32 code done-patch done-target
		type: pick instruction rs-o2-ir/ins-type
		result-register-value: result-register allocation result
		unless result-register-value [return none]
		emit-gpr-move code type result-register-value 'eax
		unless emit-spilled-result code allocation result result-register-value [return none]
		emit-call-split-reloads code instruction allocation
	]

	emit-compare-immediate: func [
		code [binary!]
		wide? [logic!]
		left [word!]
		value [integer!]
		/local lhs short?
	][
		lhs: register-code left
		short?: all [value >= -128 value <= 127]
		case [
			zero? value [
				emit-rex code wide? lhs none lhs
				append-byte code 133
				emit-modrm code 192 lhs lhs
			]
			all [left = 'eax not short?] [
				emit-rex code wide? none none lhs
				append-byte code 61                  ;-- CMP EAX, imm32
				append code int-to-bin/to-bin32 value
			]
			true [
				emit-rex code wide? none none lhs
				append-byte code either short? [131][129]
				emit-modrm code 192 7 lhs
				append code either short? [int-to-bin/to-bin8 value][int-to-bin/to-bin32 value]
			]
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

	pointer-condition-code: func [opcode [word! none!] /local code][
		code: case [
			opcode = rs-o2-ir/equal-op [4]
			opcode = rs-o2-ir/not-equal-op [5]
			opcode = rs-o2-ir/less-op [2]
			opcode = rs-o2-ir/greater-op [7]
			opcode = rs-o2-ir/less-or-equal-op [6]
			opcode = rs-o2-ir/greater-or-equal-op [3]
			true [none]
		]
		code
	]

	gpr-condition-code: func [opcode [word! none!] type [block! none!]][
		either any [
			all [type valid-pointer-type? type]
			all [type supported-logic? type]
			all [
				rs-o2-ir/valid-type? type
				find [i8 i16 i32 i64] type/1
				not type/4
			]
		][
			pointer-condition-code opcode
		][condition-code opcode]
	]

	float-condition-code: func [opcode [word! none!] /local code][
		code: case [
			opcode = rs-o2-ir/equal-op [4]
			opcode = rs-o2-ir/not-equal-op [5]
			opcode = rs-o2-ir/less-op [2]
			opcode = rs-o2-ir/greater-op [7]
			opcode = rs-o2-ir/less-or-equal-op [6]
			opcode = rs-o2-ir/greater-or-equal-op [3]
			true [none]
		]
		code
	]

	float-condition-needs-parity?: func [opcode [word! none!]][
		to logic! any [
			opcode = rs-o2-ir/equal-op
			opcode = rs-o2-ir/not-equal-op
			opcode = rs-o2-ir/less-op
			opcode = rs-o2-ir/less-or-equal-op
		]
	]

	emit-set-condition: func [
		code [binary!]
		condition [integer!]
		destination [word!]
		/local dst
	][
		dst: register-code destination
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
	]

	emit-materialized-condition: func [
		code [binary!]
		opcode [word!]
		type [block!]
		destination [word!]
		/local condition
	][
		condition: gpr-condition-code opcode type
		unless integer? condition [return fail-selection 'x64-condition-code]
		; SETcc writes one byte; MOVZX makes the Red/System logic representation
		; an explicit 32-bit 0/1 without disturbing the comparison flags first.
		emit-set-condition code condition destination
		yes
	]

	emit-materialized-float-condition: func [
		code [binary!]
		opcode [word!]
		destination [word!]
		/local condition patch skip-start correction
	][
		condition: float-condition-code opcode
		unless integer? condition [return fail-selection 'x64-float-condition-code]
		emit-set-condition code condition destination
		if float-condition-needs-parity? opcode [
			; UCOMI sets PF for unordered operands. Skip the correction for the
			; overwhelmingly common ordered case without changing its flags.
			append-byte code 123
			patch: (length? code) + 1
			append-byte code 0
			skip-start: length? code
			correction: either opcode = rs-o2-ir/not-equal-op [1][0]
			emit-mov-immediate code destination correction
			change/part at code patch int-to-bin/to-bin8 ((length? code) - skip-start) 1
		]
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

	emit-fixed-near-jump: func [
		code [binary!]
		fixups [block!]
		target [integer!]
		/local patch
	][
		append-byte code 233
		patch: (length? code) + 1
		append code #{00000000}
		append/only fixups reduce [patch target length? code 4 none 0]
	]

	emit-fixed-near-condition: func [
		code [binary!]
		fixups [block!]
		condition [integer!]
		target [integer!]
		/local patch
	][
		append-byte code 15
		append-byte code 128 + condition
		patch: (length? code) + 1
		append code #{00000000}
		append/only fixups reduce [patch target length? code 4 none 0]
	]

	patch-switch-local-rel32: func [
		code [binary!]
		position [integer!]
		target [integer!]
	][
		change/part
			at code position
			int-to-bin/to-bin32 (target - (position + 3))
			4
	]

	emit-sparse-switch-node: func [
		code [binary!]
		fixups [block!]
		selector [word!]
		entries [block!]
		low [integer!]
		high [integer!]
		default-id [integer!]
		/local middle entry-position value target left-patch
	][
		middle: to integer! round/down ((low + high) / 2)
		entry-position: (((middle - 1) * 2) + 1)
		value: pick entries entry-position
		target: pick entries (entry-position + 1)
		emit-compare-immediate code no selector value
		emit-fixed-near-condition code fixups 4 target

		if all [low = middle middle = high][
			emit-fixed-near-jump code fixups default-id
			return yes
		]

		either low < middle [
			append code #{0F8C}                    ;-- JL left subtree
			left-patch: (length? code) + 1
			append code #{00000000}
		][
			emit-fixed-near-condition code fixups 12 default-id
		]

		either middle < high [
			unless emit-sparse-switch-node
				code fixups selector entries (middle + 1) high default-id
			[return none]
		][
			emit-fixed-near-jump code fixups default-id
		]
		if low < middle [
			patch-switch-local-rel32 code left-patch length? code
			unless emit-sparse-switch-node
				code fixups selector entries low (middle - 1) default-id
			[return none]
		]
		yes
	]

	vreg-used-after?: func [
		id [integer!]
		instruction-id [integer!]
		/local block instruction operand
	][
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-id) > instruction-id [
					foreach operand pick instruction rs-o2-ir/ins-operands [
						if all [operand/1 = 'vreg operand/2 = id][return yes]
					]
				]
			]
		]
		no
	]

	emit-dense-switch-control: func [
		code [binary!]
		fixups [block!]
		instruction [block!]
		allocation [block!]
		entries [block!]
		min-value [integer!]
		span [integer!]
		default-id [integer!]
		/local operands selector-id selector lea-patch lea-end table-start index target patch
	][
		operands: pick instruction rs-o2-ir/ins-operands
		selector-id: operands/1/2
		if vreg-used-after? selector-id pick instruction rs-o2-ir/ins-id [
			return fail-selection 'x64-dense-switch-selector-live
		]
		selector: materialize-value code allocation selector-id
		unless selector [return none]
		unless selector = 'eax [emit-mov-register code 'eax selector]

		unless zero? min-value [
			append-byte code 45                       ;-- SUB EAX, minimum case value
			append code int-to-bin/to-bin32 min-value
		]
		append-byte code 61                           ;-- CMP EAX, normalized range
		append code int-to-bin/to-bin32 span
		emit-fixed-near-condition code fixups 7 default-id ;-- JA default

		append code #{4C8D1D}                         ;-- LEA r11, [RIP+table]
		lea-patch: (length? code) + 1
		append code #{00000000}
		lea-end: length? code
		append code #{49630483}                       ;-- MOVSXD rax, dword [r11+rax*4]
		append code #{4C01D8}                         ;-- ADD rax, r11
		append code #{FFE0}                           ;-- JMP rax
		table-start: length? code
		change/part
			at code lea-patch
			int-to-bin/to-bin32 (table-start - lea-end)
			4

		repeat index (span + 1) [
			target: select/skip entries ((min-value + index) - 1) 2
			unless target [target: default-id]
			patch: (length? code) + 1
			append code #{00000000}
			append/only jump-table-patches reduce [patch target table-start]
		]
		yes
	]

	emit-sparse-switch-control: func [
		code [binary!]
		fixups [block!]
		instruction [block!]
		allocation [block!]
		/local operands position entries selector default-operand default-id count
			previous value target min-value max-value span dense?
	][
		operands: pick instruction rs-o2-ir/ins-operands
		entries: make block! length? operands
		position: next operands
		while [(length? position) > 1][
			repend entries [position/1/2 position/2/2]
			position: skip position 2
		]
		sort/skip entries 2
		previous: none
		foreach [value target] entries [
			if all [integer? previous value = previous][
				return fail-selection 'x64-duplicate-switch-value
			]
			previous: value
		]
		count: (length? entries) / 2
		min-value: entries/1
		max-value: first skip tail entries -2
		dense?: all [count >= 5 not negative? min-value]
		if dense? [
			span: max-value - min-value
			dense?: all [span <= 255 (span + 1) <= (count * 2)]
		]
		default-operand: last operands
		default-id: default-operand/2
		if dense? [
			return emit-dense-switch-control
				code fixups instruction allocation entries min-value span default-id
		]
		if count < 12 [return fail-selection 'x64-switch-small]

		selector: materialize-value code allocation operands/1/2
		unless selector [return none]
		emit-sparse-switch-node
			code fixups selector entries 1 count default-id
	]

	emit-near-condition: func [
		code [binary!]
		fixups [block!]
		condition [integer!]
		target [integer!]
		instruction-id [integer!]
		/key branch-key [integer!]
		/local patch relaxation-id
	][
		relaxation-id: either key [branch-key][instruction-id * 2]
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

	emit-float-branch-control: func [
		code [binary!]
		fixups [block!]
		opcode [word!]
		condition [integer!]
		true-id [integer!]
		false-id [integer!]
		next-id [integer! none!]
		instruction-id [integer!]
		/local unordered-id parity-key condition-key
	][
		unordered-id: either opcode = rs-o2-ir/not-equal-op [true-id][false-id]
		parity-key: 0 - ((instruction-id * 2) + 1)
		condition-key: 0 - (instruction-id * 2)
		emit-near-condition/key code fixups 10 unordered-id instruction-id parity-key
		emit-near-condition/key code fixups condition true-id instruction-id condition-key
		unless false-id = next-id [emit-near-jump code fixups false-id instruction-id]
		yes
	]

	emit-branch-control: func [
		code [binary!]
		fixups [block!]
		instruction [block!]
		allocation [block!]
		next-id [integer! none!]
		/local operands metadata opcode condition true-id false-id instruction-id definition
			comparison-operands operand-type float? source
	][
		operands: pick instruction rs-o2-ir/ins-operands
		metadata: pick instruction rs-o2-ir/ins-metadata
		opcode: select metadata 'condition
		case [
			find [overflow carry] opcode [
				operand-type: rs-o2-ir/vreg-type operands/1/2
				unless supported-i32? operand-type [
					return fail-selection 'x64-overflow-condition-type
				]
				float?: no
				condition: either opcode = 'overflow [0][2]
			]
			opcode = 'truthy [
			operand-type: rs-o2-ir/vreg-type operands/1/2
			unless supported-logic? operand-type [return fail-selection 'x64-branch-condition-type]
			source: materialize-value code allocation operands/1/2
			unless source [return none]
			emit-test-register code source
			float?: no
			condition: 5
			]
			true [
			definition: rs-o2-ir/find-vreg-definition operands/1/2
			operand-type: none
			if definition [
				comparison-operands: pick definition rs-o2-ir/ins-operands
				if all [not empty? comparison-operands comparison-operands/1/1 = 'vreg][
					operand-type: rs-o2-ir/vreg-type comparison-operands/1/2
				]
			]
			float?: to logic! all [operand-type supported-float? operand-type]
			condition: either float? [
				float-condition-code opcode
			][gpr-condition-code opcode operand-type]
			]
		]
		unless integer? condition [return fail-selection 'x64-condition-code]
		instruction-id: pick instruction rs-o2-ir/ins-id
		true-id: operands/2/2
		false-id: operands/3/2
		case [
			true-id = false-id [
				unless true-id = next-id [emit-near-jump code fixups true-id instruction-id]
			]
			all [float? float-condition-needs-parity? opcode][
				return emit-float-branch-control
					code fixups opcode condition true-id false-id next-id instruction-id
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
					empty? aligned-loop-blocks
					integer? fixup/5
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

	patch-jump-tables: func [
		code [binary!]
		labels [block!]
		/local entry target
	][
		foreach entry jump-table-patches [
			target: rs-o2-ir/table-value labels entry/2
			unless integer? target [return fail-selection 'x64-missing-jump-table-label]
			change/part at code entry/1 int-to-bin/to-bin32 (target - entry/3) 4
		]
		code
	]

	canonical-loop-body: func [
		condition-id [integer!]
		blocks [block!]
		visited [block!]
		/local condition terminal operands body-id body body-terminal body-operands
	][
		if find visited condition-id [return none]
		unless all [condition-id >= 1 condition-id <= length? blocks][return none]
		condition: pick blocks condition-id
		unless not empty? pick condition rs-o2-ir/bb-instructions [return none]
		terminal: last pick condition rs-o2-ir/bb-instructions
		unless (pick terminal rs-o2-ir/ins-opcode) = 'branch [return none]
		operands: pick terminal rs-o2-ir/ins-operands
		unless (length? operands) = 3 [return none]
		body-id: operands/2/2
		unless all [body-id >= 1 body-id <= length? blocks not find visited body-id][return none]
		body: pick blocks body-id
		unless not empty? pick body rs-o2-ir/bb-instructions [return none]
		body-terminal: last pick body rs-o2-ir/bb-instructions
		unless (pick body-terminal rs-o2-ir/ins-opcode) = 'jump [return none]
		body-operands: pick body-terminal rs-o2-ir/ins-operands
		unless all [(length? body-operands) = 1 body-operands/1/2 = condition-id][return none]
		body-id
	]

	simple-switch-merge: func [
		block [block!]
		blocks [block!]
		/local successors successor arm terminal operands merge-id
	][
		successors: pick block rs-o2-ir/bb-successors
		if empty? successors [return none]
		merge-id: none
		foreach successor successors [
			arm: pick blocks successor
			if empty? pick arm rs-o2-ir/bb-instructions [return none]
			terminal: last pick arm rs-o2-ir/bb-instructions
			unless (pick terminal rs-o2-ir/ins-opcode) = 'jump [return none]
			operands: pick terminal rs-o2-ir/ins-operands
			unless (length? operands) = 1 [return none]
			either merge-id [
				unless merge-id = operands/1/2 [return none]
			][merge-id: operands/1/2]
		]
		merge-id
	]

	append-layout-block: func [
		id [integer!]
		blocks [block!]
		visited [block!]
		layout [block!]
		/local block instruction opcode operands successor loop-body merge-id merge-pending? default-id
			target target-block true-block false-block true-label false-label
			metadata
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
				target: operands/1/2
				target-block: pick blocks target
				either all [
					find [short-circuit-true short-circuit-false] pick block rs-o2-ir/bb-label
					(pick target-block rs-o2-ir/bb-label) = 'short-circuit-exit
				][none][
					loop-body: canonical-loop-body target blocks visited
					either loop-body [
						unless find aligned-loop-blocks loop-body [append aligned-loop-blocks loop-body]
						append-layout-block loop-body blocks visited layout
					][append-layout-block target blocks visited layout]
				]
			]
			opcode = 'branch [
				true-block: pick blocks operands/2/2
				false-block: pick blocks operands/3/2
				true-label: pick true-block rs-o2-ir/bb-label
				false-label: pick false-block rs-o2-ir/bb-label
				metadata: pick instruction rs-o2-ir/ins-metadata
				case [
					select metadata 'overflow-edge [
						append-layout-block operands/3/2 blocks visited layout
						append-layout-block operands/2/2 blocks visited layout
					]
					all [
						true-label = 'short-circuit-true
						false-label = 'short-circuit-next
					][
						append-layout-block operands/3/2 blocks visited layout
						append-layout-block operands/2/2 blocks visited layout
					]
					all [
						true-label = 'short-circuit-next
						false-label = 'short-circuit-false
					][
						append-layout-block operands/2/2 blocks visited layout
						append-layout-block operands/3/2 blocks visited layout
					]
					all [
						find [short-circuit-true short-circuit-false] true-label
						find [short-circuit-true short-circuit-false] false-label
					][
						either true-label = 'short-circuit-false [
							append-layout-block operands/2/2 blocks visited layout
							append-layout-block operands/3/2 blocks visited layout
						][
							append-layout-block operands/3/2 blocks visited layout
							append-layout-block operands/2/2 blocks visited layout
						]
						merge-id: simple-switch-merge block blocks
						if merge-id [append-layout-block merge-id blocks visited layout]
					]
					true [
						append-layout-block operands/2/2 blocks visited layout
						append-layout-block operands/3/2 blocks visited layout
					]
				]
			]
			opcode = 'switch [
				merge-id: simple-switch-merge block blocks
				either merge-id [
					merge-pending?: none? find visited merge-id
					if merge-pending? [append visited merge-id]
					default-id: last operands
					default-id: default-id/2
					append-layout-block default-id blocks visited layout
					foreach successor pick block rs-o2-ir/bb-successors [
						unless successor = default-id [
							append-layout-block successor blocks visited layout
						]
					]
					if merge-pending? [
						remove find visited merge-id
						append-layout-block merge-id blocks visited layout
					]
				][
					foreach successor pick block rs-o2-ir/bb-successors [
						append-layout-block successor blocks visited layout
					]
				]
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
		clear aligned-loop-blocks
		layout: make block! length? blocks
		visited: make block! length? blocks
		append-layout-block 1 blocks visited layout
		foreach block blocks [
			id: pick block rs-o2-ir/bb-id
			unless find visited id [append-layout-block id blocks visited layout]
		]
		layout
	]

	emit-code-alignment: func [
		code [binary!]
		base [integer!]
		alignment [integer!]
		/local remainder padding
	][
		remainder: (base + (length? code)) // alignment
		if not zero? remainder [
			padding: alignment - remainder
			loop padding [append-byte code 144]
		]
	]

	encode-body: func [
		allocation [block!]
		body-base [integer!]
		/local code blocks block block-index block-id next-block next-id last-id labels fixups terminal
			instruction opcode operands result destination source base left right offset local-register
			constant-info constant-values immediate-constants left-value right-value target
			memory-name left-memory-name memory-offset type source-type right-type patch instruction-id
			pointer-offset division-magic wide? metadata spec
	][
		code: make binary! 128
		clear encoded-relocation-patches
		clear encoded-instruction-offsets
		clear jump-table-patches
		labels: make block! 16
		fixups: make block! 16
		constant-info: constant-use-info
		constant-values: constant-info/1
		immediate-constants: constant-info/2
		unless emit-spill-frame-reserve code [return none]
		unless emit-callee-save-registers code [return none]
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
			if find aligned-loop-blocks block-id [emit-code-alignment code body-base 32]
			rs-o2-ir/set-table-value labels block-id length? code
			terminal: last pick block rs-o2-ir/bb-instructions
			foreach instruction pick block rs-o2-ir/bb-instructions [
				instruction-id: pick instruction rs-o2-ir/ins-id
				rs-o2-ir/set-table-value encoded-instruction-offsets
					instruction-id
					length? code
				opcode: pick instruction rs-o2-ir/ins-opcode
				operands: pick instruction rs-o2-ir/ins-operands
				result: pick instruction rs-o2-ir/ins-result
				type: pick instruction rs-o2-ir/ins-type
				if same? instruction terminal [
					unless emit-phi-edge-copy code allocation block-id [return none]
				]
				case [
					opcode = 'const [
						unless find immediate-constants result [
							destination: result-register allocation result
							either supported-float? type [
								unless emit-float-constant code destination operands/1/2 type [return none]
							][
								emit-constant-immediate
									code instruction destination operands/1/2 type
							]
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
					opcode = 'bitcast [
						destination: result-register allocation result
						source: materialize-value code allocation operands/1/2
						unless all [destination source][return none]
						source-type: rs-o2-ir/vreg-type operands/1/2
						case [
							all [supported-float? type supported-i32? source-type][
								emit-gpr-to-xmm-bits code type destination source
							]
							all [supported-i32? type supported-float? source-type][
								emit-xmm-to-gpr-bits code source-type destination source
							]
							true [emit-gpr-move code type destination source]
						]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'convert [
						destination: result-register allocation result
						source: materialize-value code allocation operands/1/2
						unless all [destination source][return none]
						source-type: rs-o2-ir/vreg-type operands/1/2
						unless emit-scalar-conversion code type destination source-type source [return none]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'log-b [
						destination: result-register allocation result
						source: materialize-value code allocation operands/1/2
						unless all [destination source][return none]
						unless emit-log-b code destination source [return none]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'load-local [
						case [
							folded-load-name result []
							local-register: promoted-register operands/1/2 [
								destination: result-register allocation result
								either supported-float? type [
									emit-xmm-move code type destination local-register
								][emit-gpr-move code type destination local-register]
								unless emit-spilled-result code allocation result destination [return none]
							]
							frameless? [
								local-register: argument-register operands/1/2
								destination: result-register allocation result
								unless all [local-register destination][return none]
								emit-gpr-move code type destination local-register
								unless emit-spilled-result code allocation result destination [return none]
							]
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
					opcode = 'address-local [
						destination: result-register allocation result
						unless destination [return none]
						offset: stack-offset operands/1/2
						emit-frame-address code destination offset
						unless emit-spilled-result code allocation result destination [return none]
					]
					find [address-symbol address-global] opcode [
						destination: result-register allocation result
						unless destination [return none]
						patch: emit-rip-address code destination
						unless integer? patch [return none]
						record-encoded-relocation-patch instruction-id patch
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'aggregate-temp [
						unless emit-aggregate-temp code instruction allocation [return none]
					]
					opcode = 'typed-list [
						unless emit-typed-list code instruction allocation [return none]
					]
					opcode = 'keepalive []
					opcode = 'pack-aggregate [
						unless emit-pack-aggregate code instruction allocation [return none]
					]
					opcode = 'copy-aggregate [
						unless emit-copy-aggregate code instruction allocation [return none]
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
					opcode = 'load-global [
						destination: result-register allocation result
						unless destination [return none]
						spec: select emitter/symbols operands/1/2
						either all [spec spec/1 = 'import-var][
							either supported-float? type [
								patch: emit-import-variable-address code 'r11d
								emit-xmm-scalar-pointer-load code type destination 'r11d 0
							][
								patch: emit-import-variable-address code destination
								emit-gpr-pointer-load code type destination destination 0
							]
						][patch: emit-rip-load code type destination]
						record-encoded-relocation-patch instruction-id patch
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'store-global [
						source: materialize-value code allocation operands/2/2
						unless source [return none]
						source-type: rs-o2-ir/vreg-type operands/2/2
						spec: select emitter/symbols operands/1/2
						either all [spec spec/1 = 'import-var][
							patch: emit-import-variable-address code 'r11d
							either supported-float? source-type [
								emit-xmm-scalar-pointer-store code source-type 'r11d 0 source
							][emit-gpr-pointer-store code source-type 'r11d 0 source]
						][patch: emit-rip-store code source-type source]
						record-encoded-relocation-patch instruction-id patch
					]
					opcode = 'load-indirect [
						base: materialize-value code allocation operands/1/2
						destination: result-register allocation result
						unless all [base destination][return none]
						offset: operands/2/2
						either supported-float? type [
							emit-xmm-scalar-pointer-load code type destination base offset
						][emit-gpr-pointer-load code type destination base offset]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'load-aggregate-slot [
						base: materialize-value code allocation operands/1/2
						destination: result-register allocation result
						unless all [base destination][return none]
						metadata: pick instruction rs-o2-ir/ins-metadata
						either supported-float? type [
							emit-xmm-scalar-pointer-load code type destination base operands/2/2
						][
							unless emit-aggregate-slot-load
								code (select metadata 'width) destination base operands/2/2
							[return none]
						]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'address-indirect [
						base: materialize-value code allocation operands/1/2
						destination: result-register allocation result
						unless all [base destination][return none]
						offset: operands/2/2
						unless emit-lea-base-displacement code destination base offset [return none]
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'store-indirect [
						source-type: rs-o2-ir/vreg-type operands/3/2
						if all [
							operands/1/2 <> operands/3/2
							not supported-float? source-type
							(allocation-register allocation operands/1/2) = 'spill
							(allocation-register allocation operands/3/2) = 'spill
						][return fail-selection 'x64-indirect-dual-gpr-spill]
						base: materialize-value code allocation operands/1/2
						source: materialize-value code allocation operands/3/2
						unless all [base source][return none]
						offset: operands/2/2
						either supported-float? source-type [
							emit-xmm-scalar-pointer-store code source-type base offset source
						][emit-gpr-pointer-store code source-type base offset source]
					]
					find [atomic-load atomic-store atomic-math atomic-cas atomic-fence] opcode [
						unless emit-atomic-instruction code instruction allocation [return none]
					]
					supported-pointer-arithmetic? instruction [
						destination: result-register allocation result
						unless destination [return none]
						memory-name: folded-load-name operands/2/2
						right-value: all [
							find immediate-constants operands/2/2
							rs-o2-ir/table-value constant-values operands/2/2
						]
						either not none? right-value [
							left: materialize-value code allocation operands/1/2
							unless left [return none]
							pointer-offset: scaled-pointer-offset opcode right-value type/5
							unless integer? pointer-offset [
								return fail-selection 'x64-pointer-immediate-range
							]
							unless emit-lea-base-displacement
								code destination left pointer-offset
							[return none]
						][
							either memory-name [
								left: materialize-value code allocation operands/1/2
								unless left [return none]
								memory-offset: stack-offset memory-name
								unless emit-pointer-arithmetic-memory
									code opcode type destination left memory-offset
								[return none]
							][
								if all [
									(allocation-register allocation operands/1/2) = 'spill
									(allocation-register allocation operands/2/2) = 'spill
								][return fail-selection 'x64-pointer-double-spill]
								left: materialize-value code allocation operands/1/2
								right: materialize-value code allocation operands/2/2
								unless all [left right][return none]
								right-type: rs-o2-ir/vreg-type operands/2/2
								unless emit-pointer-arithmetic-register
									code opcode type right-type destination left right
								[return none]
							]
						]
						unless emit-spilled-result code allocation result destination [return none]
					]
					all [supported-i32? type supported-integer-division? opcode][
						destination: result-register allocation result
						unless destination [return none]
						if (allocation-register allocation operands/1/2) = 'ecx [
							return fail-selection 'x64-division-left-in-count-register
						]
						right-value: constant-vreg-value operands/2/2
						either integer? right-value [
							left: materialize-value code allocation operands/1/2
							unless left [return none]
							division-magic: signed-division-magic right-value
							either division-magic [
								unless emit-signed-i32-magic-division
									code opcode destination left right-value division-magic
								[return none]
							][
								emit-mov-immediate code 'ecx right-value
								unless emit-signed-i32-division code opcode destination left [return none]
							]
						][
							right: materialize-value code allocation operands/2/2
							unless right [return none]
							emit-mov-register code 'ecx right
							left: materialize-value code allocation operands/1/2
							unless left [return none]
							unless emit-signed-i32-division code opcode destination left [return none]
						]
						unless emit-spilled-result code allocation result destination [return none]
					]
					supported-shift? opcode [
						destination: result-register allocation result
						unless destination [return none]
						right-value: constant-vreg-value operands/2/2
						source-type: rs-o2-ir/vreg-type operands/1/2
						either integer? right-value [
							left: materialize-value code allocation operands/1/2
							unless left [return none]
							unless emit-shift-immediate
								code opcode destination left right-value source-type
							[return none]
						][
							if destination = 'ecx [
								return fail-selection 'x64-shift-count-destination
							]
							right: materialize-value code allocation operands/2/2
							unless right [return none]
							emit-mov-register code 'ecx right
							left: materialize-value code allocation operands/1/2
							unless left [return none]
							emit-mov-register code destination left
							unless emit-shift-register-count
								code opcode destination source-type
							[return none]
						]
						unless emit-spilled-result code allocation result destination [return none]
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
								all [
									not none? left-value
									rs-o2-ir/commutative-op? opcode
									any [memory-name integer? memory-offset]
								][
									if memory-name [memory-offset: stack-offset memory-name]
									emit-mov-immediate code destination left-value
									unless emit-binary-memory
										code opcode destination destination memory-offset
									[return none]
								]
								memory-name [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									memory-offset: stack-offset memory-name
									unless emit-binary-memory code opcode destination left memory-offset [
										return none
									]
								]
								left-memory-name [
									memory-offset: stack-offset left-memory-name
									either not none? right-value [
										emit-frame-load code destination memory-offset
										unless emit-binary-immediate code opcode destination destination right-value [
											return none
										]
									][
										right: materialize-value code allocation operands/2/2
										unless right [return none]
										unless emit-binary-memory code opcode destination right memory-offset [
											return none
										]
									]
								]
								not none? right-value [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									unless emit-binary-immediate code opcode destination left right-value [
										return none
									]
								]
								integer? memory-offset [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									unless emit-binary-memory code opcode destination left memory-offset [
										return none
									]
								]
								all [not none? left-value rs-o2-ir/commutative-op? opcode][
									right: materialize-value code allocation operands/2/2
									unless right [return none]
									unless emit-binary-immediate code opcode destination right left-value [
										return none
									]
								]
								true [
									left: materialize-value code allocation operands/1/2
									right: materialize-value code allocation operands/2/2
									unless all [left right][return none]
									either all [
										destination = right
										destination <> left
										not rs-o2-ir/commutative-op? opcode
										(allocation-register allocation operands/1/2) = 'spill
									][
										; The loaded spill scratch is dead after this use. Compute
										; there first so the right operand is not overwritten.
										unless emit-binary code opcode left left right [return none]
										emit-mov-register code destination left
									][
										unless emit-binary code opcode destination left right [return none]
									]
								]
							]
						]
						unless emit-spilled-result code allocation result destination [return none]
					]
					rs-o2-ir/comparison-op? opcode [
						source-type: rs-o2-ir/vreg-type operands/1/2
						wide?: supported-wide-gpr? source-type
						memory-name: folded-load-name operands/2/2
						memory-offset: none
						unless memory-name [
							if (allocation-register allocation operands/2/2) = 'spill [
								memory-offset: spill-offset operands/2/2
							]
						]
						either supported-float? source-type [
							left: materialize-value code allocation operands/1/2
							unless left [return none]
							case [
								memory-name [
									memory-offset: stack-offset memory-name
									emit-xmm-compare-memory code source-type left memory-offset
								]
								integer? memory-offset [
									emit-xmm-compare-memory code source-type left memory-offset
								]
								true [
									right: materialize-value code allocation operands/2/2
									unless right [return none]
									emit-xmm-compare code source-type left right
								]
							]
							if comparison-value-used? result [
								destination: result-register allocation result
								unless destination [return none]
								unless emit-materialized-float-condition code opcode destination [return none]
								unless emit-spilled-result code allocation result destination [return none]
							]
						][
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
									emit-compare-memory-immediate code wide? memory-offset left-value
								]
								all [not none? left-value integer? memory-offset] [
									emit-compare-memory-immediate code wide? memory-offset left-value
								]
								not none? left-value [
									right: materialize-value code allocation operands/2/2
									unless right [return none]
									emit-compare-immediate code wide? right left-value
								]
								true [
									left: materialize-value code allocation operands/1/2
									unless left [return none]
									case [
										memory-name [
											memory-offset: stack-offset memory-name
											emit-compare-memory code wide? left memory-offset
										]
										not none? right-value [
											emit-compare-immediate code wide? left right-value
										]
										integer? memory-offset [
											emit-compare-memory code wide? left memory-offset
										]
										true [
											right: materialize-value code allocation operands/2/2
											unless right [return none]
											emit-compare-registers code wide? left right
										]
									]
								]
							]
							if comparison-value-used? result [
								destination: result-register allocation result
								unless destination [return none]
								unless emit-materialized-condition
									code opcode source-type destination
								[return none]
								unless emit-spilled-result code allocation result destination [return none]
							]
						]
					]
					opcode = 'stack-push [
						unless emit-stack-push-instruction code instruction allocation [return none]
					]
					opcode = 'stack-pop [
						unless emit-stack-pop-instruction code instruction allocation [return none]
					]
					opcode = 'custom-call [
						unless emit-custom-call-instruction code instruction allocation [return none]
					]
					opcode = 'call [
						unless emit-direct-call code instruction allocation [return none]
					]
					opcode = 'resolve-node [
						unless emit-resolver-intrinsic code instruction allocation no [return none]
					]
					opcode = 'resolve-series [
						unless emit-resolver-intrinsic code instruction allocation yes [return none]
					]
					opcode = 'copy-cell [
						unless emit-copy-cell-intrinsic code instruction allocation [return none]
					]
					opcode = 'phi []
					opcode = 'switch [
						unless emit-sparse-switch-control code fixups instruction allocation [return none]
					]
					opcode = 'jump [
						target: operands/1/2
						unless target = next-id [
							emit-near-jump code fixups target pick instruction rs-o2-ir/ins-id
						]
					]
					opcode = 'branch [
						unless emit-branch-control code fixups instruction allocation next-id [return none]
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
		unless emit-callee-restore-registers code [return none]
		unless patch-relative-branches code labels fixups [return none]
		unless patch-jump-tables code labels [return none]
		code
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

	apply-relocations: func [
		direct-chunk [block!]
		/local start body-base relocation id ref patch patches counts index
	][
		if empty? planned-relocations [return yes]
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		body-base: either frameless? [0][start]
		counts: make block! 8
		foreach relocation planned-relocations [
			id: relocation/1
			ref: relocation/2
			patches: rs-o2-ir/table-value encoded-relocation-patches id
			index: any [rs-o2-ir/table-value counts id 0]
			index: index + 1
			rs-o2-ir/set-table-value counts id index
			patch: all [block? patches pick patches index]
			unless integer? patch [return fail-selection 'x64-missing-relocation-patch]
			ref/1: direct-chunk/3 + body-base + patch - 1
		]
		yes
	]

	commit-dropped-relocations: func [/local ref][
		foreach ref reverse copy dropped-relocation-refs [remove ref]
		yes
	]

	replace-body: func [direct-chunk [block!] body [binary!] /local bytes start ending selected prefix][
		bytes: direct-chunk/1
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		ending: pick rs-o2-ir/current rs-o2-ir/fn-body-end
		selected: copy direct-chunk
		if (length? selected) >= 2 [poke selected 2 copy selected-relocation-refs]
		if frameless? [
			bytes: copy body
			append-byte bytes 195
			poke selected 1 bytes
			unless apply-gc-bitmap selected [return none]
			return selected
		]
		bytes: make binary! (start + (length? body) + ((length? bytes) - ending))
		prefix: copy/part direct-chunk/1 start
		if fixed-shadow-frame-merge? [
			poke prefix start (32 + spill-frame-bytes)
		]
		append bytes prefix
		append bytes body
		append bytes skip direct-chunk/1 ending
		poke selected 1 bytes
		unless apply-gc-bitmap selected [return none]
		selected
	]

	select-current: func [
		direct-chunk [block!]
		/local intervals allocation body pass body-base selected start ending blocks
	][
		unless validate-current direct-chunk [return none]
		unless plan-call-argument-locations [return none]
		plan-folded-loads
		intervals: build-intervals
		unless intervals [return none]
		unless division-register-liveness-valid? intervals [return none]
		unless plan-call-spills intervals [return none]
		allocation: allocate-intervals intervals
		unless allocation [return none]
		plan-spill-slots intervals
		unless plan-fixed-shadow-frame-merge direct-chunk [return none]
		unless plan-phi-edge-copies allocation [return none]
		unless plan-gc-metadata intervals allocation direct-chunk [return none]
		unless rs-o2-ir/verify-current [return fail-selection 'x64-gc-safepoint-verification]
		unless verify-planned-safepoints intervals [return none]
		body-base: 0
		if all [(length? direct-chunk) >= 3 integer? direct-chunk/3][
			body-base: (direct-chunk/3 - 1) + (either frameless? [
				0
			][pick rs-o2-ir/current rs-o2-ir/fn-body-start])
		]
		clear relaxed-branches
		repeat pass 8 [
			branch-relaxation-changed?: no
			body: encode-body allocation body-base
			unless all [binary? body pick rs-o2-ir/current rs-o2-ir/fn-eligible?][return none]
			unless branch-relaxation-changed? [break]
		]
		if branch-relaxation-changed? [return fail-selection 'x64-branch-relaxation-limit]
		start: pick rs-o2-ir/current rs-o2-ir/fn-body-start
		ending: pick rs-o2-ir/current rs-o2-ir/fn-body-end
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
		if all [
			released-call-argument-fixed?
			(length? blocks) = 1
			(length? body) > (ending - start)
		][return fail-selection 'x64-call-live-expansion]
		unless apply-relocations direct-chunk [return none]
		selected: replace-body direct-chunk body
		unless selected [return none]
		commit-dropped-relocations
		selected
	]
]
