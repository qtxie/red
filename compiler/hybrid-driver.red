Red [
	Title: "Hybrid compiler strict codegen driver"
	File:  %hybrid-driver.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-rscf-producer [do %rscf-producer.red]
unless value? 'compiler-wire-diagnostics [do %wire-diagnostics.red]

; The standard compiler installs no backend hooks. A hybrid package replaces
; both hooks together and sets installed? only after routine and adapter code
; are available. Every successful linked RSIR job crosses each hook once.
compiler-hybrid-driver: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	config-producer: compiler-rscf-producer
	diagnostic-verifier: compiler-wire-diagnostics

	ERROR-SUCCESS: 0
	ERROR-NOT-INSTALLED: 1
	ERROR-CONFIGURATION: 2
	ERROR-CODEGEN: 3
	ERROR-DIAGNOSTIC: 4
	ERROR-CONTRACT: 5
	ERROR-ADAPTER: 6

	installed?: false
	last-error: none
	last-status: -1
	last-config: none
	last-artifact: none
	last-diagnostics: none

	; Replaced by system/compiler-windows-hybrid-bootstrap.red. These defaults
	; make an incomplete package fail closed rather than selecting legacy code.
	invoke-codegen: func [ir config artifact diagnostics][
		schema/WIRE_STATUS_INVALID_ARGUMENTS
	]
	invoke-adapter: func [artifact job][false]
	adapter-message: does ["hybrid RSCG adapter is not installed"]

	set-error: func [
		code [integer!]
		message [string!]
		status [integer!]
		/local record
	][
		record: make object! [code: 0 message: none status: -1]
		record/code: code
		record/message: message
		record/status: status
		last-error: record
		none
	]

	reset: does [
		last-error: none
		last-status: -1
		last-config: none
		last-artifact: none
		last-diagnostics: none
	]

	diagnostic-summary: func [
		data [binary!]
		expected-status [integer!]
		/local summary verified view strings record-offset message-id string-record
			string-offset string-size start
	][
		summary: make object! [valid?: true present?: false message: none]
		if empty? data [return summary]
		summary/present?: true
		verified: diagnostic-verifier/verify data schema/WIRE_MAGIC_RSDG
		unless verified/valid? [
			summary/valid?: false
			summary/message: rejoin [
				"native codegen returned invalid RSDG error=" verified/error
				" at " verified/error-offset ":" verified/error-section
			]
			return summary
		]
		view: verified/view
		if view/status <> expected-status [
			summary/valid?: false
			summary/message: rejoin [
				"native codegen status " expected-status
				" disagrees with RSDG status " view/status
			]
			return summary
		]
		strings: verified/strings
		record-offset: view/records-offset
		message-id: container/read-i31 data
			(record-offset + schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET)
		string-record: strings/records-offset
			+ ((message-id - 1) * schema/WIRE_STRING_SIZE)
		string-offset: container/read-i31 data
			(string-record + schema/WIRE_STRING_OFFSET_OFFSET)
		string-size: container/read-i31 data
			(string-record + schema/WIRE_STRING_SIZE_OFFSET)
		start: strings/data-offset + string-offset
		summary/message: to string! copy/part at data (start + 1) string-size
		summary
	]

	generate: func [
		ir [binary!]
		job [object!]
		/local config artifact diagnostics status summary
	][
		reset
		unless installed? [
			return set-error ERROR-NOT-INSTALLED
				"RSIR linking requires the installed native codegen package" -1
		]
		config: config-producer/build job
		unless binary? config [
			return set-error ERROR-CONFIGURATION
				config-producer/last-error/message -1
		]
		last-config: copy config
		; A zero-capacity binary may use the runtime's shared empty series node.
		; The routine contract requires all four series nodes to be distinct.
		artifact: make binary! 1
		diagnostics: make binary! 1
		set/any 'status try [invoke-codegen ir config artifact diagnostics]
		if error? :status [
			return set-error ERROR-CONTRACT
				rejoin ["native codegen raised an error: " mold status] -1
		]
		unless integer? status [
			return set-error ERROR-CONTRACT
				"native codegen returned a noninteger status" -1
		]
		last-status: status
		last-diagnostics: copy diagnostics
		unless all [
			status >= schema/WIRE_STATUS_SUCCESS
			status <= schema/WIRE_STATUS_INVALID_ARTIFACT
		][
			return set-error ERROR-CONTRACT
				rejoin ["native codegen returned unknown status " status] status
		]
		if all [status <> schema/WIRE_STATUS_SUCCESS not empty? artifact][
			return set-error ERROR-CONTRACT
				"native codegen committed an artifact on failure" status
		]
		summary: diagnostic-summary diagnostics status
		unless summary/valid? [
			return set-error ERROR-DIAGNOSTIC summary/message status
		]
		if status <> schema/WIRE_STATUS_SUCCESS [
			return set-error ERROR-CODEGEN any [
				summary/message rejoin ["native codegen failed with status " status]
			] status
		]
		if summary/present? [
			return set-error ERROR-CONTRACT
				"native codegen returned diagnostics on success" status
		]
		if empty? artifact [
			return set-error ERROR-CONTRACT
				"native codegen returned success without an RSCG artifact" status
		]
		last-artifact: copy artifact
		last-artifact
	]

	adapt: func [
		artifact [binary!]
		job [object!]
		/local adapted message
	][
		last-error: none
		unless installed? [
			set-error ERROR-NOT-INSTALLED
				"RSIR linking requires the installed RSCG adapter" -1
			return false
		]
		set/any 'adapted try [invoke-adapter artifact job]
		if error? :adapted [
			set-error ERROR-CONTRACT
				rejoin ["RSCG adapter raised an error: " mold adapted] last-status
			return false
		]
		unless logic? adapted [
			set-error ERROR-CONTRACT
				"RSCG adapter returned a non-logic result" last-status
			return false
		]
		unless adapted [
			message: attempt [adapter-message]
			unless string? message [message: "RSCG adapter rejected the native artifact"]
			set-error ERROR-ADAPTER message last-status
			return false
		]
		true
	]
]
