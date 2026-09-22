Red [
	Title:   "Shared helpers for the Red toolchain scripts"
	File:    %toolchain-common.red
	Purpose: {
		Failures, child processes, PE/ELF/Mach-O checks and the bootstrap lookup
		that build-red-toolchain.red, build-red-toolchain-fixed-point.red and
		test-red-toolchain-hermetic.red all need. Pulled in with #include, so it
		is never run on its own.
	}
]

;-- ---------------------------------------------------------------------------
;-- Shared helpers for the Red-driven toolchain scripts:
;--     build-red-toolchain.red
;--     build-red-toolchain-fixed-point.red
;--     test-red-toolchain-hermetic.red
;--
;-- Pulled in with #include, so this file must stay headerless: its words join
;-- the including script's context, and it is never run on its own.
;-- ---------------------------------------------------------------------------

error-prefix: "Toolchain error"		;-- each script narrows this to its own name
on-fail: none						;-- optional block a script wants run before fail quits

;-- quit/return is not caught by `try`, so cleanup cannot live in the script's
;-- trailing error handler: it has to hang off fail itself.
fail: func [message [string! block!] /local text][
	text: either block? message [form reduce message][form message]	;-- `form` does not reduce
	replace/all text "^/" "^/    "
	print ["***" error-prefix ":" text]
	if on-fail [do on-fail]
	quit/return 1
]

resource-count: func [output [string!] /local marker at count][
	marker: "resource-self-check: ok resources: "
	at: find output marker
	require at ["the toolchain resource self-check did not pass^/--- output ---^/" output]
	count: attempt [to integer! trim-eol copy/part skip at (length? marker) 24]
	require all [integer? count  count > 0] ["the toolchain reported no resources"]
	count
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

;-- ------------------------------------------------------------------- paths --

;-- A Red console runs a script with the process in the script's own directory,
;-- while system/options/script keeps the path it was invoked with, relative to
;-- the directory the console started in. what-dir is therefore the only reliable
;-- anchor, unless the script was given as an absolute path.
script-dir: has [script][
	script: system/options/script
	either all [script  #"/" = pick script 1][first split-path script][dirize what-dir]
]

resolve-root: does [
	;-- these scripts live at <root>/tools/self_hosting/
	dirize first split-path first split-path script-dir
]

absolute?: func [value [string!]][
	any [
		#"/" = pick value 1						;-- Red form: /C/dir/file
		all [2 <= length? value  #":" = pick value 2]	;-- host form: C:\dir\file
	]
]

;-- A Red console runs a script with the process in the script's own directory,
;-- so a relative path typed on the command line would resolve against
;-- tools/self_hosting. Every path these scripts take is resolved against an
;-- explicit base -- the repository root, or this script's directory for --root
;-- itself -- which is what whoever typed it meant.
resolve-in: func [base [file!] value [string!] /local path][
	path: to file! value
	clean-path to-red-file either absolute? value [path][rejoin [base path]]
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

log-dir: none						;-- set by the including script; NONE means no logs

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
	if log-dir [
		write rejoin [log-dir label %.stdout.log] out
		write rejoin [log-dir label %.stderr.log] err
	]
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
		system/platform = 'macOS   [rejoin ["Darwin-" target-arch machine-arch]]
		system/platform = 'Linux   [rejoin ["Linux-" target-arch machine-arch]]
		true [fail ["unsupported host platform:" system/platform]]
	]
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

;-- ------------------------------------------------------------ PE/ELF/Mach-O --
;-- Enough of each container to check what a build produced, which is what the
;-- PowerShell scripts needed dumpbin.exe for.

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

pe-directory: func [
	"Maps DataDirectory[index] to a 1-based index into b"
	b [binary!] index [integer!]
	/local pe count size first-section rva here
][
	pe: (u32 b 61) + 1								;-- e_lfanew, as a 1-based index
	count: u16 b pe + 6								;-- NumberOfSections
	size: u16 b pe + 20								;-- SizeOfOptionalHeader
	first-section: pe + 24 + size
	rva: u32 b pe + 136 + (index * 8)				;-- DataDirectory[index].VirtualAddress
													;-- (optional header + 112, PE32+)
	if zero? rva [return none]
	here: section-offset b rva count first-section
	require here ["PE data directory" index "is outside every section"]
	here
]

pe-imports: func [b [binary!] /local pe count first-section here rva at names][
	here: pe-directory b 1							;-- IMAGE_DIRECTORY_ENTRY_IMPORT
	if none? here [return copy []]
	pe: (u32 b 61) + 1
	count: u16 b pe + 6
	first-section: pe + 24 + (u16 b pe + 20)
	names: copy []
	while [not zero? rva: u32 b here + 12][			;-- descriptor/Name
		at: section-offset b rva count first-section
		require at ["a PE import name is outside every section"]
		append names uppercase asciiz b at
		here: here + 20
	]
	names
]

pe-exports: func [b [binary!] /local pe count first-section here at index name names][
	here: pe-directory b 0							;-- IMAGE_DIRECTORY_ENTRY_EXPORT
	if none? here [return copy []]
	pe: (u32 b 61) + 1
	count: u16 b pe + 6
	first-section: pe + 24 + (u16 b pe + 20)
	at: section-offset b (u32 b here + 32) count first-section		;-- AddressOfNames
	require at ["the PE export names are outside every section"]
	names: copy []
	repeat index u32 b here + 24					;-- NumberOfNames
	[
		name: section-offset b (u32 b at + ((index - 1) * 4)) count first-section
		require name ["a PE export name is outside every section"]
		append names uppercase asciiz b name
	]
	names
]

check-pe-headers: func [b [binary!] name [string!] /local pe machine magic flags][
	pe: (u32 b 61) + 1
	require "PE" = asciiz b pe [name "is not a PE image"]
	machine: u16 b pe + 4
	magic: u16 b pe + 24
	require machine = 8664h [name "is not an x86-64 PE image"]
	require magic = 20Bh [name "is not a PE32+ image"]
	flags: u16 b pe + 94							;-- DllCharacteristics
	require flags and 40h <> 0 [name "is not dynamic-base"]
	require flags and 100h <> 0 [name "is not NX-compatible"]
]

check-image: func [
	"Checks the container, the headers and, unless /runtime, standalone-ness"
	file [file!] target [string!] /runtime /local b machine
][
	b: read/binary file
	case [
		all [(pick b 1) = 77  (pick b 2) = 90][		;-- "MZ"
			require find target "Windows" [target "should not be a PE image"]
			check-pe-headers b form file
			unless runtime [
				require not find pe-imports b "LIBREDRT.DLL" [
					file "imports libRedRT.dll; a standalone toolchain must not"
				]
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
