Red/System [
	Title: "Hybrid compiler Windows x64 O0 codegen substrate tests"
]

#include %../../../system/codegen/x64-o0-codegen.reds

failures: 0
records: #{00000000000000000000000002000000}
data: #{666E}
strings: declare wire-string-table!
strings/records: as byte-ptr! records
strings/record-count: 2
strings/record-size: WIRE_STRING_SIZE
strings/records-offset: 0
strings/records-ordinal: 0
strings/data: as byte-ptr! data
strings/data-size: 2
strings/data-offset: 0
strings/data-ordinal: 0

cursor: declare wire-codegen-string-cursor!
wire-codegen-strings/reset-cursor cursor
item-id: 1
status: wire-codegen-strings/advance strings/records strings/record-count
	strings/data cursor wire-codegen-strings/BASE_EXTRA_COUNT
while [status = wire-codegen-strings/ITEM_READY][
	case [
		item-id = 1 [
			unless all [
				cursor/size = 0
				cursor/item-input-id = 1
				cursor/item-extra-id = 0
			][
				failures: failures + 1
			]
		]
		item-id = 2 [
			unless all [
				cursor/size = 5
				cursor/item-input-id = 0
				cursor/item-extra-id = 1
			][
				failures: failures + 1
			]
			if (compare-memory cursor/data (as byte-ptr! ".data") 5) <> 0 [
				failures: failures + 1
			]
		]
		item-id = 3 [
			unless all [
				cursor/size = 5
				cursor/item-input-id = 0
				cursor/item-extra-id = 2
			][
				failures: failures + 1
			]
			if (compare-memory cursor/data (as byte-ptr! ".text") 5) <> 0 [
				failures: failures + 1
			]
		]
		item-id = 4 [
			unless all [
				cursor/size = 2
				cursor/item-input-id = 2
				cursor/item-extra-id = 0
			][
				failures: failures + 1
			]
			if (compare-memory cursor/data (as byte-ptr! "fn") 2) <> 0 [
				failures: failures + 1
			]
		]
		true [failures: failures + 1]
	]
	item-id: item-id + 1
	status: wire-codegen-strings/advance strings/records strings/record-count
		strings/data cursor wire-codegen-strings/BASE_EXTRA_COUNT
]
if status <> wire-codegen-strings/ITEM_DONE [failures: failures + 1]
if item-id <> 5 [failures: failures + 1]

arena: declare wire-arena!
writer: declare wire-container-writer!
string-map: declare wire-codegen-string-map!
wire-arena/reset arena
status: wire-container-writer/begin writer arena 2048 WIRE_RSCG_MINIMUM_SIZE
	WIRE_MAGIC_RSCG WIRE_TARGET_X86_64 WIRE_ABI_WIN64 WIRE_ENDIAN_LITTLE
	8 0 0 1 WIRE_RSCG_REQUIRED_SECTION_COUNT
if status = 0 [
	status: wire-container-writer/empty-section writer
		WIRE_RSCG_SECTION_DATA_LAYOUT 0
]
if status = 0 [
	status: wire-codegen-strings/write-sections writer strings 0 2
		wire-codegen-strings/BASE_EXTRA_COUNT string-map
]
unless all [
	status = 0
	string-map/module-name = 0
	string-map/function-name = 4
	string-map/data-section-name = 2
	string-map/code-section-name = 3
][failures: failures + 1]
wire-arena/release arena

either failures = 0 [
	print ["PASS: Windows x64 O0 codegen substrate" lf]
][
	print ["FAIL: Windows x64 O0 substrate failures=" failures lf]
]
quit failures
