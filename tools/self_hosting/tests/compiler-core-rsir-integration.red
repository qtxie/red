Red [
	Title: "Compiler-core exclusive RSIR frontend integration"
]

#include %../../../system/compiler-windows-bootstrap.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic!] message [string! block!]][
	unless condition [fail message]
]

source: all [
	block? system/options/args
	not empty? system/options/args
	clean-path to-red-file to file! system/options/args/1
]
unless source [
	foreach candidate reduce [
		join system/options/path %../fixtures/backend/rsir-empty-void.reds
		join system/options/path %tools/self_hosting/fixtures/backend/rsir-empty-void.reds
		join system/options/path %../../tools/self_hosting/fixtures/backend/rsir-empty-void.reds
	][
		candidate: clean-path candidate
		if exists? candidate [source: candidate break]
	]
]
unless source [fail ["cannot access RSIR integration fixture from: " system/options/path]]
unless exists? source [fail ["cannot access RSIR integration fixture: " source]]

code-before: copy emitter/code-buf
data-before: copy emitter/data-buf
rodata-before: copy emitter/rodata-buf
bits-before: copy emitter/bits-buf
symbols-before: copy/deep emitter/symbols
pic-before: emitter/target/PIC?

; Poison every legacy entry reachable for this source shape.  Successful
; compilation proves that the RSIR path is selected before any of them run.
emitter/init: func [link? job][fail "RSIR path invoked emitter/init"]
emitter/add-native: func [name][fail "RSIR path invoked emitter/add-native"]
emitter/encode-ptr-bitmap: func [locals /metadata fspec][
	fail "RSIR path invoked emitter/encode-ptr-bitmap"
]
emitter/store-ptr-bitmap: func [list][fail "RSIR path invoked emitter/store-ptr-bitmap"]
emitter/store-bitmaps: func [compress?][fail "RSIR path invoked emitter/store-bitmaps"]
emitter/enter: func [name locals offset][fail "RSIR path invoked emitter/enter"]
emitter/leave: func [name locals args-size locals-size return-spec][
	fail "RSIR path invoked emitter/leave"
]
emitter/reloc-native-calls: does [fail "RSIR path invoked emitter/reloc-native-calls"]
emitter/target/on-init: does [fail "RSIR path invoked target/on-init"]
emitter/target/on-root-level-entry: does [fail "RSIR path invoked target/on-root-level-entry"]
emitter/target/on-global-prolog: func [runtime? type][
	fail "RSIR path invoked target/on-global-prolog"
]
emitter/target/on-global-epilog: func [runtime? type][
	fail "RSIR path invoked target/on-global-epilog"
]
emitter/target/on-finalize: does [fail "RSIR path invoked target/on-finalize"]
rs-o2-ir/start-session: func [opt-level target path verbosity debug-mode][
	fail "RSIR path invoked machine-ir/start-session"
]

job: compiler-system-job/new 'Windows-X86-64
unless object? job [fail "could not create the Windows x64 compilation job"]
compiler-system-job/job-set job 'backend-mode 'rsir
compiler-system-job/job-set job 'link? false
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'opt-level 1
compiler-system-job/job-set job 'o2-ir-dump none
compiler-system-job/job-set job 'dev-mode? false

system-dialect/compile/options source job
artifact: system-dialect/last-rsir

check binary? artifact "compiler-core did not return RSIR"
check (length? artifact) = 1396 "compiler-core RSIR size changed"
check (checksum artifact 'SHA256) =
	#{8353248CDBC69D83181C09D2668C4DF1879503004D23C890B079953F2EEA8DBE}
	"compiler-core RSIR bytes differ from the independent fixture"
check none? system-dialect/last-result "RSIR compile published a legacy linker result"
check not rs-o2-ir/session? "RSIR compile left a machine-IR session active"
check not rs-o2-ir/function-active? "RSIR compile created a machine-IR function"
check code-before = emitter/code-buf "RSIR compile changed the emitter code buffer"
check data-before = emitter/data-buf "RSIR compile changed the emitter data buffer"
check rodata-before = emitter/rodata-buf "RSIR compile changed the emitter rodata buffer"
check bits-before = emitter/bits-buf "RSIR compile changed the emitter bitmap buffer"
check symbols-before = emitter/symbols "RSIR compile changed the emitter symbol table"
check pic-before = emitter/target/PIC? "RSIR compile changed the emitter target configuration"

print "PASS: compiler-core exclusive RSIR frontend"
