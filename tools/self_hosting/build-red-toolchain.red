Red [
	Title:   "Standalone hybrid Red toolchain builder"
	File:    %build-red-toolchain.red
	Purpose: {
		Builds the standalone Red toolchain for one hybrid target with a pinned
		bootstrap compiler. This script replaces build-windows-hybrid-toolchain.ps1
		and build-red-toolchain.sh: one Red script, driven by any Red console, on
		every host the hybrid compiler targets. No shell, no PowerShell, no Python.
	}
	Usage: {
		console tools/self_hosting/build-red-toolchain.red [options]

		--bootstrap <exe>   pinned bootstrap compiler (default: the newest
		                    build/self-hosting/merge-red64/hybrid-compilerN.exe)
		--target <name>     toolchain target (default: the host target)
		--host <name>       target the resource generator is built for; it runs
		                    here, so it defaults to the host, not to --target
		--output <file>     toolchain binary (default:
		                    build/red-toolchain/<target>/red-toolchain-<N>)
		--source <file>     toolchain source (default: chosen from --target)
		--root <dir>        repository root (default: two levels above this file)
		--epoch <seconds>   SOURCE_DATE_EPOCH (default: the environment, then the
		                    HEAD commit time; it pins the embedded compiler date)
		--no-resources      reuse the checked-in resource archive
		--no-verify         skip the post-build checks
		-h --help           print this text
	}
	Notes: {
		Every child path is absolute: a Red console starts a script in the
		script's own directory, so a relative path would resolve against
		tools/self_hosting instead of the repository root.

		The resource generator is compiled for the host and the toolchain for the
		target. The embedded resource archive is regenerated first because the
		toolchain links it in.

		Red's `call` waits but cannot kill a child, so this script has no
		watchdog: a wedged compiler wedges the build instead of timing out.
	}
]

fail: func [message [string! block!] /local text][
	text: either block? message [form reduce message][form message]	;-- `form` does not reduce
	replace/all text "^/" "^/    "
	print ["*** Toolchain build error:" text]
	quit/return 1
]

require: func [condition message [string! block!]][			;-- `all` yields NONE, not FALSE
	unless condition [fail message]
]

require-match: func [output [string!] pattern [string!] message [string! block!]][
	unless find output pattern [fail [message "^/--- output ---^/" output]]
]

;-- plain `trim` only removes spaces and tabs, and every child answers with a
;-- trailing newline, which would otherwise end up inside the value.
trim-eol: func [text [string!]][trim/with copy text "^/^M^- "]

digits: charset "0123456789"
hex-digits: charset "0123456789abcdef"

;-- ---------------------------------------------------------------- options --

options: context [
	target: none
	host: none
	bootstrap: none
	output: none
	source: none
	root: none
	epoch: none
	no-resources: no
	no-verify: no
	help: no
]

parse-options: func [args [block!] /local arg value][
	while [not tail? args][
		arg: first args
		args: next args
		case [
			find ["-h" "--help"] arg [options/help: yes  args: tail args]
			find ["-t" "--target"] arg [
				require not tail? args "--target needs a target name"
				options/target: first args
				args: next args
			]
			true [
				require all [#"-" = pick arg 1  #"-" = pick arg 2] ["unexpected argument:" arg]
				value: to word! skip arg 2
				case [
					find [bootstrap output source root epoch] value [
						require not tail? args [arg "needs a value"]
						set in options value first args
						args: next args
					]
					find [no-resources no-verify] value [set in options value yes]
					true [fail ["unknown option:" arg]]
				]
			]
		]
	]
]

print-usage: has [spec header][
	print "Build the standalone Red toolchain with a pinned hybrid bootstrap."
	spec: attempt [load/header script-file]
	header: either all [block? spec  block? spec/2] [spec/2][[]]
	print any [
		attempt [select header to-set-word 'usage]
		"(the Usage: field of this script's header)"
	]
]

;-- ------------------------------------------------------------------- paths --

;-- A Red console runs a script with the process in the script's own directory,
;-- while system/options/script keeps the path it was invoked with, relative to
;-- the directory the console started in. what-dir is therefore the only reliable
;-- anchor, unless the script was given as an absolute path.
script-dir: has [script][
	script: system/options/script
	either all [script  #"/" = pick script 1][first split-path script][dirize what-dir]
]

script-file: does [
	rejoin [
		script-dir
		any [
			attempt [second split-path system/options/script]
			%build-red-toolchain.red
		]
	]
]

resolve-root: does [
	;-- this file lives at <root>/tools/self_hosting/build-red-toolchain.red
	dirize first split-path first split-path script-dir
]

toolchain-sources: [
	"Windows-X86-64" %red-toolchain-windows-hybrid.red
	"Darwin-ARM64"   %red-toolchain-darwin-hybrid.red
]

target-directories: [
	"Windows-X86-64" %windows-x64/
	"Darwin-ARM64"   %darwin-arm64/
	"Linux-X86-64"   %linux-x64/
	"Linux-ARM64"    %linux-arm64/
]

directory-for: func [target [string!]][
	any [select target-directories target  dirize to file! lowercase target]
]

executable-suffix: func [target [string!]][
	either find target "Windows" [%.exe][%""]
]

;-- --------------------------------------------------------------- processes --

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

run: func [
	"Runs a child, logs both streams and returns [code stdout stderr]"
	label [string!]
	exe   [file!]
	args  [block!]
	/local code out err
][
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

;-- ------------------------------------------------------------- environment --

target-arch: func [arch [string!]][
	case [
		find arch "aarch64" ["ARM64"]
		find arch "arm64"   ["ARM64"]
		find arch "x86_64"  ["X86-64"]
		find arch "amd64"   ["X86-64"]
		true [fail ["unknown host architecture:" arch]]
	]
]

machine-arch: has [out][
	out: copy ""
	require 0 = call/wait/output {uname -m} out "uname -m failed"
	trim-eol out
]

host-target: does [
	case [
		system/platform = 'Windows ["Windows-X86-64"]		;-- PE x64 is the only Windows target
		system/platform = 'macOS   [join "Darwin-" target-arch machine-arch]
		system/platform = 'Linux   [join "Linux-" target-arch machine-arch]
		true [fail ["unsupported host platform:" system/platform]]
	]
]

resolve-epoch: has [out code][
	if options/epoch [return options/epoch]
	if out: get-env "SOURCE_DATE_EPOCH" [return trim-eol out]
	out: copy ""
	code: call/wait/output {git log -1 --format=%ct} out
	either all [code = 0  not empty? trim-eol out][trim-eol out][
		fail "no SOURCE_DATE_EPOCH: pass --epoch, or set it, or run in a Git checkout"
	]
]

check-epoch: func [value [string!]][
	require all [not empty? value  parse value [some digits]] [
		"SOURCE_DATE_EPOCH must be a non-negative integer, got:" value
	]
	value
]

newest-bootstrap: has [dir best best-number number name][
	dir: dirize rejoin [root "build/self-hosting/merge-red64"]		;-- a hyphen is not a path word
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
	dir/:best										;-- dir/best would append the word itself
]

generation-tag: func [bootstrap [file!] /local tag char][
	tag: copy ""
	foreach char to string! second split-path bootstrap [
		if find digits char [append tag char]
	]
	either empty? tag ["local"][tag]
]

;-- ------------------------------------------------------------ PE/ELF/Mach-O --
;-- Enough of each container to check what the build produced. This is what the
;-- PowerShell script needed dumpbin.exe for.

u16: func [b [binary!] i [integer!]][(pick b i) or ((pick b i + 1) << 8)]

u32: func [b [binary!] i [integer!]][
	(pick b i)
	or ((pick b i + 1) << 8)
	or ((pick b i + 2) << 16)
	or ((pick b i + 3) << 24)
]

asciiz: func [b [binary!] i [integer!] /local out byte][
	out: copy ""
	while [byte: pick b i  byte <> 0][append out to char! byte  i: i + 1]
	out
]

section-offset: func [
	"Maps an RVA to a 1-based index into b, or returns NONE"
	b [binary!] rva [integer!] count [integer!] first-section [integer!]
	/local i header base size ptr
][
	i: 0
	while [i < count][
		header: first-section + (i * 40)
		base: u32 b header + 12
		size: max (u32 b header + 8) (u32 b header + 16)
		ptr:  u32 b header + 20
		if all [rva >= base  rva < (base + size)][return ptr + (rva - base) + 1]
		i: i + 1
	]
	none
]

pe-imports: func [b [binary!] /local pe count size first-section rva here at names][
	pe: (u32 b 61) + 1								;-- e_lfanew, as a 1-based index
	count: u16 b pe + 6
	size: u16 b pe + 20
	first-section: pe + 24 + size
	rva: u32 b pe + 144							;-- DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT]
	if zero? rva [return copy []]
	here: section-offset b rva count first-section
	require here ["the PE import directory is outside every section"]
	names: copy []
	while [not zero? rva: u32 b here + 12][			;-- descriptor/Name
		at: section-offset b rva count first-section
		require at ["a PE import name is outside every section"]
		append names uppercase asciiz b at
		here: here + 20
	]
	names
]

check-image: func [file [file!] target [string!] /local b pe machine magic flags][
	b: read/binary file
	case [
		all [(pick b 1) = 77  (pick b 2) = 90][		;-- "MZ"
			require find target "Windows" [target "should not be a PE image"]
			pe: (u32 b 61) + 1
			require "PE" = asciiz b pe ["not a PE image:" file]
			machine: u16 b pe + 4
			magic: u16 b pe + 24
			require machine = 8664h ["PE machine is not x86-64:" machine]
			require magic = 20Bh ["PE optional header is not PE32+:" magic]
			flags: u16 b pe + 94					;-- DllCharacteristics
			require flags and 40h <> 0 [file "is not dynamic-base"]
			require flags and 100h <> 0 [file "is not NX-compatible"]
			require not find pe-imports b "LIBREDRT.DLL" [
				file "imports libRedRT.dll; a standalone toolchain must not"
			]
		]
		all [(pick b 1) = 7Fh  (pick b 2) = 69  (pick b 3) = 76  (pick b 4) = 70][	;-- ELF
			require find target "Linux" [target "should not be an ELF image"]
			require (pick b 5) = 2 [file "is not a 64-bit ELF image"]
			machine: u16 b 19
			require machine = select ["Linux-X86-64" 62  "Linux-ARM64" 183] target [
				"ELF machine does not match" target ":" machine
			]
		]
		all [(pick b 1) = CFh  (pick b 2) = 250  (pick b 3) = 237  (pick b 4) = 254][	;-- Mach-O 64
			require find target "Darwin" [target "should not be a Mach-O image"]
			machine: u32 b 5
			require machine = select ["Darwin-ARM64" 16777228  "Darwin-X86-64" 16777223] target [
				"Mach-O cputype does not match" target ":" machine
			]
		]
		true [fail ["unknown executable format:" file]]
	]
]

;-- ------------------------------------------------------------------- build --

root: none
tc-dir: none
log-dir: none
target: none
host: none
bootstrap: none
output: none
source: none
manifest: none

generate-resources: has [generator resources result][
	generator: rejoin [
		tc-dir directory-for host
		%generate-toolchain-resources executable-suffix host
	]
	if exists? generator [delete generator]
	run-checked "generator-build" bootstrap reduce [
		"-r" "-t" host "-o" to string! generator
		to string! root/tools/self_hosting/generate-toolchain-resources.red
	]
	resources: root/build/generated/red-toolchain-resources.generated.red
	if exists? resources [delete resources]
	result: run-checked "generator" generator reduce [to string! root  to string! resources]
	require-match result/2 "resources: " "the resource generator reported no archive"
	require exists? resources ["the resource generator wrote nothing"]
]

compile-toolchain: has [result][
	if exists? output [delete output]
	result: run-checked "toolchain-build" bootstrap reduce [
		"-r" "-t" target "-o" to string! output  to string! source
	]
	require exists? output ["the bootstrap compiler produced no binary"]
]

verify-toolchain: has [result info count targets expected][
	result: run-checked "self-check" output ["--self-check"]
	count: find result/2 "resource-self-check: ok resources: "
	require count ["the toolchain resource self-check did not pass"]
	count: attempt [
		to integer! trim-eol copy/part skip count length? "resource-self-check: ok resources: " 24
	]
	require all [integer? count  count > 0] ["the toolchain reported no resources"]

	result: run-checked "toolchain-info" output ["--toolchain-info"]
	info: result/2
	require-match info rejoin ["host: " target] "unexpected toolchain host"
	require-match info "backend: hybrid-rsir" "the toolchain is not hybrid"
	require-match info "standalone: true" "the toolchain is not standalone"

	result: run-checked "list-targets" output ["--list-targets"]
	targets: copy []
	foreach line split result/2 "^/" [unless empty? trim line [append targets trim line]]
	require not empty? targets ["the toolchain lists no targets"]
	require targets/1 = target ["the toolchain does not default to" target]

	result: run-checked "resource-manifest" output ["--resource-manifest"]
	manifest: trim-eol result/2
	require parse manifest [64 hex-digits] ["invalid resource manifest digest:" manifest]
	expected: any [attempt [trim-eol copy/part find/tail info "resource-manifest: " 64]  none]
	require manifest = expected [
		"--resource-manifest disagrees with --toolchain-info"
		"^/manifest:" manifest "^/info:" expected
	]

	check-image output target
	print ["Verified" count "resources," (length? targets) "targets," target]
]

build: does [
	parse-options any [system/options/args copy []]
	if options/help [print-usage  quit/return 0]

	root: any [
		if options/root [dirize clean-path to-red-file to file! options/root]
		resolve-root
	]
	require exists? root/compiler/bootstrap-boot.red ["not a Red repository root:" root]
	change-dir root
	tc-dir: dirize rejoin [root "build/red-toolchain"]
	print ["root:"  root]

	target: any [options/target  host-target]
	host: any [options/host  host-target]
	print ["target:" target "  host:" host]

	set-env "SOURCE_DATE_EPOCH" check-epoch resolve-epoch
	print ["epoch:" get-env "SOURCE_DATE_EPOCH"]

	bootstrap: any [
		if options/bootstrap [clean-path to-red-file to file! options/bootstrap]
		newest-bootstrap
	]
	require exists? bootstrap ["bootstrap compiler not found:" bootstrap]

	source: any [
		if options/source [clean-path to-red-file to file! options/source]
		if source: select toolchain-sources target [clean-path root/:source]
	]
	require source ["no toolchain source for" target "-- pass --source"]
	require exists? source ["toolchain source not found:" source]

	output: any [
		if options/output [clean-path to-red-file to file! options/output]
		clean-path rejoin [
			tc-dir directory-for target
			"red-toolchain-" generation-tag bootstrap executable-suffix target
		]
	]
	log-dir: dirize rejoin [first split-path output  %logs/]
	make-dir/deep tc-dir
	make-dir/deep dirize root/build/generated		;-- a path! cannot end with a slash
	make-dir/deep first split-path output
	make-dir/deep log-dir

	print ["bootstrap:" bootstrap]
	print ["source:" source]
	print ["output:" output]

	unless options/no-resources [generate-resources]
	compile-toolchain
	unless options/no-verify [verify-toolchain]

	print ["Built" output size? output "bytes"]
	if manifest [print ["Resource manifest:" manifest]]
	quit/return 0
]

;-- An uncaught script error leaves the console exit status at 0, which would
;-- pass CI, so report it and fail.
either error? result: try [build][
	print ["*** Toolchain build error:" form result]
	quit/return 1
][]
