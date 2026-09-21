Red [
	Title:   "Hybrid toolchain fixed-point gate"
	File:    %build-red-toolchain-fixed-point.red
	Purpose: {
		Builds N consecutive toolchain generations, each one built by the previous
		one, and requires the last two to be the same image and to carry the same
		resource manifest. Red replaces
		test-windows-hybrid-toolchain-fixed-point.ps1: no PowerShell, and no
		`python selfhost.py compare-pe` either -- the PE comparison is here.
	}
	Usage: {
		console tools/self_hosting/build-red-toolchain-fixed-point.red [options]

		--bootstrap <exe>   first generation's compiler (default: the newest
		                    build/self-hosting/merge-red64/hybrid-compilerN.exe)
		--generations <n>   how many to build (default: 3, the minimum for a
		                    fixed point: the last two are both toolchain-built)
		--output-root <dir> where h1..hN land (default:
		                    build/red-toolchain/windows-x64-fixed-point)
		--target <name>     toolchain target (default: the host target)
		--epoch <seconds>   SOURCE_DATE_EPOCH, forwarded to every generation
		-h --help           print this text
	}
	Notes: {
		Every generation is compiled to the *same* staging path and copied out
		afterwards: the toolchain embeds its own output path, so building H2 and
		H3 under different names would make them differ for a reason that has
		nothing to do with the fixed point. The same applies to the resource
		archive, which is why the epoch is pinned once and forwarded.

		The last two images must be byte-identical apart from the two fields the
		linker cannot make stable: the COFF timestamp and the PE checksum.
	}
]

fail: func [message [string! block!] /local text][
	text: either block? message [form reduce message][form message]
	replace/all text "^/" "^/    "
	print ["*** Fixed-point error:" text]
	quit/return 1
]

require: func [condition message [string! block!]][
	unless condition [fail message]
]

trim-eol: func [text [string!]][trim/with copy text "^/^M^- "]
digits: charset "0123456789"

;-- ---------------------------------------------------------------- options --

options: context [
	bootstrap: none
	generations: 3
	output-root: none
	target: none
	epoch: none
	help: no
]

parse-options: func [args [block!] /local arg value][
	while [not tail? args][
		arg: first args
		args: next args
		case [
			find ["-h" "--help"] arg [options/help: yes  args: tail args]
			true [
				require all [#"-" = pick arg 1  #"-" = pick arg 2] ["unexpected argument:" arg]
				value: to word! skip arg 2
				case [
					find [bootstrap output-root target epoch] value [
						require not tail? args [arg "needs a value"]
						set in options value first args
						args: next args
					]
					value = 'generations [
						require not tail? args [arg "needs a number"]
						options/generations: to integer! first args
						args: next args
					]
					true [fail ["unknown option:" arg]]
				]
			]
		]
	]
]

print-usage: has [spec header][
	print "Build consecutive toolchain generations and compare the last two."
	spec: attempt [load/header script-file]
	header: either all [block? spec  block? spec/2] [spec/2][[]]
	print any [
		attempt [select header to-set-word 'usage]
		"(the Usage: field of this script's header)"
	]
]

;-- ------------------------------------------------------------------- paths --

script-dir: has [script][
	script: system/options/script
	either all [script  #"/" = pick script 1][first split-path script][dirize what-dir]
]

script-file: does [
	rejoin [
		script-dir
		any [
			attempt [second split-path system/options/script]
			%build-red-toolchain-fixed-point.red
		]
	]
]

resolve-root: does [
	dirize first split-path first split-path script-dir
]

;-- --------------------------------------------------------------- processes --
;-- Same helpers as the build script: absolute paths, both streams captured and
;-- logged, exit code returned.

quote-arg: func [value [string!]][
	either any [find value " " find value {"}] [
		rejoin [{"} replace/all copy value {"} {\"} {"}]
	][value]
]

command-line: func [exe [string!] args [block!] /local line arg][
	line: copy quote-arg exe
	foreach arg args [append line rejoin [" " quote-arg arg]]
	line
]

run: func [label [string!] exe [file!] args [block!] /local code out err][
	print ["==>" label]
	out: copy ""
	err: copy ""
	code: call/wait/output/error command-line (to-local-file exe) args out err
	write rejoin [log-dir label %.stdout.log] out
	write rejoin [log-dir label %.stderr.log] err
	reduce [code out err]
]

run-checked: func [label [string!] exe [file!] args [block!] /local result][
	result: run label exe args
	unless result/1 = 0 [
		fail [
			label "exited with" result/1
			"^/--- stdout ---^/" result/2
			"^/--- stderr ---^/" result/3
		]
	]
	result
]

;-- ------------------------------------------------------------ PE comparison --

u32: func [b [binary!] i [integer!]][
	(pick b i)
	or ((pick b i + 1) << 8)
	or ((pick b i + 2) << 16)
	or ((pick b i + 3) << 24)
]

;-- Blanks the COFF timestamp and the PE checksum, the only two fields the
;-- linker varies between two identical builds.
normalize-image: func [image [binary!] /local pe index][
	require all [(pick image 1) = 77  (pick image 2) = 90] "not a PE image"
	pe: (u32 image 61) + 1							;-- e_lfanew, as a 1-based index
	image: copy image
	repeat index 4 [
		poke image (pe + 7 + index) 0				;-- COFF TimeDateStamp
		poke image (pe + 87 + index) 0				;-- optional header CheckSum
	]
	image
]

first-difference: func [left [binary!] right [binary!] /local index][
	index: 1
	while [all [index <= length? left  index <= length? right]][
		unless (pick left index) = pick right index [return index]
		index: index + 1
	]
	either (length? left) = length? right [none][index]
]

;-- ------------------------------------------------------------------- build --

root: none
log-dir: none
output-root: none
console: none
build-script: none
stage: none

build-generation: func [index [integer!] bootstrap [file!] /local result generation][
	generation: rejoin [output-root "h" index "/red-toolchain" executable-suffix target]
	make-dir/deep first split-path generation
	print ["=== generation" index "from" bootstrap]
	result: run-checked rejoin ["build-h" index] console append reduce [
		to string! build-script
		"--bootstrap" to string! bootstrap
		"--output" to string! stage
		"--target" target
	] either options/epoch [reduce ["--epoch" options/epoch]][[]]
	require exists? stage ["generation" index "produced no binary"]
	write/binary generation read/binary stage
	delete stage
	generation
]

executable-suffix: func [target [string!]][
	either find target "Windows" [%.exe][%""]
]

report-manifest: func [generation [file!] /local result][
	result: run-checked rejoin ["manifest-" last split-path generation] generation ["--resource-manifest"]
	trim-eol result/2
]

fixed-point: does [
	parse-options any [system/options/args copy []]
	if options/help [print-usage  quit/return 0]

	require options/generations >= 2 ["--generations must be at least 2, got:" options/generations]

	root: resolve-root
	require exists? root/compiler/bootstrap-boot.red ["not a Red repository root:" root]
	change-dir root

	console: to-red-file to file! any [attempt [system/options/boot]  none]
	require console ["this script must be run by a Red console, not compiled"]
	build-script: root/tools/self_hosting/build-red-toolchain.red
	require exists? build-script ["build script not found:" build-script]

	target: any [options/target  "Windows-X86-64"]
	output-root: dirize any [
		if options/output-root [clean-path to-red-file to file! options/output-root]
		rejoin [root "build/red-toolchain/windows-x64-fixed-point"]
	]
	log-dir: dirize rejoin [output-root "logs/"]
	make-dir/deep output-root
	make-dir/deep log-dir
	make-dir/deep dirize rejoin [output-root "stage"]
	stage: rejoin [output-root "stage/red-toolchain" executable-suffix target]

	bootstrap: any [
		if options/bootstrap [clean-path to-red-file to file! options/bootstrap]
		newest-bootstrap
	]
	require exists? bootstrap ["bootstrap compiler not found:" bootstrap]

	print ["root:" root]
	print ["target:" target " generations:" options/generations]
	print ["output:" output-root]

	generations: copy []
	repeat index options/generations [
		append generations build-generation index bootstrap
		bootstrap: last generations
	]

	previous: pick generations (length? generations) - 1
	latest: last generations
	require (report-manifest previous) = report-manifest latest [
		"the last two generations embed different resource manifests"
	]

	left: normalize-image read/binary previous
	right: normalize-image read/binary latest
	if difference: first-difference left right [
		fail [
			"the last two generations differ at byte" difference
			"(COFF timestamp and PE checksum ignored)^/"
			previous " vs " latest
		]
	]

	print ["Fixed point:" latest]
	print [options/generations "generations, last two identical (" (length? left) "bytes)"]
	print ["Resource manifest:" report-manifest latest]
	quit/return 0
]

newest-bootstrap: has [dir best best-number number name][
	dir: dirize rejoin [root "build/self-hosting/merge-red64"]
	best: none
	best-number: -1
	foreach file read dir [
		name: to string! file
		if parse name ["hybrid-compiler" copy number some digits ".exe"] [
			if (to integer! number) > best-number [
				best-number: to integer! number
				best: file
			]
		]
	]
	require best ["no hybrid-compilerN.exe under" dir "-- pass --bootstrap"]
	dir/:best
]

;-- An uncaught script error leaves the console exit status at 0, which would
;-- pass CI, so report it and fail.
either error? result: try [fixed-point][
	print ["*** Fixed-point error:" form result]
	quit/return 1
][]
