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
		--no-verify         skip the post-build checks
		-h --help           print this text
	}
	Notes: {
		Every child path is absolute: a Red console starts a script in the
		script's own directory, so a relative path would resolve against
		tools/self_hosting instead of the repository root.

		The resource generator is compiled for the host and the toolchain for the
		target. The embedded resource archive is generated first, on every build,
		because the toolchain links it in: the toolchain sources `#include` it, so
		this script is the only way to build them. The archive is never committed.

		Red's `call` waits but cannot kill a child, so this script has no
		watchdog: a wedged compiler wedges the build instead of timing out.
	}
]

;-- ------------------------------------------------- shared toolchain helpers --

#include %toolchain-common.red
error-prefix: "Toolchain build error"

;-- ---------------------------------------------------------------- options --

options: context [
	target: none
	host: none
	bootstrap: none
	output: none
	source: none
	root: none
	epoch: none
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
					value = 'no-verify [options/no-verify: yes]
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

script-file: does [
	rejoin [
		script-dir
		any [
			attempt [second split-path system/options/script]
			%build-red-toolchain.red
		]
	]
]

;-- One source, every target: the hybrid core is a cross-compiler, so the
;-- target is chosen by -t at build time, not by which file is compiled.
toolchain-sources: [
	"MSDOS-X86-64" %red-toolchain-hybrid.red
	"Linux-X86-64" %red-toolchain-hybrid.red
	"Linux-ARM64"  %red-toolchain-hybrid.red
	"Darwin-ARM64" %red-toolchain-hybrid.red
]

target-directories: [
	"MSDOS-X86-64" %windows-x64/
	"Darwin-ARM64" %darwin-arm64/
	"Linux-X86-64" %linux-x64/
	"Linux-ARM64"  %linux-arm64/
]

directory-for: func [target [string!]][
	any [select target-directories target  dirize to file! lowercase target]
]

;-- ------------------------------------------------------------- environment --

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

generation-tag: func [bootstrap [file!] /local tag char][
	tag: copy ""
	foreach char to string! second split-path bootstrap [
		if find digits char [append tag char]
	]
	either empty? tag ["local"][tag]
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
	count: resource-count result/2

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
		if options/root [dirize resolve-in script-dir options/root]
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
		if options/bootstrap [resolve-in root options/bootstrap]
		newest-bootstrap
	]
	require exists? bootstrap ["bootstrap compiler not found:" bootstrap]

	source: any [
		if options/source [resolve-in root options/source]
		if source: select toolchain-sources target [clean-path root/:source]
	]
	require source ["no toolchain source for" target "-- pass --source"]
	require exists? source ["toolchain source not found:" source]

	output: any [
		if options/output [resolve-in root options/output]
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

	generate-resources
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
