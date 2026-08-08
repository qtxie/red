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

	r11-scratch-reserved?: does [
		any [function-has-switch? function-has-pointer-arithmetic?]
	]

	reserved-gpr-register?: func [register [word!]][
		any [
			all [function-needs-shift-count-register? register = 'ecx]
			all [function-needs-division-registers? find [eax ecx edx] register]
			all [r11-scratch-reserved? register = 'r11d]
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
				if find [call resolve-series] pick instruction rs-o2-ir/ins-opcode [return yes]
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
				if find [call resolve-series] opcode [return no]
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
		/local maximum abi block instruction operands argument-index operand offset
	][
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

	constant-vreg-value: func [id [integer!] /local definition operands][
		definition: rs-o2-ir/find-vreg-definition id
		unless all [
			definition
			(pick definition rs-o2-ir/ins-opcode) = 'const
			operands: pick definition rs-o2-ir/ins-operands
			(length? operands) = 1
			operands/1/1 = 'imm
			integer? operands/1/2
		][return none]
		operands/1/2
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

	return-register: func [type][
		either supported-float? type ['xmm0]['eax]
	]

	validate-operands: func [
		instruction [block!]
		/local opcode operands stack-entry name result type operand left-type right-type position
			resolver-name metadata condition-kind condition-type variadic?
			pointer-operation? pointer-constant shift-constant base-type value-type
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
			opcode = 'bitcast [
				unless all [result (length? operands) = 1 operands/1/1 = 'vreg][
					return fail-selection 'x64-bitcast-shape
				]
				operand: rs-o2-ir/vreg-type operands/1/2
				unless all [
					supported-gpr-scalar? type
					supported-gpr-scalar? operand
					type/2 = operand/2
			][return fail-selection 'x64-bitcast-type]
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
			opcode = 'load-global [
				unless all [
					result
					(length? operands) = 1
					operands/1/1 = 'global
				][return fail-selection 'x64-global-load-shape]
			]
			opcode = 'store-global [
				unless all [
					(length? operands) = 2
					operands/1/1 = 'global
					operands/2/1 = 'vreg
				][return fail-selection 'x64-global-store-shape]
				operand: rs-o2-ir/vreg-type operands/2/2
				unless any [supported-gpr-scalar? operand supported-float? operand][
					return fail-selection 'x64-global-store-type
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
				unless all [supported-wide-gpr? base-type base-type/1 = 'ptr][
					return fail-selection 'x64-indirect-base-type
				]
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
				unless all [supported-wide-gpr? base-type base-type/1 = 'ptr][
					return fail-selection 'x64-indirect-base-type
				]
				unless any [supported-gpr-scalar? value-type supported-float? value-type][
					return fail-selection 'x64-indirect-store-type
				]
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
				if supported-integer-division? opcode [
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
				opcode = 'call [
					unless all [
						not empty? operands
						operands/1/1 = 'symbol
					][return fail-selection 'x64-call-shape]
					foreach operand next operands [
						unless operand/1 = 'vreg [return fail-selection 'x64-call-argument]
					]
					metadata: pick instruction rs-o2-ir/ins-metadata
					unless all [block? metadata find metadata 'variadic][
						return fail-selection 'x64-call-metadata
					]
					variadic?: select metadata 'variadic
					unless logic? variadic? [return fail-selection 'x64-call-metadata]
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
			spec: select emitter/symbols name
			unless all [
				spec
				block? spec/3
			][return fail-selection 'x64-relocation-symbol]
			valid-symbol?: case [
				kind = 'call-rel32 [
					any [
						all [opcode = 'call find [native import] spec/1]
						all [
							opcode = 'resolve-series
							name = 'red>resolve-series
							spec/1 = 'native
						]
					]
				]
				kind = 'rip-rel32 [
					case [
						opcode = 'store-global [spec/1 = 'global]
						opcode = 'load-global [find [global constant] spec/1]
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

	build-intervals: func [
		/local intervals blocks block instruction use-position definition-position operand interval
			result opcode operands preferred fixed return-interval
			store-targets register existing existing-fixed argument-index call-operand
			position predecessor terminal phi-interval
	][
		intervals: make block! 16
		blocks: pick rs-o2-ir/current rs-o2-ir/fn-blocks
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
							argument-register operands/1/2
						][
							promoted-register operands/1/2
						]
					]
					if find [call copy-cell resolve-node resolve-series] opcode [
						fixed: return-register pick instruction rs-o2-ir/ins-type
					]
					if all [opcode = 'phi (length? operands) >= 2][
						preferred: operands/2/2
					]
					if all [
						any [find [copy bitcast log-b] opcode supported-binary-operation? opcode]
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
		foreach block blocks [
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
		foreach block blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if (pick instruction rs-o2-ir/ins-opcode) = 'phi [
					phi-interval: find-interval intervals pick instruction rs-o2-ir/ins-result
					fixed: all [phi-interval pick phi-interval interval-fixed]
					if fixed [
						operands: pick instruction rs-o2-ir/ins-operands
						position: operands
						while [not tail? position][
							interval: find-interval intervals position/2/2
							if all [interval none? pick interval interval-fixed][
								poke interval interval-fixed fixed
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
		/local block instruction position interval type
	][
		foreach interval intervals [poke interval interval-call-live no]
		foreach block pick rs-o2-ir/current rs-o2-ir/fn-blocks [
			foreach instruction pick block rs-o2-ir/bb-instructions [
				if find [call resolve-series] pick instruction rs-o2-ir/ins-opcode [
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
			if all [
				pick interval interval-call-live
				pick interval interval-call-fixed
			][
				poke interval interval-fixed none
				poke interval interval-call-fixed no
				type: rs-o2-ir/vreg-type pick interval interval-id
				if all [
					rs-o2-ir/valid-type? type
					type/3 = 'gpr
					type/6 = 'none
				][released-call-argument-fixed?: yes]
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
				if supported-integer-division? pick instruction rs-o2-ir/ins-opcode [
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
		/local interval id type fixed
	][
		clear call-spilled-values
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
				either any [type/3 <> 'gpr type/6 <> 'none][
					append call-spilled-values id
				][
					fixed: pick interval interval-fixed
					if all [fixed not callee-saved-register? fixed][
						append call-spilled-values id
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
				either r11-scratch-reserved? [copy [r10d]][copy [r11d r10d]]
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
					preferred-register: allocation-register allocation preferred
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
				if find [call resolve-series] pick instruction rs-o2-ir/ins-opcode [
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
		value [integer!]
		type [block!]
	][
		either all [
			supported-i32? type
			destination = 'eax
			value = 1
			empty? loop-blocks
			not flags-consumed-after? pick instruction rs-o2-ir/ins-id
		][
			append code #{31C0FFC0}                 ;-- XOR EAX,EAX / INC EAX
		][emit-mov-immediate code destination value]
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
		;-- Scalar ABI stack arguments occupy eight-byte slots. A full-slot store
		;-- also forwards to the callee's qword slot copy without a width mismatch.
		emit-rex code yes src none 4
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
		emit-rex code supported-wide-gpr? type dst none src
		append-byte code 139
		emit-pointer-displacement-modrm code dst src offset
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
		emit-rex code supported-wide-gpr? type src none dst
		append-byte code 137
		emit-pointer-displacement-modrm code src dst offset
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
		][
			dst: register-code destination
			emit-rex code supported-wide-gpr? type dst none 5
			append-byte code 139
		]
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
		][
			src: register-code source
			emit-rex code supported-wide-gpr? type src none 5
			append-byte code 137
		]
		emit-modrm code 0 src 5
		patch: (length? code) + 1
		append code #{00000000}
		patch
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

	immediate-use?: func [instruction [block!] index [integer!] /local opcode][
		opcode: pick instruction rs-o2-ir/ins-opcode
		any [
			all [opcode = 'return index = 1]
			all [supported-binary? opcode index = 2]
			all [supported-shift? opcode index = 2]
			all [supported-integer-division? opcode index = 2]
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

	emit-direct-call: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		/local patch id result type source operands callee spec abi
	][
		unless emit-promoted-local-stores code [return none]
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
		result: pick instruction rs-o2-ir/ins-result
		if result [
			type: pick instruction rs-o2-ir/ins-type
			source: return-register type
			unless emit-spilled-result code allocation result source [return none]
		]
		unless emit-promoted-local-reloads code [return none]
		yes
	]

	emit-resolver-intrinsic: func [
		code [binary!]
		instruction [block!]
		allocation [block!]
		series? [logic!]
		/local instruction-id result result-location abi handle expected-handle
			global-patch patch slow-patches done-patch slow-target done-target
	][
		unless emit-call-argument-moves code instruction allocation [return none]
		instruction-id: pick instruction rs-o2-ir/ins-id
		result: pick instruction rs-o2-ir/ins-result
		result-location: allocation-register allocation result
		abi: pick rs-o2-ir/current rs-o2-ir/fn-abi
		handle: call-argument-register instruction 1
		expected-handle: either abi = 'win64 ['ecx]['edi]
		unless all [
			handle = expected-handle
			find [eax spill] result-location
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
		emit-spilled-result code allocation result 'eax
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
		either all [type valid-pointer-type? type] [
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
		either opcode = 'truthy [
			operand-type: rs-o2-ir/vreg-type operands/1/2
			unless supported-logic? operand-type [return fail-selection 'x64-branch-condition-type]
			source: materialize-value code allocation operands/1/2
			unless source [return none]
			emit-test-register code source
			float?: no
			condition: 5
		][
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
				case [
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
			pointer-offset division-magic wide?
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
							emit-constant-immediate
								code instruction destination operands/1/2 type
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
						emit-gpr-move code type destination source
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
					opcode = 'load-global [
						destination: result-register allocation result
						unless destination [return none]
						patch: emit-rip-load code type destination
						record-encoded-relocation-patch instruction-id patch
						unless emit-spilled-result code allocation result destination [return none]
					]
					opcode = 'store-global [
						source: materialize-value code allocation operands/2/2
						unless source [return none]
						source-type: rs-o2-ir/vreg-type operands/2/2
						patch: emit-rip-store code source-type source
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
					supported-integer-division? opcode [
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
