Red [
	Title: "Hybrid compiler minimal RSIR semantic sink"
	File:  %rsir-sink.red
]

unless value? 'compiler-rsir-producer [do %rsir-producer.red]

; This is the first compiler-core semantic boundary.  It deliberately accepts
; only the shape implemented by the native codegen slice; unsupported input is
; a module-level failure and never falls back to the legacy emitter.
compiler-rsir-sink: context [
	ERROR-SUCCESS: 0
	ERROR-STATE: 1
	ERROR-UNSUPPORTED: 2
	ERROR-FUNCTION-COUNT: 3
	ERROR-PRODUCER: 4
	last-error: none

	set-error: func [state [object!] code [integer!] message [string!] /local record][
		record: make object! [code: 0 message: none]
		record/code: code
		record/message: message
		state/failed?: true
		state/error: record
		last-error: record
		false
	]

	new: func [
		module-name [string! none!]
		module-kind image-kind [integer!]
		/limit max-bytes [integer!]
		/local state
	][
		last-error: none
		state: make object! [
			module-name: none
			module-kind: 0
			image-kind: 0
			max-bytes: 0
			function-name: none
			function-count: 0
			finished?: false
			failed?: false
			error: none
		]
		state/module-name: either module-name [copy module-name][none]
		state/module-kind: module-kind
		state/image-kind: image-kind
		state/max-bytes: any [max-bytes compiler-rsir-producer/DEFAULT-MAX-BYTES]
		state
	]

	add-function: func [
		state [object!]
		function-name [word! string!]
		specs body
		/local function-text
	][
		last-error: none
		if state/failed? [
			last-error: state/error
			return false
		]
		case [
			state/finished? [
				return set-error state ERROR-STATE
					"RSIR semantic sink is already finished"
			]
			state/function-count <> 0 [
				return set-error state ERROR-FUNCTION-COUNT
					"RSIR semantic sink supports exactly one function"
			]
			not block? specs [
				return set-error state ERROR-UNSUPPORTED
					"RSIR semantic sink requires an empty function spec"
			]
			not empty? specs [
				return set-error state ERROR-UNSUPPORTED
					"RSIR semantic sink does not yet support parameters or return values"
			]
			not block? body [
				return set-error state ERROR-UNSUPPORTED
					"RSIR semantic sink requires a function body block"
			]
			not empty? body [
				return set-error state ERROR-UNSUPPORTED
					"RSIR semantic sink does not yet support nonempty function bodies"
			]
			true [
				function-text: either word? function-name [form function-name][copy function-name]
				unless compiler-rsir-producer/valid-name-bytes? function-text [
					return set-error state ERROR-UNSUPPORTED
						"RSIR semantic sink received an invalid function name"
				]
			]
		]
		state/function-name: function-text
		state/function-count: state/function-count + 1
		true
	]

	finish: func [state [object!] /local output producer-error message][
		last-error: none
		if state/failed? [
			last-error: state/error
			return none
		]
		if state/finished? [
			set-error state ERROR-STATE "RSIR semantic sink cannot be finished twice"
			return none
		]
		if state/function-count <> 1 [
			set-error state ERROR-FUNCTION-COUNT
				"RSIR semantic sink requires exactly one function before finish"
			return none
		]
		output: compiler-rsir-producer/build-empty-void-module/limit
			state/module-name
			state/function-name
			state/module-kind
			state/image-kind
			state/max-bytes
		unless binary? output [
			producer-error: compiler-rsir-producer/last-error
			message: either producer-error [
				rejoin ["RSIR producer failed: " producer-error/message]
			]["RSIR producer failed without a diagnostic"]
			set-error state ERROR-PRODUCER message
			return none
		]
		state/finished?: true
		output
	]
]
