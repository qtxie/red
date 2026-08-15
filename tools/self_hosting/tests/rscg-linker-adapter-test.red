Red [
	Title: "Hybrid compiler minimal RSCG linker adapter tests"
]

do %../../../compiler/rscg-linker-adapter.red
; The complete Red verifier is a test oracle, not a hybrid product dependency.
do %../../../compiler/wire-rscg-metadata.red

schema: compiler-wire-schema
adapter: compiler-rscg-linker-adapter

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

fixture-file: none
foreach candidate reduce [
	to file! rejoin [system/options/path %codegen-bridge-integration.red]
	to file! rejoin [system/options/path %tools/self_hosting/tests/codegen-bridge-integration.red]
	to file! rejoin [system/options/path %../tests/codegen-bridge-integration.red]
][
	candidate: clean-path candidate
	if exists? candidate [fixture-file: candidate break]
]
assert file? fixture-file "cannot locate generated codegen bridge fixtures"
fixture-values: load/all read fixture-file
glue-rscg: select fixture-values to set-word! 'expected-glue-rscg
late-glue-rscg: select fixture-values to set-word! 'expected-late-name-glue-rscg
user-rscg: select fixture-values to set-word! 'expected-function-rscg
assert binary? glue-rscg "generated glue RSCG fixture is missing"
assert binary? late-glue-rscg "generated late-name glue RSCG fixture is missing"
assert binary? user-rscg "generated user RSCG fixture is missing"

make-job: does [
	make object! [
		format: 'PE
		OS: 'Windows
		target: 'X86-64
		ABI: 'win64
		type: 'exe
		link?: true
		runtime?: false
		debug?: false
		PIC?: false
		PIE?: false
		static-link?: false
		red-pass?: false
		libRed?: false
		libRedRT?: false
		libRedRT-update?: false
		sections: copy [original-sections]
		symbols: copy [original-symbols]
		debug-info: 'original-debug
	]
]

artifact: copy glue-rscg
artifact-before: copy artifact
job: make-job
assert adapter/adapt artifact job "adapter rejected its supported glue object"
assert none? adapter/last-error "adapter retained an error after success"
assert object? adapter/last-result "adapter did not publish its prepared result"
assert artifact = artifact-before "adapter mutated the RSCG artifact"
assert all [
	binary? job/sections/code/2
	job/sections/code/2 = #{554889E56A006A0068000000006A0031C94883EC20FF150000000031C0C9C3}
	binary? job/sections/data/2
	(length? job/sections/data/2) = 16
	job/sections/import/3 = ["kernel32.dll" ["ExitProcess" [24]]]
]["adapter produced the wrong legacy section buffers"]
assert (select job/symbols 'fn) = [native 1 []]
	"adapter produced the wrong one-based legacy function symbol"
assert all [
	adapter/last-result/entry-name = 'fn
	adapter/last-result/entry-offset = 0
	adapter/last-result/code-size = 31
	adapter/last-result/data-size = 16
]["adapter published incorrect entry metadata"]

; The linker buffers must not alias the verified wire message.
poke job/sections/code/2 1 144
assert artifact = artifact-before "legacy code buffer aliases the RSCG artifact"

job: make-job
assert adapter/adapt late-glue-rscg job
	"adapter rejected a glue object whose entry symbol sorts second"
assert (select job/symbols 'zz-entry) = [native 1 []]
	"adapter lost the remapped late-name entry symbol"
assert job/sections/import/3 = ["kernel32.dll" ["ExitProcess" [24]]]
	"adapter changed the remapped entry import"
assert adapter/last-result/entry-name = 'zz-entry
	"adapter published the wrong remapped entry name"

job: make-job
sections-before: job/sections
symbols-before: job/symbols
debug-before: job/debug-info
assert not adapter/adapt user-rscg job
	"adapter accepted an entryless USER object as an executable"
assert adapter/last-error/code = adapter/ERROR-LIFECYCLE
	"entryless object returned the wrong adapter error"
assert all [
	same? sections-before job/sections
	same? symbols-before job/symbols
	debug-before = job/debug-info
]["entryless failure partially mutated the linker job"]

job: make-job
job/PIC?: true
sections-before: job/sections
symbols-before: job/symbols
assert not adapter/adapt glue-rscg job "adapter accepted an unsupported PIC job"
assert adapter/last-error/code = adapter/ERROR-UNSUPPORTED-JOB
	"unsupported job returned the wrong adapter error"
assert all [
	same? sections-before job/sections
	same? symbols-before job/symbols
]["job validation failure partially mutated linker state"]

job: make-job
sections-before: job/sections
symbols-before: job/symbols
truncated: copy/part glue-rscg ((length? glue-rscg) - 1)
assert not adapter/adapt truncated job "adapter accepted a truncated RSCG object"
assert adapter/last-error/code = adapter/ERROR-INVALID-RSCG
	"truncated object returned the wrong adapter error"
assert all [
	same? sections-before job/sections
	same? symbols-before job/symbols
]["RSCG verification failure partially mutated linker state"]

container-result: compiler-wire-container/verify/expect glue-rscg schema/WIRE_MAGIC_RSCG
assert container-result/valid? "could not open the valid adapter fixture"

mutate-record: func [
	source [binary!]
	section [map!]
	id field value [integer!]
	/local mutated offset
][
	mutated: copy source
	offset: (select section 'payload-offset)
		+ ((id - 1) * (select section 'record-size))
		+ field
	change/part at mutated (offset + 1) int-to-bin/to-bin32 value 4
	mutated
]

assert-rejected-atomically: func [
	bad [binary!]
	expected [integer!]
	message [string!]
	/local job sections-before symbols-before debug-before
][
	job: make-job
	sections-before: job/sections
	symbols-before: job/symbols
	debug-before: job/debug-info
	assert not adapter/adapt bad job message
	assert adapter/last-error/code = expected [message " returned the wrong error"]
	assert all [
		same? sections-before job/sections
		same? symbols-before job/symbols
		debug-before = job/debug-info
	][message " partially mutated linker state"]
]

modules-section: compiler-wire-container/find-section container-result
	schema/WIRE_RSCG_SECTION_MODULES
bad-entry: mutate-record glue-rscg modules-section 1
	schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET 3
assert-rejected-atomically bad-entry adapter/ERROR-LIFECYCLE
	"adapter accepted an out-of-range entry symbol"

imports-section: compiler-wire-container/find-section container-result
	schema/WIRE_RSCG_SECTION_IMPORTS
bad-import-symbol: mutate-record glue-rscg imports-section 1
	schema/WIRE_IMPORT_SYMBOL_OFFSET 3
assert-rejected-atomically bad-import-symbol adapter/ERROR-IMPORT
	"adapter accepted an out-of-range import symbol"

outputs-section: compiler-wire-container/find-section container-result
	schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
bad-output-range: mutate-record glue-rscg outputs-section 2
	schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET 0
assert-rejected-atomically bad-output-range adapter/ERROR-SECTION
	"adapter accepted overlapping output-section data"

gc-section: compiler-wire-container/find-section container-result
	schema/WIRE_RSCG_SECTION_GC_FRAMES
bad-patch: mutate-record glue-rscg gc-section 1
	schema/WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET 1048576
assert-rejected-atomically bad-patch adapter/ERROR-GC-FRAME
	"adapter accepted an out-of-range GC prolog patch"

; A structurally valid but semantically different import must not be accepted
; as executable termination glue.
metadata: compiler-wire-rscg-metadata/verify glue-rscg
adapter-view: adapter/open-view glue-rscg
assert object? adapter-view "thin adapter could not open the verified fixture"
fn-string: 0
string-id: 1
while [string-id <= metadata/strings/record-count][
	if (adapter/string-at glue-rscg adapter-view string-id) = "fn" [
		fn-string: string-id
		break
	]
	string-id: string-id + 1
]
assert fn-string > 0 "could not locate the fixture function string"
wrong-import: copy glue-rscg
change/part at wrong-import (
	(select imports-section 'payload-offset)
	+ schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
	+ 1
) int-to-bin/to-bin32 fn-string 4
metadata: compiler-wire-rscg-metadata/verify wrong-import
assert metadata/valid? "wrong-import fixture stopped being structurally valid"
job: make-job
sections-before: job/sections
symbols-before: job/symbols
assert not adapter/adapt wrong-import job
	"adapter accepted a non-ExitProcess executable terminator"
assert adapter/last-error/code = adapter/ERROR-IMPORT
	"wrong executable import returned the wrong adapter error"
assert all [
	same? sections-before job/sections
	same? symbols-before job/symbols
]["import validation failure partially mutated linker state"]

assert not adapter/adapt none make-job "adapter accepted a non-binary artifact"
assert adapter/last-error/code = adapter/ERROR-ARGUMENTS
	"invalid adapter arguments returned the wrong error"

print "PASS: minimal RSCG linker adapter"
