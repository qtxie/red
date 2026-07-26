Red [
	Title: "Red self-hosting compiler entrypoint"
	File:  %red-selfhost.red
]

compiler-root: system/options/path

#include %compiler/target-registry.red
#include %compiler/system-job.red
#include %compiler/lexer.red
#include %compiler/system-source.red
#include %compiler/system-loader.red
#include %compiler/int-to-bin.red
#include %compiler/system-target-class.red
#include %compiler/system-types.red
#include %compiler/system-layout.red
#include %compiler/system-emitter.red
#include %compiler/system-diagnostics.red
#include %compiler/source-parity.red
#include %compiler/ieee-754.red
#include %compiler/unicode.red
#include %compiler/paths.red
#include %compiler/preprocessor.red
#include %compiler/source-loader.red
#include %compiler/virtual-struct.red
#include %compiler/sha256.red
#include %compiler/redbin.red
#include %compiler/extractor.red
#include %compiler/phase-timer.red
#include %compiler/binding-identity.red
#include %compiler/options.red

selfhost-version: "0.6.6-selfhost.0"

print-usage: does [
	print "Usage: red-selfhost --version | --list-targets | --check-all | --check-registry | --check-system-job | --check-system-target | --check-system-types | --check-system-layout | --check-system-emitter | --check-system-diagnostics | --check-system-compiler-source | --check-system-backend-source | --check-lexer | --check-system-source | --check-system-loader | --check-preprocessor | --check-source-loader | --check-redbin | --check-encoding | --check-floats | --check-unicode | --check-paths | --check-structs | --check-sha256 | --check-runtime-ids | --check-timing | --check-bindings | --check-options"
]

check-system-job: has [linux windows priority invalid][
	linux: compiler-system-job/new 'Linux-X86-64
	compiler-system-job/apply-header linux [
		Title: "job fixture"
		Config: [red-strict-check?: false GUI-engine: 'test]
	]
	compiler-system-job/for-source linux %samples/hello.reds
	windows: compiler-system-job/new 'Windows-X86-64-DLL
	priority: compiler-system-job/new 'Linux
	priority/command-line: [red-strict-check? true]
	compiler-system-job/apply-header priority [Config: [red-strict-check?: false]]
	invalid: compiler-system-job/new 'not-a-target
	either all [
		object? linux
		linux/config-name = 'Linux-X86-64
		linux/OS = 'Linux
		linux/target = 'X86-64
		linux/PIC?
		linux/PIE?
		not linux/red-strict-check?
		linux/GUI-engine = 'test
		linux/build-basename = %hello
		object? windows
		windows/type = 'DLL
		not windows/PIE?
		priority/red-strict-check?
		none? invalid
		object? compiler-system-job/last-error
	][
		print "Red/System job configuration: OK"
		0
	][
		print [
			"Red/System job configuration mismatch:"
			mold linux
			mold windows
			mold compiler-system-job/last-error
		]
		1
	]
]

check-system-target: has [target arguments classes][
	target: make compiler-system-target-class []
	arguments: reduce [true 42]
	classes: target/get-arguments-class arguments
	either all [
		(target/opposite? to word! "=") = to word! "<>"
		(target/opposite? 'overflow?) = 'not-overflow?
		(target/power-of-2? 1) = 0
		(target/power-of-2? 1024) = 10
		none? target/power-of-2? 12
		(target/stack-encode -128) = #{80}
		(target/stack-encode 127) = #{7F}
		(target/stack-encode -129) = #{7FFFFFFF}
		(target/stack-encode 128) = #{80000000}
		classes = [imm imm]
		arguments/1 = 1
	][
		print "Red/System target contract: OK"
		0
	][
		print ["Red/System target contract mismatch:" mold classes]
		1
	]
]

check-system-types: has [types target layout alias tagged i64 min-i64 max-u64 wide-hex][
	target: make object! [ptr-size: 8 stack-width: 8 struct-align-size: 4]
	layout: compiler-system-layout
	types: compiler-system-types
	types/reset
	layout/connect target
	types/register-alias 'machine-word [uint64!]
	alias: types/resolve-aliased [machine-word]
	tagged: types/normalize-union-spec [[variant] none [byte!] wide [uint64!]]
	i64: types/int64-literal-info to issue! "i64-2147483648"
	min-i64: types/int64-literal-info to issue! "i64-n9223372036854775808"
	max-u64: types/int64-literal-info to issue! "u64-18446744073709551615"
	wide-hex: types/int64-literal-info to issue! "u64h-7FFFFFFFFFFFFFFF"
	either all [
		types/integer-type? [uint16!]
		types/signed-integer? [int16!]
		types/unsigned-integer? [uint16!]
		(types/integer-width? [uint64!]) = 8
		types/lossless-integer-cast? [uint16!] [integer!]
		not types/lossless-integer-cast? [integer!] [uint32!]
		alias = [uint64!]
		types/tagged-union? tagged
		(types/union-variant-id? tagged 'wide) = 2
		(types/union-tag-type? tagged) = [uint8!]
		i64 = [int64! "0000000080000000"]
		min-i64 = [int64! "8000000000000000"]
		max-u64 = [uint64! "FFFFFFFFFFFFFFFF"]
		wide-hex = [int64! "7FFFFFFFFFFFFFFF"]
		(types/int-literal-hex -1 'int16!) = "FFFF"
	][
		print "Red/System type service: OK"
		0
	][
		print ["Red/System type service mismatch:" mold i64 mold min-i64 mold max-u64]
		1
	]
]

check-system-layout: has [
	types target32 target64 layout struct plain-union tagged-union checks32 checks64
][
	target32: make object! [ptr-size: 4 stack-width: 4 struct-align-size: 4]
	target64: make object! [ptr-size: 8 stack-width: 8 struct-align-size: 4]
	struct: [small [byte!] count [integer!] wide [uint64!]]
	layout: compiler-system-layout
	types: compiler-system-types
	types/reset
	layout/connect target32
	plain-union: types/normalize-union-spec [small [byte!] wide [uint64!]]
	tagged-union: types/normalize-union-spec [[variant] small [byte!] wide [uint64!]]
	checks32: all [
		(layout/size-of? 'pointer!) = 4
		layout/signed? 'int16!
		not layout/signed? 'uint16!
		(layout/member-offset? struct 'count) = 4
		(layout/member-offset? struct 'wide) = 8
		(layout/member-offset? struct none) = 16
		(layout/union-size? plain-union) = 8
		(layout/union-payload-offset? plain-union) = 0
		(layout/union-size? tagged-union) = 12
		(layout/union-payload-offset? tagged-union) = 4
		(layout/struct-slots?/direct struct) = 4
	]
	layout/connect target64
	checks64: all [
		(layout/size-of? 'pointer!) = 8
		(layout/union-size? tagged-union) = 16
		(layout/union-payload-offset? tagged-union) = 8
		(layout/struct-slots?/direct struct) = 2
	]
	either all [
		checks32
		checks64
	][
		print "Red/System ABI layout: OK"
		0
	][
		print "Red/System ABI layout mismatch"
		1
	]
]

check-system-emitter: has [
	left right joined start chunk symbol target target64 layout types pointer name1 name2 checks
	padded-data tagged-ref value-struct slots32 bitmap32 bitmap64 bitmap-offset bitmap-bytes
][
	compiler-system-emitter/reset
	start: compiler-system-emitter/chunks/start
	append compiler-system-emitter/code-buf #{AABB}
	chunk: compiler-system-emitter/chunks/stop
	left: reduce [copy #{AA} reduce [reduce [1]]]
	right: reduce [copy #{BBCC} reduce [reduce [2]]]
	joined: compiler-system-emitter/chunks/join left right
	append compiler-system-emitter/data-buf #{01}
	compiler-system-emitter/pad-data-buf 4
	padded-data: copy compiler-system-emitter/data-buf
	compiler-system-emitter/rodata?: true
	append compiler-system-emitter/rodata-buf #{0102FF}
	compiler-system-emitter/pad-data-buf 4
	tagged-ref: compiler-system-emitter/tag-ref 7
	symbol: compiler-system-emitter/add-symbol/with 'answer 9 [10]
	target: make object! [
		ptr-size: 4
		stack-width: 4
		struct-align-size: 4
		default-align: 4
		little-endian?: true
		stack-bitmap-counts?: false
	]
	layout: compiler-system-layout
	types: compiler-system-types
	types/reset
	layout/connect target
	compiler-system-emitter/target: target
	compiler-system-emitter/rodata?: false
	clear compiler-system-emitter/data-buf
	pointer: compiler-system-emitter/store-scalar -1 'int8!
	compiler-system-emitter/store-scalar 4660 'uint16!
	compiler-system-emitter/store-scalar -1 'integer!
	compiler-system-emitter/store-scalar to issue! "u64-18446744073709551615" 'uint64!
	compiler-system-emitter/store-scalar 1.0 'float32!
	compiler-system-emitter/store-scalar "A" 'c-string!
	name1: compiler-system-emitter/make-name
	name2: compiler-system-emitter/make-name
	value-struct: [struct! [address [pointer! [integer!]] count [integer!]] value]
	types/register-alias 'value-struct! value-struct
	slots32: compiler-system-emitter/pointer-slots [value-struct!]
	bitmap32: compiler-system-emitter/encode-ptr-bitmap [
		[typed]
		value [integer!]
		address [pointer! [integer!]]
		wide [uint64!]
		return: [integer!]
		/local text [c-string!] aggregate [value-struct!]
	]
	clear compiler-system-emitter/bits-buf
	bitmap-offset: compiler-system-emitter/store-ptr-bitmap bitmap32
	bitmap-bytes: copy compiler-system-emitter/bits-buf
	target64: make object! [
		ptr-size: 8
		stack-width: 8
		struct-align-size: 8
		default-align: 8
		little-endian?: true
		stack-bitmap-counts?: true
	]
	layout/connect target64
	compiler-system-emitter/target: target64
	bitmap64: compiler-system-emitter/encode-ptr-bitmap [
		[typed]
		value [integer!]
		address [pointer! [integer!]]
		wide [uint64!]
		return: [integer!]
		/local text [c-string!] aggregate [value-struct!]
	]
	checks: reduce [
		start = 1
		chunk/1 = #{AABB}
		chunk/3 = 1
		empty? compiler-system-emitter/code-buf
		joined/1 = #{AABBCC}
		joined/2/2/1 = 3
		padded-data = #{01000000}
		compiler-system-emitter/rodata-buf = #{0102FF00}
		tagged-ref = -7
		symbol/2/1 = 'constant
		symbol/2/2 = 9
		name1 = 'no-name-1
		name2 = 'no-name-2
		pointer = 1
		compiler-system-emitter/data-buf = #{FF003412FFFFFFFFFFFFFFFFFFFFFFFF0000803F4100}
		slots32 = [#(true) #(false)]
		bitmap32 = [536870914 - 3]
		bitmap-offset = 0
		bitmap-bytes = #{0200002003000000}
		bitmap64 = [3 3 536870914 - 3]
	]
	either all checks [
		print "Red/System emitter state: OK"
		0
	][
		print [
			"Red/System emitter state mismatch:"
			mold chunk
			mold joined
			"data:"
			mold compiler-system-emitter/data-buf
			"pointer:"
			pointer
			"pointer slots:"
			mold slots32
			"bitmaps:"
			mold bitmap32
			mold bitmap64
			"checks:"
			mold checks
		]
		1
	]
]

check-system-diagnostics: has [job source platform nested platform-location nested-location error][
	job: compiler-system-job/new 'MSDOS
	job/debug?: true
	compiler-system-loader/job: job
	compiler-system-loader/init
	source: compiler-system-loader/process
		%tools/self_hosting/fixtures/system-loader/main.reds
	platform: find source to set-word! 'platform
	nested: select source to set-word! 'nested
	compiler-system-diagnostics/reset
	platform-location: compiler-system-diagnostics/location
		platform
		%tools/self_hosting/fixtures/system-loader/main.reds
	nested-location: compiler-system-diagnostics/location nested %nested.reds
	error: compiler-system-diagnostics/error-at
		"invalid expression"
		platform
		%tools/self_hosting/fixtures/system-loader/main.reds
	either all [
		platform-location/index = 9
		platform-location/line = 6
		nested-location/index = 1
		nested-location/line = 12
		error/line = 6
		error/near/1 = to set-word! 'platform
		same? error compiler-system-diagnostics/last-error
	][
		print "Red/System source diagnostics: OK"
		0
	][
		print [
			"Red/System source diagnostics mismatch:"
			mold platform-location
			mold nested-location
			mold error
		]
		1
	]
]

check-system-compiler-source: has [
	source core body compiler-body checks system-pos compiler-pos
][
	set/any 'source try [transcode read/binary %system/compiler.red]
	set/any 'core try [transcode read/binary %system/compiler-core.red]
	if any [error? :source error? :core][
		print [
			"current Red/System compiler Red source transcode error:"
			mold :source
			mold :core
		]
		return 1
	]
	system-pos: find core to set-word! 'system-dialect
	body: all [
		system-pos
		system-pos/2 = 'context
		block? system-pos/3
		system-pos/3
	]
	compiler-pos: all [block? body find body to set-word! 'compiler]
	compiler-body: all [
		compiler-pos
		compiler-pos/2 = 'context
		block? compiler-pos/3
		compiler-pos/3
	]
	checks: reduce [
		block? source
		source/1 = 'Red
		block? source/2
		to logic! find source %compiler-core.red
		block? body
		block? compiler-body
		find compiler-body to set-word! 'normalize-union-spec
		find compiler-body to set-word! 'int64-literal-info
		find compiler-body to set-word! 'comp-overflow?
		find compiler-body to set-word! 'hidden-struct-return?
	]
	either all checks [
		print "current Red/System compiler Red source: OK"
		0
	][
		print [
			"current Red/System compiler Red source mismatch:"
			mold checks
		]
		1
	]
]

check-system-backend-source: has [
	pairs data-pairs failures oracle ported checks spec oracle-payload ported-payload
	target-manifest base-methods ia32-inventory ia32-adapters base-present? method position
][
	pairs: [
		[%system/emitter.r emitter %system/emitter.red emitter 63]
		[%system/targets/target-class.r target-class %system/targets/target-class-body.red source-body 13]
		[%system/targets/IA-32.r #(none) %system/targets/IA-32.red system-target-IA32 118]
		[%system/linker.r linker %system/linker.red linker 20]
		[%system/linker-static.r static-link %system/linker-static.red static-link 90]
		[%system/formats/PE.r #(none) %system/formats/PE.red system-format-PE 33]
		[%system/formats/ELF.r #(none) %system/formats/ELF.red system-format-ELF 55]
		[%system/formats/Mach-O.r #(none) %system/formats/Mach-O.red system-format-MachO 30]
		[%system/formats/Mach-O-ARM64.r #(none) %system/formats/Mach-O-ARM64.red system-format-MachO-ARM64 39]
		[%system/formats/COFF.r coff %system/formats/COFF.red coff 35]
		[%system/formats/ELF-obj.r elf-obj %system/formats/ELF-obj.red elf-obj 33]
		[%system/formats/Mach-O-obj.r macho-obj %system/formats/Mach-O-obj.red macho-obj 37]
	]
	data-pairs: [
		[%system/formats/libc-exports.r %system/formats/libc-exports.red]
		[%system/formats/win32-exports.r %system/formats/win32-exports.red]
		[%system/formats/mac-cxx-exports.r %system/formats/mac-cxx-exports.red]
		[%system/formats/mac-libsystem.r %system/formats/mac-libsystem.red]
		[%system/formats/crt-helpers.r %system/formats/crt-helpers.red]
	]
	failures: 0
	target-manifest: compiler-source-parity/decode %system/targets/target-class.red
	base-methods: compiler-source-parity/inventory
		%system/targets/target-class-body.red 'source-body
	ia32-inventory: compiler-source-parity/inventory
		%system/targets/IA-32.red 'system-target-IA32
	ia32-adapters: [homogeneous-floats? emit-push-struct-ref on-root-level-entry]
	base-present?: all [block? base-methods block? ia32-inventory]
	if base-present? [
		foreach method append copy base-methods ia32-adapters [
			unless find ia32-inventory method [base-present?: false]
		]
	]
	unless all [
		block? target-manifest
		compiler-source-parity/contains-value?
			target-manifest %system/targets/target-class-body.red
		base-present?
	][
		print "backend target body composition mismatch"
		failures: failures + 1
	]
	foreach spec pairs [
		oracle: compiler-source-parity/inventory spec/1 spec/2
		ported: compiler-source-parity/inventory spec/3 spec/4
		if all [
			block? ported
			spec/3 = %system/targets/IA-32.red
		][
			ported: copy ported
			foreach method append copy base-methods ia32-adapters [
				if position: find ported method [remove position]
			]
		]
		checks: reduce [
			block? oracle
			block? ported
			all [block? oracle equal? (length? oracle) spec/5]
			all [block? oracle block? ported equal? oracle ported]
		]
		unless all checks [
			print [
				"backend source parity mismatch:"
				spec/1 spec/3
				mold checks
				"counts:" any [all [block? oracle length? oracle] 0]
				any [all [block? ported length? ported] 0]
				"missing:" mold all [block? oracle block? ported difference oracle ported]
				"extra:" mold all [block? oracle block? ported difference ported oracle]
				mold compiler-source-parity/last-error
			]
			failures: failures + 1
		]
	]
	foreach spec data-pairs [
		oracle-payload: compiler-source-parity/payload-text spec/1
		ported-payload: compiler-source-parity/payload-text spec/2
		unless all [
			string? oracle-payload
			string? ported-payload
			equal? oracle-payload ported-payload
		][
			print [
				"generated backend data parity mismatch:"
				spec/1 spec/2
				mold compiler-source-parity/last-error
			]
			failures: failures + 1
		]
	]
	if zero? failures [print "current Red/System backend source parity: OK"]
	failures
]

check-lexer: has [source code saved-tokens token a-token invalid][
	source: {Red [Title: "Lexer"]
a: 123
nested: [true false]
}
	code: compiler-lexer/process/file source %lexer-check.red
	saved-tokens: copy compiler-lexer/tokens
	a-token: none
	foreach token saved-tokens [
		if all [
			token/kind = 'value
			set-word? token/value
			(mold token/value) = "a:"
		][a-token: token]
	]
	invalid: compiler-lexer/process {Red [}
	either all [
		block? code
		code/1 = 'Red
		set-word? code/3
		code/4 = 123
		block? code/6
		code/6/1 = 'true
		code/6/2 = 'false
		12 = length? saved-tokens
		object? a-token
		a-token/line = 2
		a-token/column = 1
		a-token/newline?
		(compiler-lexer/scan-type "123") = integer!
		none? invalid
		error? compiler-lexer/last-error
	][
		print "native transcode lexer: OK"
		0
	][
		print ["native transcode lexer mismatch:" mold code mold compiler-lexer/last-error]
		1
	]
]

check-system-source: has [source values rewrites invalid][
	source: {Red/System []
7FFFFFFFh
7FFFFFFFFFFFFFFFh
2147483648
-9223372036854775808
18446744073709551615
1.#INF
}
	values: copy/deep compiler-system-source/process source
	rewrites: copy/deep compiler-system-source/rewrites
	invalid: compiler-system-source/process {Red/System [] 18446744073709551616}
	either all [
		values/3 = 2147483647
		(mold values/4) = "#u64h-7FFFFFFFFFFFFFFF"
		(mold values/5) = "#i64-2147483648"
		(mold values/6) = "#i64-n9223372036854775808"
		(mold values/7) = "#u64-18446744073709551615"
		same? values/8 1.#INF
		4 = length? rewrites
		none? invalid
		object? compiler-system-source/last-error
	][
		print "native Red/System source normalization: OK"
		0
	][
		print ["Red/System source normalization mismatch:" mold compiler-system-source/last-error]
		1
	]
]

check-system-loader: has [source nested macro-pos macro-code][
	compiler-system-loader/job: make object! [
		OS: 'Windows
		debug?: true
		modules: copy []
	]
	compiler-system-loader/init
	source: compiler-system-loader/process
		%tools/self_hosting/fixtures/system-loader/main.reds
	nested: select source to set-word! 'nested
	macro-pos: find source to set-word! 'macro-value
	macro-code: either macro-pos [copy/part next macro-pos 3][none]
	either all [
		block? source
		find source to set-word! 'child-value
		(select source to set-word! 'child-value) = 10
		(select source to set-word! 'platform) = 10
		(select source to set-word! 'debug-value) = 1
		(select source to set-word! 'switch-value) = 1
		(select source to set-word! 'case-value) = 1
		(select source to set-word! 'wide-value) = to issue! "u64-18446744073709551615"
		macro-code = [2 + 3]
		block? nested
		nested/1 = 10
		none? compiler-system-loader/last-error
	][
		print "native Red/System loader: OK"
		0
	][
		print [
			"native Red/System loader mismatch:"
			mold source
			mold compiler-system-loader/last-error
			"options root:"
			mold system/options/path
			"loader root:"
			mold compiler-system-loader/root-path
		]
		1
	]
]

check-preprocessor: has [source code config expanded][
	config: make object! [
		OS: 'Windows
		target: 'IA-32
		debug?: true
	]
	source: {Red []
#if config/debug? [debug-value: yes]
#either config/OS = 'Windows [platform: 'win] [platform: 'other]
#switch config/target [IA-32 [bits: 32] #default [bits: 64]]
#case [config/debug? [case-value: 1] true [case-value: 2]]
#do keep [to set-word! "generated"]
}
	code: compiler-lexer/process source
	expanded: compiler-preprocessor/expand/clean/file code config %preprocessor-check.red
	either all [
		block? expanded
		find expanded to set-word! 'debug-value
		find expanded to set-word! 'platform
		find expanded to lit-word! 'win
		find expanded to set-word! 'bits
		find expanded 32
		find expanded to set-word! 'case-value
		find expanded to set-word! 'generated
		none? compiler-preprocessor/last-error
	][
		print "native Red preprocessor: OK"
		0
	][
		print ["native Red preprocessor mismatch:" mold expanded mold compiler-preprocessor/last-error]
		1
	]
]

check-source-loader: has [config record binary-found? item][
	config: make object! [debug?: true]
	record: compiler-source-loader/load
		%tools/self_hosting/fixtures/source-loader/main.red
		config
	binary-found?: false
	if record [
		foreach item record/code [if binary? :item [binary-found?: true]]
	]
	either all [
		object? record
		record/header/Title = "source loader fixture"
		find record/code to set-word! 'child-value
		find record/code 7
		find record/code to set-word! 'nested-value
		find record/code 8
		find record/code compiler-source-loader/directive-system
		binary-found?
		3 = length? compiler-source-loader/dependencies
		3 = length? compiler-source-loader/sources
		none? compiler-source-loader/last-error
	][
		print "native source pipeline: OK"
		0
	][
		print ["native source pipeline mismatch:" mold compiler-source-loader/last-error]
		1
	]
]

check-redbin: has [shared value compact fat decoded decoded-fat][
	shared: copy [shared-value]
	value: reduce [42 "Redbin" shared shared -0.0]
	new-line at value 2 true
	compact: compiler-redbin/encode value
	fat: compiler-redbin/encode/fat value
	decoded: compiler-redbin/decode compact
	decoded-fat: compiler-redbin/decode fat
	either all [
		compiler-redbin/header? compact
		compiler-redbin/header? fat
		(compiler-redbin/version-of compact) = 2
		compiler-redbin/compact? compact
		not compiler-redbin/compact? fat
		value = decoded
		value = decoded-fat
		same? decoded/3 decoded/4
		new-line? at decoded 2
		none? compiler-redbin/last-error
	][
		print "native Redbin codec: OK"
		0
	][
		print ["native Redbin codec mismatch:" mold compiler-redbin/last-error]
		1
	]
]

check-encoding: has [cases failures label actual expected][
	cases: reduce [
		"u8" (int-to-bin/to-bin8 255) #{FF}
		"u16" (int-to-bin/to-bin16 4660) #{3412}
		"u32" (int-to-bin/to-bin32 305419896) #{78563412}
		"negative-u32" (int-to-bin/to-bin32 -1) #{FFFFFFFF}
		"u64-limbs" (int-to-bin/to-bin64 [305419896 0]) #{7856341200000000}
	]
	failures: 0
	foreach [label actual expected] cases [
		unless actual = expected [
			print [label "expected" mold expected "but got" mold actual]
			failures: failures + 1
		]
	]
	either zero? failures [print "integer encoders: OK" 0][1]
]

check-floats: has [cases failures label actual expected split-value][
	split-value: ieee-754/to-binary64/split 1.0
	cases: reduce [
		"f64-one" (ieee-754/to-binary64 1.0) #{3FF0000000000000}
		"f64-little" (ieee-754/to-binary64/rev 1.0) #{000000000000F03F}
		"f64-negative-zero" (ieee-754/to-binary64 #0-) #{8000000000000000}
		"f64-split-high" split-value/1 1072693248
		"f64-split-low" split-value/2 0
		"f32-one" (ieee-754/to-binary32 1.0) #{3F800000}
		"f32-negative" (ieee-754/to-binary32 -2.5) #{C0200000}
		"f32-little" (ieee-754/to-binary32/rev 0.5) #{0000003F}
		"f32-infinity" (ieee-754/to-binary32 #INF) #{7F800000}
	]
	failures: 0
	foreach [label actual expected] cases [
		unless actual = expected [
			print [label "expected" mold expected "but got" mold actual]
			failures: failures + 1
		]
	]
	either zero? failures [print "IEEE-754 encoders: OK" 0][1]
]

check-unicode: has [cases failures label actual expected][
	cases: reduce [
		"ascii" (unicode/to-utf16le "A") #{4100}
		"bmp" (unicode/to-utf16le rejoin ["Red-" to char! 20013]) #{5200650064002D002D4E}
		"supplementary" (unicode/to-utf16le to string! to char! 128512) #{3DD800DE}
		"code-units" (unicode/to-utf16le/length rejoin ["A" to char! 128512]) 3
	]
	failures: 0
	foreach [label actual expected] cases [
		unless actual = expected [
			print [label "expected" mold expected "but got" mold actual]
			failures: failures + 1
		]
	]
	either zero? failures [print "Unicode encoders: OK" 0][1]
]

check-paths: has [cases failures label actual expected mutable returned][
	mutable: copy "a/./b/../c"
	returned: compiler-paths/secure-clean/nocopy mutable
	cases: reduce [
		"dot" (compiler-paths/secure-clean "a/./b") "a/b"
		"duplicate-slash" (compiler-paths/secure-clean "a//b") "a/b"
		"parent" (compiler-paths/secure-clean "a/b/../c") "a/c"
		"clamp-relative" (compiler-paths/secure-clean "../../a") "a"
		"clamp-absolute" (compiler-paths/secure-clean "/a/../../b") "/b"
		"trailing" (compiler-paths/secure-clean "a/b/") "a/b/"
		"root-limit" (compiler-paths/secure-clean/limit "/root/a/../../b" "/root") "/root/b"
		"nocopy-value" mutable "a/c"
		"nocopy-identity" (same? mutable returned) true
	]
	failures: 0
	foreach [label actual expected] cases [
		unless actual = expected [
			print [label "expected" mold expected "but got" mold actual]
			failures: failures + 1
		]
	]
	either zero? failures [print "path normalization: OK" 0][1]
]

check-structs: has [sample bytes expected invalid][
	sample: virtual-struct/make-value [
		first [char]
		second [short]
		third [integer!]
		fourth [uint64]
	] [#"A" 4660 305419896 [1 0]]
	bytes: virtual-struct/form-value sample
	expected: #{41003412785634120100000000000000}
	invalid: virtual-struct/is? (make object! [value: 1])
	either all [
		virtual-struct/is? sample
		bytes = expected
		not invalid
	][
		print "virtual structs: OK"
		0
	][
		print ["virtual struct mismatch:" mold bytes]
		1
	]
]

check-sha256: has [pages expected][
	pages: compiler-sha256/digest-pages #{616263646566} 6 3
	expected: #{
		BA7816BF8F01CFEA414140DE5DAE2223
		B00361A396177A9CB410FF61F20015AD
		CB8379AC2098AA165029E3938A51DA0B
		CECFC008FD6795F401178647F96C5B34
	}
	either all [
		(compiler-sha256/digest #{}) = #{
			E3B0C44298FC1C149AFBF4C8996FB924
			27AE41E4649B934CA495991B7852B855
		}
		(compiler-sha256/digest "abc") = #{
			BA7816BF8F01CFEA414140DE5DAE2223
			B00361A396177A9CB410FF61F20015AD
		}
		pages = expected
		(compiler-sha256/word-to-binary 305419896) = #{12345678}
	][
		print "SHA-256: OK"
		0
	][
		print "SHA-256 mismatch"
		1
	]
]

check-runtime-ids: has [ok without-view with-view job][
	job: make object! [modules: copy []]
	compiler-extractor/init job
	without-view: compiler-extractor/scalars
	job/modules: [View]
	compiler-extractor/init job
	with-view: compiler-extractor/scalars
	ok: all [
		(select compiler-extractor/definitions 'TYPE_IMAGE) = 53
		(select compiler-extractor/definitions 'ACT_WRITE) = 62
		(select compiler-extractor/definitions 'NAT_CHECKSUM) = 87
		compiler-extractor/datatype-count = 58
		compiler-extractor/action-count = 62
		compiler-extractor/native-count = 107
		empty? (get in without-view 'external!)
		find (get in with-view 'external!) 'event!
		(length? compiler-extractor/currencies) = 170
		find compiler-extractor/currencies 'USD
		find (get in compiler-extractor/scalars 'external!) 'event!
	]
	either ok [print "runtime IDs: OK" 0][1]
]

check-timing: has [records][
	phase-timer/reset
	phase-timer/active?: true
	phase-timer/begin 'self-test
	phase-timer/finish 'self-test
	phase-timer/active?: false
	records: phase-timer/snapshot
	either all [
		3 = length? records
		records/1 = 'self-test
		records/2 = 1
		time? records/3
		not negative? records/3
	][
		print "phase timing: OK"
		0
	][
		print ["phase timing mismatch:" mold records]
		1
	]
]

check-bindings: has [
	root child sibling root-id child-id left-owner right-owner
	left-word same-word other-word left-set left-context right-context index
][
	compiler-bindings/reset
	root: compiler-bindings/new-scope 'global 'global none
	child: compiler-bindings/new-scope 'function 'child root
	sibling: compiler-bindings/new-scope 'function 'sibling root
	root-id: root/id
	child-id: child/id
	left-owner: make object! [value: 1]
	right-owner: make object! [value: 2]
	left-word: bind/copy 'value left-owner
	same-word: bind/copy 'value left-owner
	other-word: bind/copy 'value right-owner
	left-set: bind/copy to set-word! 'value left-owner
	left-context: compiler-bindings/context-of left-word
	right-context: compiler-bindings/context-of other-word
	repeat index 256 [
		compiler-bindings/new-scope 'temporary none child
	]
	recycle
	either all [
		compiler-bindings/same-scope? child child
		not compiler-bindings/same-scope? child sibling
		root/id = root-id
		child/id = child-id
		(compiler-bindings/key child 'value) = (reduce [child-id 'value])
		compiler-bindings/same-word-binding? left-word same-word
		not compiler-bindings/same-word-binding? left-word other-word
		compiler-bindings/same-word-binding? left-word left-set
		compiler-bindings/same-context? left-word same-word
		compiler-bindings/same-context? left-word left-set
		not compiler-bindings/same-context? left-word other-word
		same? left-context left-owner
		same? right-context right-owner
	][
		print "binding identity: OK"
		0
	][
		print "binding identity mismatch"
		1
	]
]

check-options: has [parsed job invalid encap][
	parsed: compiler-options/parse-args [
		"--target" "Linux-X86-64"
		"--release"
		"--debug"
		"--static"
		"--config" "red-strict-check?: false"
		"--output" "out.bin"
		"hello.reds"
	]
	job: compiler-options/to-job parsed
	invalid: compiler-options/parse-args ["--target"]
	encap: compiler-options/parse-args ["--encap" "hello.red"]
	either all [
		object? parsed
		parsed/target = "Linux-X86-64"
		parsed/release?
		parsed/debug?
		parsed/static?
		parsed/output = "out.bin"
		parsed/source = "hello.reds"
		object? job
		job/target = 'X86-64
		job/PIC?
		job/PIE?
		not job/dev-mode?
		job/debug?
		job/static-link?
		not job/red-strict-check?
		job/build-basename = %out.bin
		error? invalid
		error? encap
	][
		print "command-line options: OK"
		0
	][
		print "command-line options mismatch"
		1
	]
]

check-registry: func [/local errors path name spec format][
	errors: 0
	foreach [name spec] target-registry [
		path: rejoin [%system/targets/ (select spec 'target) %.r]
		unless exists? path [
			print ["missing target source:" path]
			errors: errors + 1
		]
	]
	foreach format compiler-formats [
		path: rejoin [%system/formats/ format %.r]
		unless exists? path [
			print ["missing format source:" path]
			errors: errors + 1
		]
	]
	if zero? errors [print "target registry: OK"]
	errors
]

check-all: has [failures][
	failures: 0
	failures: failures + check-registry
	failures: failures + check-system-job
	failures: failures + check-system-target
	failures: failures + check-system-types
	failures: failures + check-system-layout
	failures: failures + check-system-emitter
	failures: failures + check-system-diagnostics
	failures: failures + check-system-compiler-source
	failures: failures + check-system-backend-source
	failures: failures + check-lexer
	failures: failures + check-system-source
	failures: failures + check-system-loader
	failures: failures + check-preprocessor
	failures: failures + check-source-loader
	failures: failures + check-redbin
	failures: failures + check-encoding
	failures: failures + check-floats
	failures: failures + check-unicode
	failures: failures + check-paths
	failures: failures + check-structs
	failures: failures + check-sha256
	failures: failures + check-runtime-ids
	failures: failures + check-timing
	failures: failures + check-bindings
	failures: failures + check-options
	failures
]

args: system/options/args
either empty? args [
	print-usage
	quit/return 2
][
	switch/default first args [
		"--version" [print selfhost-version]
		"--list-targets" [
			foreach [name spec] target-registry [print name]
		]
		"--check-all" [quit/return check-all]
		"--check-registry" [quit/return check-registry]
		"--check-system-job" [quit/return check-system-job]
		"--check-system-target" [quit/return check-system-target]
		"--check-system-types" [quit/return check-system-types]
		"--check-system-layout" [quit/return check-system-layout]
		"--check-system-emitter" [quit/return check-system-emitter]
		"--check-system-diagnostics" [quit/return check-system-diagnostics]
		"--check-system-compiler-source" [quit/return check-system-compiler-source]
		"--check-system-backend-source" [quit/return check-system-backend-source]
		"--check-lexer" [quit/return check-lexer]
		"--check-system-source" [quit/return check-system-source]
		"--check-system-loader" [quit/return check-system-loader]
		"--check-preprocessor" [quit/return check-preprocessor]
		"--check-source-loader" [quit/return check-source-loader]
		"--check-redbin" [quit/return check-redbin]
		"--check-encoding" [quit/return check-encoding]
		"--check-floats" [quit/return check-floats]
		"--check-unicode" [quit/return check-unicode]
		"--check-paths" [quit/return check-paths]
		"--check-structs" [quit/return check-structs]
		"--check-sha256" [quit/return check-sha256]
		"--check-runtime-ids" [quit/return check-runtime-ids]
		"--check-timing" [quit/return check-timing]
		"--check-bindings" [quit/return check-bindings]
		"--check-options" [quit/return check-options]
	][
		print-usage
		quit/return 2
	]
]
