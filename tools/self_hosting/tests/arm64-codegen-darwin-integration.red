Red [
	Title: "Direct hybrid ARM64 codegen and Darwin linker integration"
]

#include %../../../system/compiler-hybrid-common.red
#include %../../../compiler/system-diagnostics.red
#include %../../../compiler/codegen-bridge.red
#include %../../../compiler/rsir-frontend.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-expand-call: func [body [block!] global? [logic!]][copy []]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic! none!] message [string! block!]][
	unless condition [fail message]
]

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ (high * 16777216)
]

system-dialect: context [
	compiler: context [
		quit-on-error: does [quit/return 1]
		throw-error: func [message][fail either block? message [message][form message]]
	]
]

source: {
	Red/System []
	identity: func [value [integer!] return: [integer!]][value]
	functions: protect [:identity]
	hot-loop: func [return: [integer!] /local index sum][
		index: 0
		sum: 0
		while [index < 100][
			sum: sum + (index and 15)
			index: index + 1
		]
		sum
	]
	main: func [return: [integer!]][identity hot-loop]
}

root: clean-path system/options/path
unless exists? join root %system/compiler-rsir-core.red [
	root: clean-path to file! rejoin [system/options/path %../../../]
]
check exists? join root %system/compiler-rsir-core.red "could not locate repository root"
output-dir: clean-path join root %build/arm64-hybrid-baseline/

ir: compiler-rsir-frontend/compile load source 'user
check binary? ir ["ARM64 integration frontend failed: " mold compiler-rsir-frontend/last-error]
change/part ir int-to-bin/to-bin32 3 4
change/part at ir 5 int-to-bin/to-bin32 3 4

image: make binary! 65536
status: codegen-module ir image 2 0
check status = 0 ["ARM64 integration codegen status=" status]
check all [
	(word-at image 60) = 28
	(word-at image 64) = 40
	(word-at image 96) = 68
	(word-at image 100) = 68
	(word-at image 132) = 0
	(word-at image 136) = 28
]["ARM64 function layout changed unexpectedly"]
check (copy/part at image ((word-at image 28) + 1) 28) = #{
	FD7BBFA9 FD030091 0F000094 04000094
	BF030091 FD7BC1A8 C0035FD6
} "ARM64 calls do not target function entries"

job: compiler-system-job/new 'Darwin-ARM64
check object? job "could not create a Darwin ARM64 compilation job"
job: construct/with body-of job linker/job-class
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename %arm64-hybrid-loop-integration
compiler-system-job/job-set job 'build-suffix none

check linker/load-codegen job image [
	"Darwin linker rejected ARM64 image: " linker/codegen-error
]
output: linker/build job
check all [file? output exists? output]["Darwin linker did not write " mold output]
status: call/wait to-local-file output
check status = 214 ["generated ARM64 loop returned " status " instead of 214"]

import-source: {
	Red/System []
	#import [
		"/usr/lib/libSystem.B.dylib" cdecl [
			c-abs: "abs" [value [integer!] return: [integer!]]
		]
	]
	main: func [return: [integer!]][c-abs -42]
}

import-ir: compiler-rsir-frontend/compile load import-source 'user
check binary? import-ir [
	"ARM64 import integration frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part import-ir int-to-bin/to-bin32 3 4
change/part at import-ir 5 int-to-bin/to-bin32 1 4

import-image: make binary! 65536
status: codegen-module import-ir import-image 2 0
check status = 0 ["ARM64 import integration codegen status=" status]
check all [
	(word-at import-image 16) = 1
	(word-at import-image 20) = 1
]["ARM64 import integration image metadata is inconsistent"]

import-job: compiler-system-job/new 'Darwin-ARM64
check object? import-job "could not create a Darwin ARM64 import compilation job"
import-job: construct/with body-of import-job linker/job-class
compiler-system-job/job-set import-job 'runtime? false
compiler-system-job/job-set import-job 'debug? false
compiler-system-job/job-set import-job 'build-prefix output-dir
compiler-system-job/job-set import-job 'build-basename %arm64-hybrid-import-integration
compiler-system-job/job-set import-job 'build-suffix none

check linker/load-codegen import-job import-image [
	"Darwin linker rejected ARM64 import image: " linker/codegen-error
]
import-output: linker/build import-job
check all [file? import-output exists? import-output][
	"Darwin linker did not write " mold import-output
]
status: call/wait to-local-file import-output
check status = 42 ["generated ARM64 import returned " status " instead of 42"]

size-source: {
	Red/System []
	cell!: alias struct! [mark [byte!] value [integer!]]
	measure: func [text [c-string!] return: [integer!]][size? text]
	main: func [return: [integer!]][
		(size? cell!) + (measure "Hybrid") + 27
	]
}

size-ir: compiler-rsir-frontend/compile load size-source 'user
check binary? size-ir [
	"ARM64 SIZE? integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part size-ir int-to-bin/to-bin32 3 4
change/part at size-ir 5 int-to-bin/to-bin32 2 4

size-image: make binary! 65536
status: codegen-module size-ir size-image 2 0
check status = 0 ["ARM64 SIZE? integration codegen status=" status]

size-job: compiler-system-job/new 'Darwin-ARM64
check object? size-job "could not create a Darwin ARM64 SIZE? job"
size-job: construct/with body-of size-job linker/job-class
compiler-system-job/job-set size-job 'runtime? false
compiler-system-job/job-set size-job 'debug? false
compiler-system-job/job-set size-job 'build-prefix output-dir
compiler-system-job/job-set size-job 'build-basename %arm64-hybrid-size-integration
compiler-system-job/job-set size-job 'build-suffix none

check linker/load-codegen size-job size-image [
	"Darwin linker rejected ARM64 SIZE? image: " linker/codegen-error
]
size-output: linker/build size-job
check all [file? size-output exists? size-output][
	"Darwin linker did not write " mold size-output
]
status: call/wait to-local-file size-output
check status = 42 [
	"generated ARM64 SIZE? module returned " status " instead of 42"
]

control-source: {
	Red/System []
	either-value: func [flag [logic!] return: [integer!]][
		either flag [11][22]
	]
	case-value: func [value [integer!] return: [integer!]][
		case [
			value = 1 [3]
			value = 2 [5]
			true [7]
		]
	]
	switch-value: func [value [integer!] return: [integer!]][
		switch value [1 [13] 2 [17] default [19]]
	]
	early-value: func [value [integer!] return: [integer!]][
		if value = 0 [return 4]
		8
	]
	nested-value: func [flag [logic!] return: [integer!]][
		1 + (either flag [2][3])
	]
	main: func [return: [integer!]][
		(either-value true) + (case-value 2) + (switch-value 1)
			+ (early-value 0) + (nested-value true) + 6
	]
}

control-ir: compiler-rsir-frontend/compile load control-source 'user
check binary? control-ir [
	"ARM64 control-flow integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part control-ir int-to-bin/to-bin32 3 4
change/part at control-ir 5 int-to-bin/to-bin32 6 4

control-image: make binary! 131072
status: codegen-module control-ir control-image 2 0
check status = 0 ["ARM64 control-flow integration codegen status=" status]

control-job: compiler-system-job/new 'Darwin-ARM64
check object? control-job "could not create a Darwin ARM64 control-flow job"
control-job: construct/with body-of control-job linker/job-class
compiler-system-job/job-set control-job 'runtime? false
compiler-system-job/job-set control-job 'debug? false
compiler-system-job/job-set control-job 'build-prefix output-dir
compiler-system-job/job-set control-job 'build-basename %arm64-hybrid-control-integration
compiler-system-job/job-set control-job 'build-suffix none

check linker/load-codegen control-job control-image [
	"Darwin linker rejected ARM64 control-flow image: " linker/codegen-error
]
control-output: linker/build control-job
check all [file? control-output exists? control-output][
	"Darwin linker did not write " mold control-output
]
status: call/wait to-local-file control-output
check status = 42 [
	"generated ARM64 control-flow module returned " status " instead of 42"
]

narrow-source: {
	Red/System []
	compute: func [
		a [int8!]
		b [uint8!]
		return: [integer!]
		/local signed-result [int8!] unsigned-result [uint8!]
			inverted [uint8!] wide [int64!]
	][
		signed-result: a * as int8! 7
		unsigned-result: b + as uint8! 10
		inverted: not b
		wide: signed-result
		(as integer! wide) - (as integer! unsigned-result) - 22
			+ (as integer! inverted) - 5
	]
	main: func [return: [integer!]][compute as int8! -100 as uint8! 250]
}

narrow-ir: compiler-rsir-frontend/compile load narrow-source 'user
check binary? narrow-ir [
	"ARM64 narrow integer integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part narrow-ir int-to-bin/to-bin32 3 4
change/part at narrow-ir 5 int-to-bin/to-bin32 2 4

narrow-image: make binary! 65536
status: codegen-module narrow-ir narrow-image 2 0
check status = 0 ["ARM64 narrow integer integration codegen status=" status]

narrow-job: compiler-system-job/new 'Darwin-ARM64
check object? narrow-job "could not create a Darwin ARM64 narrow integer job"
narrow-job: construct/with body-of narrow-job linker/job-class
compiler-system-job/job-set narrow-job 'runtime? false
compiler-system-job/job-set narrow-job 'debug? false
compiler-system-job/job-set narrow-job 'build-prefix output-dir
compiler-system-job/job-set narrow-job 'build-basename %arm64-hybrid-narrow-integration
compiler-system-job/job-set narrow-job 'build-suffix none

check linker/load-codegen narrow-job narrow-image [
	"Darwin linker rejected ARM64 narrow integer image: " linker/codegen-error
]
narrow-output: linker/build narrow-job
check all [file? narrow-output exists? narrow-output][
	"Darwin linker did not write " mold narrow-output
]
status: call/wait to-local-file narrow-output
check status = 42 [
	"generated ARM64 narrow integer module returned " status " instead of 42"
]

division-source: {
	Red/System []
	signed: func [a [integer!] b [integer!] return: [integer!]][
		(a / b) + (a % b) + (a // b)
	]
	narrow-signed: func [
		a [int8!]
		b [int8!]
		return: [integer!]
		/local quotient [int8!] remainder [int8!] modulo [int8!]
	][
		quotient: a / b
		remainder: a % b
		modulo: a // b
		(as integer! quotient) + (as integer! remainder) + (as integer! modulo)
	]
	wide: func [a [int64!] b [int64!] return: [int64!]][a / b]
	unsigned: func [a [uint32!] b [uint32!] return: [uint32!]][a % b]
	main: func [
		return: [integer!]
		/local value [integer!] wide-value [int64!] unsigned-value [uint32!]
	][
		value: signed -17 -5
		value: value + signed -17 5
		value: value + signed 17 -5
		value: value + signed 17 5
		value: value + narrow-signed as int8! -100 as int8! 7
		wide-value: wide as int64! 82 as int64! 2
		unsigned-value: unsigned as uint32! 17 as uint32! 5
		value: value + as integer! wide-value
		value + as integer! unsigned-value
	]
}

division-ir: compiler-rsir-frontend/compile load division-source 'user
check binary? division-ir [
	"ARM64 integer division integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part division-ir int-to-bin/to-bin32 3 4
change/part at division-ir 5 int-to-bin/to-bin32 5 4

division-image: make binary! 65536
status: codegen-module division-ir division-image 2 0
check status = 0 ["ARM64 integer division integration codegen status=" status]

division-job: compiler-system-job/new 'Darwin-ARM64
check object? division-job "could not create a Darwin ARM64 integer division job"
division-job: construct/with body-of division-job linker/job-class
compiler-system-job/job-set division-job 'runtime? false
compiler-system-job/job-set division-job 'debug? false
compiler-system-job/job-set division-job 'build-prefix output-dir
compiler-system-job/job-set division-job 'build-basename %arm64-hybrid-division-integration
compiler-system-job/job-set division-job 'build-suffix none

check linker/load-codegen division-job division-image [
	"Darwin linker rejected ARM64 integer division image: " linker/codegen-error
]
division-output: linker/build division-job
check all [file? division-output exists? division-output][
	"Darwin linker did not write " mold division-output
]
status: call/wait to-local-file division-output
check status = 42 [
	"generated ARM64 integer division module returned " status " instead of 42"
]

float-source: {
	Red/System []
	#import [
		"/usr/lib/libSystem.B.dylib" cdecl [
			c-sqrt: "sqrt" [value [float!] return: [float!]]
		]
	]
	factor: as float32! 1.5
	blend: func [
		count [integer!]
		a [float!]
		b [float32!]
		return: [float32!]
		/local total [float32!]
	][
		total: a + b
		factor: total * as float32! 2.0
		factor + as float32! count
	]
	through-pointer: func [
		value [float32!]
		return: [float32!]
		/local slot [float32!] pointer [pointer! [float32!]]
	][
		slot: value
		pointer: :slot
		pointer/1: pointer/1 + as float32! 1.0
		pointer/1 - as float32! 1.0
	]
	round-half: func [value [integer!] return: [integer!] /local real [float!]][
		real: as float! value
		as integer! (real / 2.0)
	]
	bits: func [value [float32!] return: [integer!]][as integer! keep value]
	increment: func [value [float!] return: [float!]][value + 1.0]
	preserve: func [value [float!] return: [float!]][
		(value * 2.0) + (increment 1.0)
	]
	bank-sum: func [
		a [integer!] x [float!]
		b [integer!] y [float!]
		c [integer!] z [float!]
		d [integer!] u [float!]
		e [integer!] v [float!]
		return: [integer!]
		/local integers [integer!] reals [float!]
	][
		integers: a + b + c + d + e
		reals: x + y + z + u + v
		integers + (as integer! reals)
	]
	compare-score: func [
		return: [integer!]
		/local score [integer!] zero [float!] one [float!] two [float!]
			three [float!] nan [float!]
	][
		score: 0
		zero: 0.0
		one: 1.0
		two: 2.0
		three: 3.0
		if three > two [score: score + 1]
		if two < three [score: score + 2]
		if three >= three [score: score + 4]
		if three <= three [score: score + 8]
		nan: zero / zero
		if nan < one [score: score + 64]
		if nan <= one [score: score + 64]
		if nan > one [score: score + 64]
		if nan >= one [score: score + 64]
		if nan = nan [score: score + 64]
		if nan <> nan [score: score + 8]
		score
	]
	main: func [return: [integer!] /local value [integer!] real [float32!]][
		real: blend 7 1.25 as float32! 2.25
		real: through-pointer real
		value: as integer! real
		value: value + round-half 10
		value: value + compare-score
		value: value + (bits as float32! 0.0)
		value: value + (as integer! (c-sqrt 81.0)) - 9
		value: value + (as integer! (preserve 3.0)) - 8
		value: value + (bank-sum 1 1.0 2 2.0 3 3.0 4 4.0 5 5.0) - 30
		value
	]
}

float-ir: compiler-rsir-frontend/compile load float-source 'user
check binary? float-ir [
	"ARM64 scalar float integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part float-ir int-to-bin/to-bin32 3 4
change/part at float-ir 5 int-to-bin/to-bin32 (word-at float-ir 16) 4

float-image: make binary! 65536
status: codegen-module float-ir float-image 2 0
check status = 0 ["ARM64 scalar float integration codegen status=" status]

float-job: compiler-system-job/new 'Darwin-ARM64
check object? float-job "could not create a Darwin ARM64 scalar float job"
float-job: construct/with body-of float-job linker/job-class
compiler-system-job/job-set float-job 'runtime? false
compiler-system-job/job-set float-job 'debug? false
compiler-system-job/job-set float-job 'build-prefix output-dir
compiler-system-job/job-set float-job 'build-basename %arm64-hybrid-float-integration
compiler-system-job/job-set float-job 'build-suffix none

check linker/load-codegen float-job float-image [
	"Darwin linker rejected ARM64 scalar float image: " linker/codegen-error
]
float-output: linker/build float-job
check all [file? float-output exists? float-output][
	"Darwin linker did not write " mold float-output
]
status: call/wait to-local-file float-output
check status = 42 [
	"generated ARM64 scalar float module returned " status " instead of 42"
]

global-source: {
	Red/System []
	pair: declare struct! [left [integer!] right [integer!]]
	text: protect "Red"
	total: 14
	main: func [
		return: [integer!]
		/local value [integer!] p [int-ptr!]
	][
		pair/left: 14
		value: 0
		p: :value
		value: value + pair/left
		p/1: value + 14
		total: total + p/1
		value: total
		value
	]
}

global-ir: compiler-rsir-frontend/compile load global-source 'user
check binary? global-ir [
	"ARM64 global integration frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part global-ir int-to-bin/to-bin32 3 4
change/part at global-ir 5 int-to-bin/to-bin32 1 4

global-image: make binary! 65536
status: codegen-module global-ir global-image 2 0
check status = 0 ["ARM64 global integration codegen status=" status]
check all [
	(word-at global-image 20) = 4
	(word-at global-image 36) = 36
	(word-at global-image 40) = 5
	(word-at global-image 44) = 12
]["ARM64 global integration image metadata is inconsistent"]

global-job: compiler-system-job/new 'Darwin-ARM64
check object? global-job "could not create a Darwin ARM64 global compilation job"
global-job: construct/with body-of global-job linker/job-class
compiler-system-job/job-set global-job 'runtime? false
compiler-system-job/job-set global-job 'debug? false
compiler-system-job/job-set global-job 'build-prefix output-dir
compiler-system-job/job-set global-job 'build-basename %arm64-hybrid-global-integration
compiler-system-job/job-set global-job 'build-suffix none

check linker/load-codegen global-job global-image [
	"Darwin linker rejected ARM64 global image: " linker/codegen-error
]
global-output: linker/build global-job
check all [file? global-output exists? global-output][
	"Darwin linker did not write " mold global-output
]
status: call/wait to-local-file global-output
check status = 42 ["generated ARM64 global update returned " status " instead of 42"]

pointer-source: {
	Red/System []
	wide-cell!: alias struct! [
		a [integer!]
		b [integer!]
		c [integer!]
		d [integer!]
	]
	hot-loop: func [
		base [wide-cell!]
		iterations [integer!]
		return: [wide-cell!]
		/local index [integer!] cursor [wide-cell!]
	][
		index: 0
		cursor: base
		while [index < iterations][
			cursor: cursor + 1
			index: index + 1
		]
		cursor
	]
	main: func [return: [integer!]][
		hot-loop null 1000000000
		0
	]
}

pointer-ir: compiler-rsir-frontend/compile load pointer-source 'user
check binary? pointer-ir [
	"ARM64 pointer integration frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part pointer-ir int-to-bin/to-bin32 3 4
change/part at pointer-ir 5 int-to-bin/to-bin32 2 4

pointer-image: make binary! 65536
status: codegen-module pointer-ir pointer-image 2 0
check status = 0 ["ARM64 pointer integration codegen status=" status]
check not none? find pointer-image #{D6420091B5060011} [
	"ARM64 pointer integration lost its direct pointer and index increments"
]

pointer-job: compiler-system-job/new 'Darwin-ARM64
check object? pointer-job "could not create a Darwin ARM64 pointer compilation job"
pointer-job: construct/with body-of pointer-job linker/job-class
compiler-system-job/job-set pointer-job 'runtime? false
compiler-system-job/job-set pointer-job 'debug? false
compiler-system-job/job-set pointer-job 'build-prefix output-dir
compiler-system-job/job-set pointer-job 'build-basename %arm64-hybrid-pointer-integration
compiler-system-job/job-set pointer-job 'build-suffix none

check linker/load-codegen pointer-job pointer-image [
	"Darwin linker rejected ARM64 pointer image: " linker/codegen-error
]
pointer-output: linker/build pointer-job
check all [file? pointer-output exists? pointer-output][
	"Darwin linker did not write " mold pointer-output
]
status: call/wait to-local-file pointer-output
check status = 0 ["generated ARM64 pointer module returned " status " instead of 0"]

indirect-source: {
	Red/System []
	unary!: alias function! [value [integer!] return: [integer!]]
	weighted!: alias function! [
		a [integer!] x [float!] b [integer!] return: [integer!]
	]
	octet!: alias function! [
		a [integer!] b [integer!] c [integer!] d [integer!]
		e [integer!] f [integer!] g [integer!] h [integer!]
		return: [integer!]
	]
	triple: func [value [integer!] return: [integer!]][value * 3]
	negate-value: func [value [integer!] return: [integer!]][0 - value]
	add-two: func [a [integer!] b [integer!] return: [integer!]][a + b]
	weigh: func [
		a [integer!] x [float!] b [integer!]
		return: [integer!]
	][a + b + as integer! x]
	sum-eight: func [
		a [integer!] b [integer!] c [integer!] d [integer!]
		e [integer!] f [integer!] g [integer!] h [integer!]
		return: [integer!]
	][a + b + c + d + e + f + g + h]
	handler: :add-two
	current: :triple
	apply-hook: func [hook [unary!] value [integer!] return: [integer!]][
		hook value
	]
	local-call: func [return: [integer!] /local hook [unary!]][
		hook: :triple
		hook 4
	]
	spilled-call: func [return: [integer!]][
		handler (add-two 1 2) 4
	]
	weighted-call: func [return: [integer!] /local hook [weighted!]][
		hook: :weigh
		hook 3 4.0 5
	]
	octet-call: func [return: [integer!] /local hook [octet!]][
		hook: :sum-eight
		hook 1 2 3 4 5 6 7 8
	]
	main: func [return: [integer!] /local total [integer!]][
		total: local-call
		total: total + (apply-hook :negate-value 5)
		total: total + spilled-call
		total: total + weighted-call
		total: total + (octet-call - 33)
		current: :negate-value
		total: total + (current 4)
		total + (handler 9 8)
	]
}

indirect-ir: compiler-rsir-frontend/compile load indirect-source 'user
check binary? indirect-ir [
	"ARM64 indirect call integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part indirect-ir int-to-bin/to-bin32 3 4
change/part at indirect-ir 5 int-to-bin/to-bin32 (word-at indirect-ir 16) 4

indirect-image: make binary! 131072
status: codegen-module indirect-ir indirect-image 2 0
check status = 0 ["ARM64 indirect call integration codegen status=" status]
check not none? find indirect-image #{20023FD6} [
	"ARM64 indirect calls do not branch through X17"
]

indirect-job: compiler-system-job/new 'Darwin-ARM64
check object? indirect-job "could not create a Darwin ARM64 indirect call job"
indirect-job: construct/with body-of indirect-job linker/job-class
compiler-system-job/job-set indirect-job 'runtime? false
compiler-system-job/job-set indirect-job 'debug? false
compiler-system-job/job-set indirect-job 'build-prefix output-dir
compiler-system-job/job-set indirect-job 'build-basename %arm64-hybrid-indirect-integration
compiler-system-job/job-set indirect-job 'build-suffix none

check linker/load-codegen indirect-job indirect-image [
	"Darwin linker rejected ARM64 indirect call image: " linker/codegen-error
]
indirect-output: linker/build indirect-job
check all [file? indirect-output exists? indirect-output][
	"Darwin linker did not write " mold indirect-output
]
status: call/wait to-local-file indirect-output
check status = 42 [
	"generated ARM64 indirect call module returned " status " instead of 42"
]

subroutine-source: {
	Red/System []
	bump-by: func [value [integer!] return: [integer!]][value + 1]
	tally: func [
		limit [integer!]
		return: [integer!]
		/local step [subroutine!] wrap [subroutine!]
			total [integer!] index [integer!]
	][
		step: [total: total + index]
		wrap: [
			total: bump-by total
			total
		]
		total: 0
		index: 0
		while [index < limit][
			index: index + 1
			step
		]
		total + wrap
	]
	blend: func [
		return: [integer!]
		/local scale [subroutine!] value [float!]
	][
		scale: [value * 2.0]
		value: 2.5
		as integer! scale
	]
	nest: func [
		return: [integer!]
		/local inner [subroutine!] outer [subroutine!] total [integer!]
	][
		inner: [total: total + 2]
		outer: [
			inner
			inner
			total
		]
		total: 1
		outer
	]
	chain: func [
		return: [integer!]
		/local leaf [subroutine!] pair [subroutine!] link [subroutine!]
			total [integer!]
	][
		leaf: [total: total + 1]
		pair: [leaf leaf total]
		link: [leaf pair]
		total: 0
		link
	]
	escape: func [
		value [integer!]
		return: [integer!]
		/local bail [subroutine!]
	][
		bail: [
			if value > 10 [return 0]
			value
		]
		bail
	]
	main: func [return: [integer!] /local total [integer!]][
		total: tally 5
		total: total + blend
		total: total + nest
		total: total + chain
		total: total + (escape 3)
		total: total + (escape 20)
		total - 5
	]
}

subroutine-ir: compiler-rsir-frontend/compile load subroutine-source 'user
check binary? subroutine-ir [
	"ARM64 subroutine integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part subroutine-ir int-to-bin/to-bin32 3 4
change/part at subroutine-ir 5 int-to-bin/to-bin32 (word-at subroutine-ir 16) 4

subroutine-image: make binary! 131072
status: codegen-module subroutine-ir subroutine-image 2 0
check status = 0 ["ARM64 subroutine integration codegen status=" status]

;-- Each subroutine body is emitted as its own block terminated by RET, so a
;-- module using them holds more returns than it has functions.
return-count: 0
cursor: at subroutine-image (word-at subroutine-image 28) + 1
code-words: (word-at subroutine-image 32) / 4
loop code-words [
	if #{C0035FD6} = copy/part cursor 4 [return-count: return-count + 1]
	cursor: skip cursor 4
]
check return-count > (word-at subroutine-image 12) [
	"ARM64 subroutine bodies were not emitted: " return-count
	" returns for " (word-at subroutine-image 12) " functions"
]

subroutine-job: compiler-system-job/new 'Darwin-ARM64
check object? subroutine-job "could not create a Darwin ARM64 subroutine job"
subroutine-job: construct/with body-of subroutine-job linker/job-class
compiler-system-job/job-set subroutine-job 'runtime? false
compiler-system-job/job-set subroutine-job 'debug? false
compiler-system-job/job-set subroutine-job 'build-prefix output-dir
compiler-system-job/job-set subroutine-job 'build-basename
	%arm64-hybrid-subroutine-integration
compiler-system-job/job-set subroutine-job 'build-suffix none

check linker/load-codegen subroutine-job subroutine-image [
	"Darwin linker rejected ARM64 subroutine image: " linker/codegen-error
]
subroutine-output: linker/build subroutine-job
check all [file? subroutine-output exists? subroutine-output][
	"Darwin linker did not write " mold subroutine-output
]
status: call/wait to-local-file subroutine-output
check status = 42 [
	"generated ARM64 subroutine module returned " status " instead of 42"
]

advanced-source: {
	Red/System []
	point!: alias struct! [x [integer!] y [integer!]]
	shape!: alias union! [
		[variant]
		point [point! value]
		id [integer!]
	]
	tag-check: func [return: [integer!] /local shape [shape!] score [integer!]][
		shape: declare shape!
		shape/point/x: 12
		shape/point/y: 34
		if not variant? shape 'point [return 1]
		if shape/point/x <> 12 [return 2]
		if shape/point/y <> 34 [return 3]
		score: switch shape [point [4] id [8] default [return 9]]
		if score <> 4 [return 4]
		shape/id: 99
		if variant? shape 'point [return 5]
		if not variant? shape 'id [return 6]
		if shape/id <> 99 [return 7]
		0
	]
	overflow-check: func [
		return: [integer!]
		/local value [integer!] wide [int64!] uwide [uint64!]
			narrow [uint8!] flag [logic!] side [integer!] inner [logic!]
	][
		flag: overflow? [value: 2147483647 + 1]
		if not flag [return 10]
		flag: overflow? [value: 1 + 1]
		if flag [return 11]

		value: 2147483647
		flag: overflow? [value: value + 1]
		if not flag [return 12]
		value: -2147483648
		flag: overflow? [value: value - 1]
		if not flag [return 13]
		flag: overflow? [value: 46340 * 46340]
		if flag [return 14]
		flag: overflow? [value: 46341 * 46341]
		if not flag [return 15]

		wide: as int64! #u64h-7FFFFFFFFFFFFFFF
		flag: overflow? [wide: wide + (as int64! 1)]
		if not flag [return 16]
		wide: as int64! -20000
		flag: overflow? [wide: wide * (as int64! 2)]
		if flag [return 17]
		if wide <> as int64! -40000 [return 18]
		wide: as int64! #u64h-4000000000000000
		flag: overflow? [wide: wide * (as int64! 4)]
		if not flag [return 19]

		uwide: as uint64! #u64h-FFFFFFFFFFFFFFFF
		flag: overflow? [uwide: uwide + (as uint64! 1)]
		if not flag [return 20]
		uwide: as uint64! 0
		flag: overflow? [uwide: uwide - (as uint64! 1)]
		if not flag [return 21]
		uwide: as uint64! #u64h-8000000000000000
		flag: overflow? [uwide: uwide * (as uint64! 2)]
		if not flag [return 22]

		narrow: as uint8! 255
		flag: overflow? [narrow: narrow + (as uint8! 1)]
		if not flag [return 23]
		narrow: as uint8! 127
		flag: overflow? [narrow: narrow + (as uint8! 1)]
		if flag [return 24]

		value: 1
		flag: overflow? [value: value << 31]
		if not flag [return 25]
		value: -1
		flag: overflow? [value: value << 31]
		if flag [return 26]

		value: -2147483648
		flag: overflow? [value: value / -1]
		if not flag [return 27]
		value: -2147483647
		flag: overflow? [value: value / -1]
		if flag [return 28]

		side: 0
		flag: overflow? [
			side: side + 1
			value: 2147483647 + 1
			side: side + 100
		]
		if not flag [return 29]
		if side <> 1 [return 30]

		flag: overflow? [
			inner: overflow? [value: 2147483647 + 1]
			value: 1 + 1
		]
		if flag [return 31]
		if not inner [return 32]
		0
	]
	main: func [return: [integer!] /local status [integer!]][
		status: tag-check
		if status <> 0 [return status]
		status: overflow-check
		if status <> 0 [return status]
		42
	]
}

advanced-ir: compiler-rsir-frontend/compile load advanced-source 'user
check binary? advanced-ir [
	"ARM64 tag/overflow integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part advanced-ir int-to-bin/to-bin32 3 4
change/part at advanced-ir 5 int-to-bin/to-bin32 (word-at advanced-ir 16) 4

advanced-image: make binary! 262144
status: codegen-module advanced-ir advanced-image 2 0
check status = 0 ["ARM64 tag/overflow integration codegen status=" status]

advanced-job: compiler-system-job/new 'Darwin-ARM64
check object? advanced-job "could not create a Darwin ARM64 tag/overflow job"
advanced-job: construct/with body-of advanced-job linker/job-class
compiler-system-job/job-set advanced-job 'runtime? false
compiler-system-job/job-set advanced-job 'debug? false
compiler-system-job/job-set advanced-job 'build-prefix output-dir
compiler-system-job/job-set advanced-job 'build-basename
	%arm64-hybrid-tag-overflow-integration
compiler-system-job/job-set advanced-job 'build-suffix none

check linker/load-codegen advanced-job advanced-image [
	"Darwin linker rejected ARM64 tag/overflow image: " linker/codegen-error
]
advanced-output: linker/build advanced-job
check all [file? advanced-output exists? advanced-output][
	"Darwin linker did not write " mold advanced-output
]
status: call/wait to-local-file advanced-output
check status = 42 [
	"generated ARM64 tag/overflow module returned " status " instead of 42"
]

print "PASS: direct ARM64 RSIR -> Mach-O -> execution"
