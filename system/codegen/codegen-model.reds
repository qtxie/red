Red/System [
	Title: "Hybrid compiler RSIR and native image records"
	File:  %codegen-model.reds
]

rsir-header!: alias struct! [
	module-kind       [integer!]
	entry-function    [integer!]
	type-count        [integer!]
	import-count      [integer!]
	function-count    [integer!]
	instruction-count [integer!]
	global-count      [integer!]
	switch-count      [integer!]
	export-count      [integer!]
]

rsir-type!: alias struct! [
	kind         [integer!]
	target       [integer!]
	flags        [integer!]
	first-member [integer!]
	member-count [integer!]
]

rsir-member!: alias struct! [
	type  [integer!]
	flags [integer!]
]

rsir-import!: alias struct! [
	library         [integer!]
	library-size    [integer!]
	external        [integer!]
	external-size   [integer!]
	type             [integer!]
	flags            [integer!]
	first-parameter  [integer!]
	parameter-count  [integer!]
]

rsir-global!: alias struct! [
	name              [integer!]
	name-size         [integer!]
	type              [integer!]
	flags             [integer!]
	first-initializer [integer!]
	initializer-count [integer!]
]

rsir-function!: alias struct! [
	name              [integer!]
	name-size         [integer!]
	return-type       [integer!]
	flags             [integer!]
	first-parameter   [integer!]
	parameter-count   [integer!]
	first-local       [integer!]
	local-count       [integer!]
	instruction-count [integer!]
]

rsir-export!: alias struct! [
	symbol    [integer!]
	name      [integer!]
	name-size [integer!]
]

rsir-parameter!: alias struct! [
	type  [integer!]
	flags [integer!]
]

rsir-initializer!: alias struct! [
	kind [integer!]
	a    [integer!]
	b    [integer!]
	c    [integer!]
]

rsir-instruction!: alias struct! [
	op [integer!]
	a  [integer!]
	b  [integer!]
	c  [integer!]
]

rsir-switch!: alias struct! [
	low    [integer!]
	high   [integer!]
	target [integer!]
]

codegen-header!: alias struct! [
	size            [integer!]
	module-kind     [integer!]
	entry-function  [integer!]
	function-count  [integer!]
	import-count    [integer!]
	reference-count [integer!]
	names-size      [integer!]
	code-offset     [integer!]
	code-size       [integer!]
	data-size       [integer!]
	global-count    [integer!]
	rodata-size     [integer!]
	export-count    [integer!]
]

codegen-function!: alias struct! [
	name            [integer!]
	name-size       [integer!]
	code-offset     [integer!]
	code-size       [integer!]
	frame-size      [integer!]
	bitmap-offset   [integer!]
	bitmap-size     [integer!]
	first-reference [integer!]
	reference-count [integer!]
]

codegen-global!: alias struct! [
	name            [integer!]
	name-size       [integer!]
	data-offset     [integer!]
	data-size       [integer!]
	first-reference [integer!]
	reference-count [integer!]
	flags           [integer!]
]

codegen-import!: alias struct! [
	library         [integer!]
	library-size    [integer!]
	external        [integer!]
	external-size   [integer!]
	first-reference [integer!]
	reference-count [integer!]
]

codegen-export!: alias struct! [
	symbol    [integer!]
	name      [integer!]
	name-size [integer!]
]

signature-pairs!: alias struct! [
	memory        [byte-ptr!]
	pair-count    [integer!]
	pair-capacity [integer!]
	slot-capacity [integer!]
	epoch         [integer!]
]

type-table!: alias struct! [
	types          [byte-ptr!]
	members        [byte-ptr!]
	type-count     [integer!]
	layouts        [int-ptr!]
	member-offsets [int-ptr!]
	signatures     [signature-pairs!]
]

rsir-module!: alias struct! [
	table             [type-table!]
	parameters        [byte-ptr!]
	functions         [byte-ptr!]
	imports           [byte-ptr!]
	globals           [byte-ptr!]
	switches          [byte-ptr!]
	instructions      [byte-ptr!]
	strings           [byte-ptr!]
	function-count    [integer!]
	import-count      [integer!]
	global-count      [integer!]
	switch-count      [integer!]
	instruction-count [integer!]
	strings-size      [integer!]
]
