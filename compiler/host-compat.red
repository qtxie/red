Red [
	Title: "Rebol host compatibility mezzanines for the self-hosted compiler"
	File:  %host-compat.red
	Notes: {
		Adapted from commit 688f2bdc (system/compiler.red host helpers).
		Red does not ship these mezzanines; both the Red frontend and the
		Red/System backend need them under a pure Red host.
	}
]

encap?: no

reform: func [v][form reduce v]

join: func [
	"Concatenates values."
	value "Base value"
	rest "Value or block of values"
][
	value: either series? value [copy value] [form value]
	append value rest
]

found?: func [
	"Returns TRUE if value is not NONE."
	value
][
	not none? :value
]

; Optional helpers kept for future R/S compiler paths that still use them.
for: func [
	"Repeats a block over a range of values."
	'word [word!]
	start [number! series! money! time! date! char!]
	end [number! series! money! time! date! char!]
	bump [number! money! time! char!]
	body [block!]
	/local result do-body compare
][
	if (type? start) <> (type? end) [
		cause-error 'script 'expect-arg ['for 'end type? start]
	]
	do-body: func reduce [word] body
	compare: either negative? bump [:lesser-or-equal?][:greater-or-equal?]
	either series? start [
		if not same? head start head end [
			cause-error 'script 'invalid-arg [end]
		]
		while [compare index? end index? start] [
			set/any 'result do-body start
			start: skip start bump
		]
		if negative? bump [set/any 'result do-body start]
	][
		while [compare end start] [
			set/any 'result do-body start
			start: start + bump
		]
	]
	get/any 'result
]

forskip: func [
	"Evaluates a block for periodic values in a series."
	'word [word!]
	skip-num [integer!]
	body [block!]
	/local orig result
][
	orig: get word
	while [any [not tail? get word (set word orig false)]] [
		set/any 'result do body
		set word skip get word skip-num
		get/any 'result
	]
]

array: func [
	"Makes and initializes a series of a given size."
	size [integer! block!]
	/initial value
	/local block rest
][
	if block? size [
		rest: next size
		if tail? rest [rest: none]
		size: first size
		unless integer? size [cause-error 'user 'message ["Integer size required"]]
	]
	block: make block! size
	case [
		block? rest [
			loop size [block: insert/only block array/initial rest :value]
		]
		series? :value [
			loop size [block: insert/only block copy/deep value]
		]
		any-function? :value [
			loop size [block: insert/only block value]
		]
		true [
			insert/dup block value size
		]
	]
	head block
]
