Red [
	Title: "Compact hybrid codegen routine smoke test"
]

#include %../../../compiler/int-to-bin.red
#include %../../../compiler/rsir-frontend.red
#include %../../../compiler/codegen-bridge.red

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

generate: func [kind [word!] result [word!] /local source ir artifact status][
	source: either result = 'void [
		[Red/System [] fn: func [][]]
	][
		[Red/System [] fn: func [return: [integer!]][7]]
	]
	ir: compiler-rsir-frontend/compile source kind
	unless binary? ir [fail ["frontend rejected " kind " " result]]
	artifact: make binary! 4096
	status: codegen-module ir artifact 0
	unless status = 0 [fail [kind " " result " codegen status=" status]]
	reduce [ir artifact]
]

check-image: func [
	kind result [word!]
	expected-size expected-code-size expected-code-offset expected-exit-ref [integer!]
	/local pair ir artifact entry? metadata-size names-start code-offset
][
	pair: generate kind result
	ir: pair/1
	artifact: pair/2
	entry?: kind = 'glue
	check (length? artifact) = expected-size [kind " " result " image size changed"]
	check all [
		(word-at artifact 0) = expected-size
		(word-at artifact 4) = either entry? [3][1]
		(word-at artifact 8) = either entry? [2][0]
		(word-at artifact 12) = either entry? [2][1]
		(word-at artifact 16) = either entry? [1][0]
		(word-at artifact 20) = either entry? [1][0]
		(word-at artifact 28) = expected-code-offset
		(word-at artifact 32) = expected-code-size
		(word-at artifact 36) = 16
		(word-at artifact 40) = 0
	][kind " " result " image header changed"]
	check all [
		(word-at artifact 44) = 0
		(word-at artifact 48) = 2
		(word-at artifact 52) = either entry? [31][0]
		(word-at artifact 56) = (expected-code-size - (either entry? [31][0]))
		(word-at artifact 60) = 32
		(word-at artifact 64) = 0
		(word-at artifact 68) = 16
		(word-at artifact 72) = 0
		(word-at artifact 76) = 0
	][kind " " result " function record changed"]
	if entry? [
		check all [
			(word-at artifact 80) = 2
			(word-at artifact 84) = 8
			(word-at artifact 88) = 0
			(word-at artifact 92) = 31
			(word-at artifact 96) = 32
			(word-at artifact 100) = 0
			(word-at artifact 104) = 16
			(word-at artifact 108) = 0
			(word-at artifact 112) = 0
		][kind " " result " module-body function record changed"]
	]
	metadata-size: either entry? [144][80]
	names-start: metadata-size
	check (copy/part at artifact (names-start + 1) either entry? [10][2]) =
		either entry? [to binary! "fn***-main"][#{666E}]
		[kind " " result " function names changed"]
	if entry? [
		check all [
			(word-at artifact 116) = 10
			(word-at artifact 120) = 12
			(word-at artifact 124) = 22
			(word-at artifact 128) = 11
			(word-at artifact 132) = 1
			(word-at artifact 136) = 1
			(word-at artifact 140) = expected-exit-ref
			(copy/part at artifact 155 12) = #{6B65726E656C33322E646C6C}
			(copy/part at artifact 167 11) = #{4578697450726F63657373}
		][kind " " result " import record changed"]
	]
	code-offset: word-at artifact 28
	check (word-at artifact (code-offset + 9)) = 0
		[kind " " result " bitmap word offset changed"]
	if result = 'i32 [
		check (word-at artifact (code-offset + (either entry? [47][16]))) = 7
			[kind " i32 literal changed"]
	]
	if entry? [
		check (word-at artifact (code-offset + expected-exit-ref)) = 0
			[kind " " result " exit relocation placeholder changed"]
	]
	check (copy at artifact (expected-size - 15)) =
		#{00000000000000000000000000000000}
		[kind " " result " bitmap is not zero initialized"]
	artifact
]

check-image 'user 'void 132 17 96 0
check-image 'glue 'void 256 48 192 23
user-i32: check-image 'user 'i32 136 22 96 0
glue-i32: check-image 'glue 'i32 264 53 192 23

module-ir: compiler-rsir-frontend/compile [
	Red/System []
	red: context [
		#import ["fixture.dll" stdcall [boot?: "boot?" [logic!]]]
	]
	red/boot?: yes
] 'glue
check binary? module-ir ["frontend rejected module-body import store: "
	mold compiler-rsir-frontend/last-error]
module-image: make binary! 4096
check (codegen-module module-ir module-image 0) = 0
	"module-body import store codegen failed"
check all [
	(length? module-image) = 252
	(word-at module-image 8) = 1
	(word-at module-image 12) = 1
	(word-at module-image 16) = 2
	(word-at module-image 20) = 2
	(word-at module-image 24) = 47
	(word-at module-image 28) = 192
	(word-at module-image 32) = 44
	(word-at module-image 52) = 0
	(word-at module-image 56) = 44
	(word-at module-image 80) = 8
	(word-at module-image 88) = 19
	(word-at module-image 92) = 5
	(word-at module-image 96) = 1
	(word-at module-image 104) = 24
	(word-at module-image 112) = 36
	(word-at module-image 116) = 11
	(word-at module-image 120) = 2
	(word-at module-image 128) = 18
	(word-at module-image 132) = 36
	(copy/part at module-image 137 47) =
		to binary! "***-mainfixture.dllboot?kernel32.dllExitProcess"
	(copy/part at module-image 193 44) = #{
		554889E56A006A0068000000006A00488B0500000000C700010000004883
		EC2031C9FF150000000031C0C9C3
	}
]["module-body store image is not direct or contiguous"]

multi-store-ir: compiler-rsir-frontend/compile [
	Red/System []
	state: context [
		#import ["fixture.dll" stdcall [
			enabled?: "enabled?" [logic!]
			count: "count" [integer!]
		]]
	]
	state/enabled?: yes
	state/count: 42
] 'glue
check binary? multi-store-ir ["frontend rejected a linear module body: "
	mold compiler-rsir-frontend/last-error]
multi-store-image: make binary! 4096
check (codegen-module multi-store-ir multi-store-image 0) = 0
	"linear module-body codegen failed"
check all [
	(length? multi-store-image) = 300
	(word-at multi-store-image 8) = 1
	(word-at multi-store-image 12) = 1
	(word-at multi-store-image 16) = 3
	(word-at multi-store-image 20) = 3
	(word-at multi-store-image 24) = 55
	(word-at multi-store-image 28) = 224
	(word-at multi-store-image 32) = 57
	(word-at multi-store-image 36) = 16
	(word-at multi-store-image 40) = 0
	(word-at multi-store-image 56) = 57
	(word-at multi-store-image 152) = 18
	(word-at multi-store-image 156) = 31
	(word-at multi-store-image 160) = 49
	(copy/part at multi-store-image 165 55) =
		to binary! "***-mainfixture.dllenabled?countkernel32.dllExitProcess"
	(copy/part at multi-store-image 225 57) = #{
		554889E56A006A0068000000006A00488B0500000000C70001000000488B
		0500000000C7002A0000004883EC2031C9FF150000000031C0C9C3
	}
]["linear module body lost instruction order or direct references"]

typed-source: [
	Red/System []
	byte-alias!: alias byte!
	small!: alias struct! [
		mark [byte-alias!]
		count [integer!]
		wide [uint64!]
	]
	nested!: alias struct! [
		head [byte!]
		sub [small! value]
		tail [uint16!]
	]
	refs!: alias struct! [
		sub [small!]
		ptr [pointer! [integer!]]
	]
	#enum choice! [CHOICE_ZERO CHOICE_FOUR: 4 CHOICE_FIVE]
	fn: func [return: [integer!]][7]
]
typed-ir: compiler-rsir-frontend/compile typed-source 'user
check binary? typed-ir ["frontend rejected logical type stream: "
	mold compiler-rsir-frontend/last-error]
typed-image: make binary! 4096
check (codegen-module typed-ir typed-image 0) = 0
	"native codegen rejected logical type records"
check typed-image = user-i32
	"unused logical type records changed native code"

callable-ir: compiler-rsir-frontend/compile [
	Red/System []
	small!: alias struct! [value [integer!]]
	callback!: alias function! [
		[cdecl]
		input [integer!]
		state [small! value]
		return: [small! value]
	]
	worker!: alias subroutine! [[callback] value [uint32!]]
	fn: func [return: [integer!]][7]
] 'user
check binary? callable-ir ["frontend rejected callable types: "
	mold compiler-rsir-frontend/last-error]
callable-image: make binary! 4096
check (codegen-module callable-ir callable-image 0) = 0
	"native codegen rejected direct callable signatures"
check callable-image = user-i32
	"unused callable signatures changed native code"

pointer-global-ir: compiler-rsir-frontend/compile [
	Red/System []
	cell!: alias struct! [value [integer!]]
	base: as cell! 0
	fn: func [return: [integer!]][7]
] 'user
check binary? pointer-global-ir ["frontend rejected a static pointer global: "
	mold compiler-rsir-frontend/last-error]
pointer-global-image: make binary! 4096
check (codegen-module pointer-global-ir pointer-global-image 0) = 0
	"static pointer global codegen failed"
check all [
	(length? pointer-global-image) = 160
	(word-at pointer-global-image 20) = 0
	(word-at pointer-global-image 24) = 6
	(word-at pointer-global-image 28) = 112
	(word-at pointer-global-image 32) = 22
	(word-at pointer-global-image 36) = 24
	(word-at pointer-global-image 40) = 1
	(word-at pointer-global-image 80) = 2
	(word-at pointer-global-image 84) = 4
	(word-at pointer-global-image 88) = 16
	(word-at pointer-global-image 92) = 8
	(word-at pointer-global-image 96) = 0
	(word-at pointer-global-image 100) = 0
	(copy/part at pointer-global-image 105 6) = to binary! "fnbase"
	(copy at pointer-global-image 137) =
		#{000000000000000000000000000000000000000000000000}
]["static aggregate alias was not laid out as a pointer global"]

string-init-ir: compiler-rsir-frontend/compile [
	Red/System []
	red-word!: alias struct! [header [integer!]]
	red: context [
		#import ["fixture.dll" stdcall [
			load: "load" [text [c-string!] return: [red-word!]]
			make: "make" [text [c-string!] return: [integer!]]
		]]
	]
	body: red/load "<body>"
	symbol: red/make "type"
] 'glue
check binary? string-init-ir ["frontend rejected string global initialization: "
	mold compiler-rsir-frontend/last-error]
string-init-image: make binary! 4096
check (codegen-module string-init-ir string-init-image 0) = 0
	"string global initialization codegen failed"
check all [
	(length? string-init-image) = 400
	(word-at string-init-image 8) = 1
	(word-at string-init-image 12) = 1
	(word-at string-init-image 16) = 3
	(word-at string-init-image 20) = 5
	(word-at string-init-image 24) = 60
	(word-at string-init-image 28) = 288
	(word-at string-init-image 32) = 82
	(word-at string-init-image 36) = 28
	(word-at string-init-image 40) = 2
	(word-at string-init-image 52) = 0
	(word-at string-init-image 56) = 70
]["string initialization image layout changed"]
check all [
	(word-at string-init-image 80) = 8
	(word-at string-init-image 84) = 4
	(word-at string-init-image 88) = 16
	(word-at string-init-image 92) = 8
	(word-at string-init-image 96) = 1
	(word-at string-init-image 100) = 1
	(word-at string-init-image 104) = 12
	(word-at string-init-image 108) = 6
	(word-at string-init-image 112) = 24
	(word-at string-init-image 116) = 4
	(word-at string-init-image 120) = 2
	(word-at string-init-image 124) = 1
	(word-at string-init-image 128) = 18
	(word-at string-init-image 136) = 29
	(word-at string-init-image 144) = 3
	(word-at string-init-image 152) = 18
	(word-at string-init-image 160) = 33
	(word-at string-init-image 168) = 4
	(word-at string-init-image 176) = 37
	(word-at string-init-image 184) = 49
	(word-at string-init-image 192) = 5
]["string initialization reference slices changed"]
check all [
	(word-at string-init-image 200) = 35
	(word-at string-init-image 204) = 54
	(word-at string-init-image 208) = 28
	(word-at string-init-image 212) = 48
	(word-at string-init-image 216) = 62
	(copy/part at string-init-image 221 60) =
		to binary! "***-mainbodysymbolfixture.dllloadmakekernel32.dllExitProcess"
	(copy/part at string-init-image 289 82) = #{
		554889E56A006A0068000000006A004883EC20488D0D2C000000FF150000
		000048890500000000488D0D1F000000FF150000000089050000000031C9
		FF150000000031C0C9C33C626F64793E007479706500
	}
]["string/call/store code is not direct and contiguous"]

imported-pointer-init-ir: compiler-rsir-frontend/compile [
	Red/System []
	cell!: alias struct! [value [integer!]]
	red: context [
		#import ["fixture.dll" stdcall [top: "top" [cell!]]]
	]
	bottom: red/top
] 'glue
check binary? imported-pointer-init-ir [
	"frontend rejected imported pointer initialization: "
	mold compiler-rsir-frontend/last-error
]
imported-pointer-init-image: make binary! 4096
check (codegen-module imported-pointer-init-ir imported-pointer-init-image 0) = 0
	"imported pointer initialization codegen failed"
check all [
	(length? imported-pointer-init-image) = 296
	(word-at imported-pointer-init-image 8) = 1
	(word-at imported-pointer-init-image 12) = 1
	(word-at imported-pointer-init-image 16) = 2
	(word-at imported-pointer-init-image 20) = 3
	(word-at imported-pointer-init-image 24) = 51
	(word-at imported-pointer-init-image 28) = 224
	(word-at imported-pointer-init-image 32) = 48
	(word-at imported-pointer-init-image 36) = 24
	(word-at imported-pointer-init-image 40) = 1
	(word-at imported-pointer-init-image 56) = 48
]["imported pointer initialization image layout changed"]
check all [
	(word-at imported-pointer-init-image 80) = 8
	(word-at imported-pointer-init-image 84) = 6
	(word-at imported-pointer-init-image 88) = 16
	(word-at imported-pointer-init-image 92) = 8
	(word-at imported-pointer-init-image 96) = 1
	(word-at imported-pointer-init-image 100) = 1
	(word-at imported-pointer-init-image 152) = 28
	(word-at imported-pointer-init-image 156) = 18
	(word-at imported-pointer-init-image 160) = 40
	(copy/part at imported-pointer-init-image 165 51) =
		to binary! "***-mainbottomfixture.dlltopkernel32.dllExitProcess"
	(copy/part at imported-pointer-init-image 225 48) = #{
		554889E56A006A0068000000006A00488B0500000000488B004889050000
		00004883EC2031C9FF150000000031C0C9C3
	}
	(copy at imported-pointer-init-image 273) =
		#{000000000000000000000000000000000000000000000000}
]["imported pointer load/store code is not direct and contiguous"]

node-call-ir: compiler-rsir-frontend/compile [
	Red/System []
	node-handle!: alias integer!
	#import ["fixture.dll" stdcall [
		get-root-node2: "get-root-node2" [
			idx [integer!]
			return: [node-handle!]
		]
	]]
	ctx: get-root-node2 96
] 'glue
check binary? node-call-ir ["frontend rejected integer call initialization: "
	mold compiler-rsir-frontend/last-error]
node-call-image: make binary! 4096
check (codegen-module node-call-ir node-call-image 0) = 0
	"integer call initialization codegen failed"
check all [
	(length? node-call-image) = 292
	(word-at node-call-image 8) = 1
	(word-at node-call-image 12) = 1
	(word-at node-call-image 16) = 2
	(word-at node-call-image 20) = 3
	(word-at node-call-image 24) = 59
	(word-at node-call-image 28) = 224
	(word-at node-call-image 32) = 48
	(word-at node-call-image 36) = 20
	(word-at node-call-image 40) = 1
	(word-at node-call-image 56) = 48
]["integer call initialization image layout changed"]
check all [
	(word-at node-call-image 80) = 8
	(word-at node-call-image 84) = 3
	(word-at node-call-image 88) = 16
	(word-at node-call-image 92) = 4
	(word-at node-call-image 96) = 1
	(word-at node-call-image 100) = 1
	(word-at node-call-image 104) = 11
	(word-at node-call-image 108) = 11
	(word-at node-call-image 112) = 22
	(word-at node-call-image 116) = 14
	(word-at node-call-image 120) = 2
	(word-at node-call-image 124) = 1
	(word-at node-call-image 128) = 36
	(word-at node-call-image 132) = 12
	(word-at node-call-image 136) = 48
	(word-at node-call-image 140) = 11
	(word-at node-call-image 144) = 3
	(word-at node-call-image 148) = 1
]["integer call initialization symbol slices changed"]
check all [
	(word-at node-call-image 152) = 32
	(word-at node-call-image 156) = 26
	(word-at node-call-image 160) = 40
	(copy/part at node-call-image 165 59) =
		to binary! "***-mainctxfixture.dllget-root-node2kernel32.dllExitProcess"
	(copy/part at node-call-image 225 48) = #{
		554889E56A006A0068000000006A004883EC20B960000000FF150000000089
		050000000031C9FF150000000031C0C9C3
	}
	(copy at node-call-image 273) =
		#{0000000000000000000000000000000000000000}
]["integer call initialization code is not direct and contiguous"]

stack-top-ir: compiler-rsir-frontend/compile [
	Red/System []
	red: context [
		#import ["fixture.dll" stdcall [
			stk-bottom: "stk-bottom" [int-ptr!]
		]]
	]
	with red [stk-bottom: system/stack/top]
] 'glue
check binary? stack-top-ir ["frontend rejected system/stack/top: "
	mold compiler-rsir-frontend/last-error]
stack-top-image: make binary! 4096
check (codegen-module stack-top-ir stack-top-image 0) = 0
	"system/stack/top codegen failed"
check all [
	(length? stack-top-image) = 252
	(word-at stack-top-image 8) = 1
	(word-at stack-top-image 12) = 1
	(word-at stack-top-image 16) = 2
	(word-at stack-top-image 20) = 2
	(word-at stack-top-image 24) = 52
	(word-at stack-top-image 28) = 192
	(word-at stack-top-image 32) = 44
	(word-at stack-top-image 36) = 16
	(word-at stack-top-image 40) = 0
	(word-at stack-top-image 56) = 44
	(word-at stack-top-image 80) = 8
	(word-at stack-top-image 88) = 19
	(word-at stack-top-image 92) = 10
	(word-at stack-top-image 96) = 1
	(word-at stack-top-image 100) = 1
	(word-at stack-top-image 128) = 21
	(word-at stack-top-image 132) = 36
	(copy/part at stack-top-image 137 52) =
		to binary! "***-mainfixture.dllstk-bottomkernel32.dllExitProcess"
	(copy/part at stack-top-image 193 44) = #{
		554889E56A006A0068000000006A004889E0488B15000000004889024883
		EC2031C9FF150000000031C0C9C3
	}
]["system/stack/top code is not direct and contiguous"]

boot-load-ir: compiler-rsir-frontend/compile [
	Red/System []
	red: context [
		cell!: alias struct! [value [integer!]]
		root-base: as cell! 0
		redbin: context [
			#import ["fixture.dll" stdcall [
				boot-load: "boot-load" [
					payload [pointer! [byte!]]
					keep? [logic!]
					return: [cell!]
				]
			]]
		]
	]
	with red [root-base: redbin/boot-load system/boot-data yes]
] 'glue
check binary? boot-load-ir ["frontend rejected boot-load initialization: "
	mold compiler-rsir-frontend/last-error]
boot-load-image: make binary! 4096
check (codegen-module boot-load-ir boot-load-image 0) = 0
	"boot-load initialization codegen failed"
check all [
	(length? boot-load-image) = 368
	(word-at boot-load-image 8) = 1
	(word-at boot-load-image 12) = 1
	(word-at boot-load-image 16) = 3
	(word-at boot-load-image 20) = 4
	(word-at boot-load-image 24) = 70
	(word-at boot-load-image 28) = 272
	(word-at boot-load-image 32) = 69
	(word-at boot-load-image 36) = 24
	(word-at boot-load-image 40) = 1
	(word-at boot-load-image 56) = 69
]["boot-load image layout changed"]
check all [
	(word-at boot-load-image 80) = 8
	(word-at boot-load-image 84) = 13
	(word-at boot-load-image 88) = 16
	(word-at boot-load-image 92) = 8
	(word-at boot-load-image 96) = 1
	(word-at boot-load-image 100) = 1
	(word-at boot-load-image 104) = 21
	(word-at boot-load-image 112) = 32
	(word-at boot-load-image 116) = 9
	(word-at boot-load-image 120) = 2
	(word-at boot-load-image 128) = 21
	(word-at boot-load-image 136) = 41
	(word-at boot-load-image 140) = 6
	(word-at boot-load-image 144) = 3
	(word-at boot-load-image 152) = 47
	(word-at boot-load-image 160) = 59
	(word-at boot-load-image 164) = 11
	(word-at boot-load-image 168) = 4
]["boot-load symbol slices changed"]
check all [
	(word-at boot-load-image 176) = 53
	(word-at boot-load-image 180) = 46
	(word-at boot-load-image 184) = 18
	(word-at boot-load-image 188) = 61
	(copy/part at boot-load-image 193 70) =
		to binary! "***-mainred>root-basefixture.dllboot-loadsystemkernel32.dllExitProcess"
	(copy/part at boot-load-image 273 69) = #{
		554889E56A006A0068000000006A00488B0500000000488B00488B804800
		00004889C1BA010000004883EC20FF15000000004889050000000031C9FF
		150000000031C0C9C3
	}
	(copy at boot-load-image 345) =
		#{000000000000000000000000000000000000000000000000}
]["boot-load member/call/store code is not direct and contiguous"]

import-ir: compiler-rsir-frontend/compile [
	Red/System []
	#import ["fixture.dll" stdcall [
		native-call: "native-call" [value [integer!] return: [integer!]]
		native-value: "native-value" [integer!]
	]]
	fn: func [return: [integer!]][7]
] 'user
check binary? import-ir ["frontend rejected direct imports: "
	mold compiler-rsir-frontend/last-error]
import-image: make binary! 4096
check (codegen-module import-ir import-image 0) = 0
	"native codegen rejected direct import declarations"
check import-image = user-i32
	"unused import declarations changed native code"

import-variable-ir: compiler-rsir-frontend/compile [
	Red/System []
	red: context [
		#import ["fixture.dll" stdcall [
			native-value: "native-value" [integer!]
			boot?: "boot?" [logic!]
		]]
	]
	reader: func [return: [integer!]][red/native-value]
	main: func [][red/boot?: yes]
] 'glue
check binary? import-variable-ir ["frontend rejected imported variable access: "
	mold compiler-rsir-frontend/last-error]
import-variable-image: make binary! 4096
check (codegen-module import-variable-ir import-variable-image 0) = 0
	"imported variable codegen failed"
check all [
	(length? import-variable-image) = 424
	(word-at import-variable-image 8) = 3
	(word-at import-variable-image 12) = 3
	(word-at import-variable-image 16) = 3
	(word-at import-variable-image 20) = 3
	(word-at import-variable-image 24) = 69
	(word-at import-variable-image 28) = 320
	(word-at import-variable-image 32) = 87
	(word-at import-variable-image 36) = 16
	(word-at import-variable-image 40) = 0
]["imported variable image header changed"]
check all [
	(word-at import-variable-image 52) = 31
	(word-at import-variable-image 56) = 26
	(word-at import-variable-image 88) = 57
	(word-at import-variable-image 92) = 30
	(word-at import-variable-image 116) = 10
	(word-at import-variable-image 124) = 0
	(word-at import-variable-image 128) = 31
	(word-at import-variable-image 152) = 18
	(word-at import-variable-image 160) = 29
	(word-at import-variable-image 164) = 12
	(word-at import-variable-image 176) = 18
	(word-at import-variable-image 184) = 41
	(word-at import-variable-image 188) = 5
	(word-at import-variable-image 200) = 46
	(word-at import-variable-image 208) = 58
	(word-at import-variable-image 212) = 11
	(word-at import-variable-image 224) = 49
	(word-at import-variable-image 228) = 75
	(word-at import-variable-image 232) = 23
]["imported variable reference slices changed"]
check (copy/part at import-variable-image 237 69) =
	to binary!
		"readermain***-mainfixture.dllnative-valueboot?kernel32.dllExitProcess"
	"imported variable names are not direct and contiguous"
check (copy/part at import-variable-image 321 87) = #{
	554889E56A006A0068000000006A004883EC2031C9FF150000000031C0C9C3
	554889E56A006A0068000000006A00488B05000000008B00C9C3554889E56A
	006A0068000000006A00488B0500000000C70001000000C9C3
} "imported variable x64 encoding changed"

global-ir: compiler-rsir-frontend/compile [
	Red/System []
	answer: 42
	ready?: true
	fn: func [return: [integer!]][answer]
] 'user
check binary? global-ir ["frontend rejected static globals: "
	mold compiler-rsir-frontend/last-error]
global-image: make binary! 4096
check (codegen-module global-ir global-image 0) = 0
	"static global codegen failed"
check all [
	(length? global-image) = 208
	(word-at global-image 12) = 1
	(word-at global-image 16) = 0
	(word-at global-image 20) = 1
	(word-at global-image 24) = 14
	(word-at global-image 28) = 160
	(word-at global-image 32) = 23
	(word-at global-image 36) = 24
	(word-at global-image 40) = 2
]["static global image header changed"]
check all [
	(word-at global-image 80) = 2
	(word-at global-image 84) = 6
	(word-at global-image 88) = 16
	(word-at global-image 92) = 4
	(word-at global-image 96) = 1
	(word-at global-image 100) = 1
	(word-at global-image 104) = 8
	(word-at global-image 108) = 6
	(word-at global-image 112) = 20
	(word-at global-image 116) = 4
	(word-at global-image 128) = 17
	(copy/part at global-image 133 14) = to binary! "fnanswerready?"
	(copy/part at global-image 161 23) =
		#{554889E56A006A0068000000006A008B0500000000C9C3}
	(copy/part at global-image 185 16) = #{00000000000000000000000000000000}
	(word-at global-image 200) = 42
	(word-at global-image 204) = 1
]["static global load, layout, or initializer changed"]

shared-global-ir: compiler-rsir-frontend/compile [
	Red/System []
	answer: 42
	helper: func [return: [integer!]][answer]
	main: func [return: [integer!]][answer]
] 'glue
check binary? shared-global-ir ["frontend rejected shared global loads: "
	mold compiler-rsir-frontend/last-error]
shared-global-image: make binary! 4096
check (codegen-module shared-global-ir shared-global-image 0) = 0
	"shared global load codegen failed"
check all [
	(length? shared-global-image) = 372
	(word-at shared-global-image 8) = 3
	(word-at shared-global-image 12) = 3
	(word-at shared-global-image 16) = 1
	(word-at shared-global-image 20) = 3
	(word-at shared-global-image 24) = 47
	(word-at shared-global-image 28) = 272
	(word-at shared-global-image 32) = 77
	(word-at shared-global-image 36) = 20
	(word-at shared-global-image 40) = 1
]["shared global image header changed"]
check all [
	(word-at shared-global-image 52) = 31
	(word-at shared-global-image 56) = 23
	(word-at shared-global-image 88) = 54
	(word-at shared-global-image 92) = 23
	(word-at shared-global-image 116) = 10
	(word-at shared-global-image 124) = 0
	(word-at shared-global-image 128) = 31
	(word-at shared-global-image 152) = 18
	(word-at shared-global-image 160) = 16
	(word-at shared-global-image 168) = 1
	(word-at shared-global-image 172) = 2
	(word-at shared-global-image 176) = 24
	(word-at shared-global-image 184) = 36
	(word-at shared-global-image 192) = 3
	(word-at shared-global-image 200) = 48
	(word-at shared-global-image 204) = 71
	(word-at shared-global-image 208) = 23
	(copy/part at shared-global-image 213 47) =
		to binary! "helpermain***-mainanswerkernel32.dllExitProcess"
]["shared global reference slice is not direct and contiguous"]

import-call-ir: compiler-rsir-frontend/compile [
	Red/System []
	#import ["fixture.dll" stdcall [
		native-call: "native-call" [value [integer!] return: [integer!]]
	]]
	fn: func [return: [integer!]][native-call 7]
] 'glue
check binary? import-call-ir ["frontend rejected an imported call: "
	mold compiler-rsir-frontend/last-error]
import-call-image: make binary! 4096
check (codegen-module import-call-ir import-call-image 0) = 0
	"imported call codegen failed"
check all [
	(length? import-call-image) = 320
	(word-at import-call-image 8) = 2
	(word-at import-call-image 12) = 2
	(word-at import-call-image 16) = 2
	(word-at import-call-image 20) = 2
	(word-at import-call-image 24) = 55
	(word-at import-call-image 28) = 240
	(word-at import-call-image 32) = 63
	(word-at import-call-image 40) = 0
]["imported call image header changed"]
check all [
	(word-at import-call-image 44) = 0
	(word-at import-call-image 48) = 2
	(word-at import-call-image 52) = 31
	(word-at import-call-image 56) = 32
	(word-at import-call-image 80) = 2
	(word-at import-call-image 84) = 8
	(word-at import-call-image 88) = 0
	(word-at import-call-image 92) = 31
	(word-at import-call-image 116) = 10
	(word-at import-call-image 124) = 21
	(word-at import-call-image 128) = 11
	(word-at import-call-image 132) = 1
	(word-at import-call-image 140) = 32
	(word-at import-call-image 148) = 44
	(word-at import-call-image 152) = 11
	(word-at import-call-image 156) = 2
	(word-at import-call-image 164) = 57
	(word-at import-call-image 168) = 23
]["imported call records or reference slices changed"]
check (copy/part at import-call-image 173 55) =
	to binary! "fn***-mainfixture.dllnative-callkernel32.dllExitProcess"
	"imported call names are not direct and contiguous"
check (copy/part at import-call-image 241 63) = #{
	554889E56A006A0068000000006A004883EC2031C9FF150000000031C0C9C3
	554889E56A006A0068000000006A004883EC20B907000000FF1500000000C9C3
}
	"imported call machine encoding changed"

group-import-ir: compiler-rsir-frontend/compile [
	Red/System []
	#import ["fixture.dll" stdcall [
		first-call: "first" [return: [integer!]]
		second-call: "second" [return: [integer!]]
		unused-call: "unused" [return: [integer!]]
	]]
	helper: func [return: [integer!]][first-call]
	main: func [return: [integer!]][second-call]
] 'glue
check binary? group-import-ir ["frontend rejected grouped imported calls: "
	mold compiler-rsir-frontend/last-error]
group-import-image: make binary! 4096
check (codegen-module group-import-ir group-import-image 0) = 0
	"grouped imported call codegen failed"
check all [
	(length? group-import-image) = 408
	(word-at group-import-image 8) = 3
	(word-at group-import-image 12) = 3
	(word-at group-import-image 16) = 3
	(word-at group-import-image 20) = 3
	(word-at group-import-image 24) = 63
	(word-at group-import-image 28) = 304
	(word-at group-import-image 32) = 85
	(word-at group-import-image 152) = 18
	(word-at group-import-image 164) = 5
	(word-at group-import-image 176) = 18
	(word-at group-import-image 188) = 6
	(word-at group-import-image 200) = 40
	(word-at group-import-image 212) = 11
	(word-at group-import-image 224) = 52
	(word-at group-import-image 228) = 79
	(word-at group-import-image 232) = 23
]["grouped imports duplicated their library or lost a reference"]
check (copy/part at group-import-image 237 63) =
	to binary! "helpermain***-mainfixture.dllfirstsecondkernel32.dllExitProcess"
	"grouped imported names are not compact"

forward-import-ir: compiler-rsir-frontend/compile [
	Red/System []
	#import ["fixture.dll" stdcall [
		native-call: "native-call" [value [integer!] return: [integer!]]
	]]
	relay: func [value [integer!] return: [integer!]][native-call value]
	main: func [return: [integer!]][relay 7]
] 'glue
check binary? forward-import-ir ["frontend rejected imported parameter forwarding: "
	mold compiler-rsir-frontend/last-error]
forward-import-image: make binary! 4096
check (codegen-module forward-import-ir forward-import-image 0) = 0
	"imported parameter-forwarding codegen failed"
check all [
	(length? forward-import-image) = 380
	(word-at forward-import-image 8) = 3
	(word-at forward-import-image 12) = 3
	(word-at forward-import-image 16) = 2
	(word-at forward-import-image 20) = 2
	(word-at forward-import-image 24) = 62
	(word-at forward-import-image 28) = 272
	(word-at forward-import-image 32) = 89
	(word-at forward-import-image 52) = 31
	(word-at forward-import-image 56) = 27
	(word-at forward-import-image 88) = 58
	(word-at forward-import-image 92) = 31
	(word-at forward-import-image 116) = 9
	(word-at forward-import-image 124) = 0
	(word-at forward-import-image 128) = 31
	(word-at forward-import-image 200) = 52
	(word-at forward-import-image 204) = 23
	(copy/part at forward-import-image 209 62) =
		to binary! "relaymain***-mainfixture.dllnative-callkernel32.dllExitProcess"
]["imported parameter forwarding lost its code or relocation"]

layout-source: [
	Red/System []
	byte-alias!: alias byte!
	small!: alias struct! [
		mark [byte-alias!]
		count [integer!]
		wide [uint64!]
	]
	nested!: alias struct! [
		head [byte!]
		sub [small! value]
		tail [uint16!]
	]
	refs!: alias struct! [
		sub [small!]
		ptr [pointer! [integer!]]
	]
	choice!: alias union! [
		small [small! value]
		wide [uint64!]
	]
	node!: alias struct! [next [node!]]
	pointer-size: func [return: [integer!]][size? pointer! [integer!]]
	small-size: func [return: [integer!]][size? small!]
	nested-size: func [return: [integer!]][size? nested!]
	refs-size: func [return: [integer!]][size? refs!]
	choice-size: func [return: [integer!]][size? choice!]
	node-size: func [return: [integer!]][size? node!]
]
layout-ir: compiler-rsir-frontend/compile layout-source 'user
check binary? layout-ir ["frontend rejected native layout source: "
	mold compiler-rsir-frontend/last-error]
layout-image: make binary! 4096
check (codegen-module layout-ir layout-image 0) = 0
	"native layout codegen failed"
expected-sizes: [8 16 32 16 16 8]
code-base: word-at layout-image 28
repeat id length? expected-sizes [
	record: 44 + ((id - 1) * 36)
	code-offset: word-at layout-image (record + 8)
	actual-size: word-at layout-image (code-base + code-offset + 16)
	check actual-size = expected-sizes/:id [
		"native layout mismatch for function " id
		": code-offset=" code-offset
		" expected=" expected-sizes/:id
		" actual=" actual-size
	]
]

cyclic-layout-ir: compiler-rsir-frontend/compile [
	Red/System []
	loop!: alias struct! [self [loop! value]]
	fn: func [return: [integer!]][size? loop!]
] 'user
check binary? cyclic-layout-ir "frontend rejected logical by-value cycle too early"
artifact: make binary! 4096
check (codegen-module cyclic-layout-ir artifact 0) = 2
	"native layout accepted a recursive by-value aggregate"
check empty? artifact "recursive by-value layout committed bytes"

bad-type: copy typed-ir
change/part at bad-type 29 int-to-bin/to-bin32 -99 4
artifact: make binary! 4096
check (codegen-module bad-type artifact 0) = 2 "unknown logical type kind was accepted"
check empty? artifact "bad logical type kind committed bytes"

bad-type: copy typed-ir
change/part at bad-type 33 int-to-bin/to-bin32 0 4
artifact: make binary! 4096
check (codegen-module bad-type artifact 0) = 2 "zero alias target was accepted"
check empty? artifact "bad alias target committed bytes"

bad-type: copy typed-ir
change/part at bad-type 45 int-to-bin/to-bin32 1 4
artifact: make binary! 4096
check (codegen-module bad-type artifact 0) = 2 "alias members were accepted"
check empty? artifact "bad alias member count committed bytes"

bad-type: copy typed-ir
change/part at bad-type 173 int-to-bin/to-bin32 2 4
artifact: make binary! 4096
check (codegen-module bad-type artifact 0) = 2 "unknown member flag was accepted"
check empty? artifact "bad member flag committed bytes"

bad-type: copy typed-ir
change/part at bad-type 161 int-to-bin/to-bin32 1 4
artifact: make binary! 4096
check (codegen-module bad-type artifact 0) = 2 "scalar by-value member was accepted"
check empty? artifact "bad by-value member committed bytes"

bad-type: copy typed-ir
change/part at bad-type 209 int-to-bin/to-bin32 1 4
artifact: make binary! 4096
check (codegen-module bad-type artifact 0) = 2 "noncontiguous parameter slice was accepted"
check empty? artifact "bad parameter slice committed bytes"

bad-import: copy import-ir
change/part at bad-import 53 int-to-bin/to-bin32 1 4
artifact: make binary! 4096
check (codegen-module bad-import artifact 0) = 2
	"noncontiguous import parameter slice was accepted"
check empty? artifact "bad import parameter slice committed bytes"

call-source: [
	Red/System []
	helper: func [return: [integer!]][41]
	main: func [return: [integer!]][helper]
]
call-ir: compiler-rsir-frontend/compile call-source 'glue
check binary? call-ir ["frontend rejected multi-function call: "
	mold compiler-rsir-frontend/last-error]
call-image: make binary! 4096
check (codegen-module call-ir call-image 0) = 0 "multi-function codegen failed"
check all [
	(length? call-image) = 320
	(word-at call-image 8) = 3
	(word-at call-image 12) = 3
	(word-at call-image 20) = 1
	(word-at call-image 24) = 41
	(word-at call-image 28) = 224
	(word-at call-image 32) = 79
]["multi-function image header changed"]
check all [
	(word-at call-image 44) = 0
	(word-at call-image 48) = 6
	(word-at call-image 52) = 31
	(word-at call-image 56) = 22
	(word-at call-image 80) = 6
	(word-at call-image 84) = 4
	(word-at call-image 88) = 53
	(word-at call-image 92) = 26
	(word-at call-image 116) = 10
	(word-at call-image 124) = 0
	(word-at call-image 128) = 31
]["multi-function code layout changed"]
check all [
	(word-at call-image 176) = 23
	(copy/part at call-image 181 41) =
		to binary! "helpermain***-mainkernel32.dllExitProcess"
	(word-at call-image (224 + 31 + 16)) = 41
	(copy/part at call-image (224 + 53 + 20 + 1) 4) = #{D2FFFFFF}
]["direct call encoding or names changed"]

context-source: [
	Red/System []
	qualified: context [
		helper: func [return: [integer!]][42]
		inside: func [return: [integer!]][helper]
	]
	main: func [return: [integer!]][qualified/inside]
]
context-ir: compiler-rsir-frontend/compile context-source 'glue
check binary? context-ir ["frontend rejected context calls: "
	mold compiler-rsir-frontend/last-error]
context-image: make binary! 4096
check (codegen-module context-ir context-image 0) = 0 "context codegen failed"
check all [
	(length? context-image) = 412
	(word-at context-image 8) = 4
	(word-at context-image 12) = 4
	(word-at context-image 24) = 67
	(word-at context-image 28) = 288
	(word-at context-image 32) = 105
	(word-at context-image 52) = 31
	(word-at context-image 88) = 53
	(word-at context-image 124) = 79
	(word-at context-image 160) = 0
	(word-at context-image 164) = 31
	(word-at context-image 212) = 23
	(word-at context-image (288 + 31 + 16)) = 42
	(copy/part at context-image (288 + 53 + 20 + 1) 4) = #{D2FFFFFF}
	(copy/part at context-image (288 + 79 + 20 + 1) 4) = #{CEFFFFFF}
]["context code layout or relative calls changed"]

parameter-source: [
	Red/System []
	node-handle!: alias integer!
	helper: func [value [node-handle!] return: [integer!]][value]
	main: func [return: [integer!]][helper 42]
]
parameter-ir: compiler-rsir-frontend/compile parameter-source 'glue
check binary? parameter-ir ["frontend rejected one-parameter call: "
	mold compiler-rsir-frontend/last-error]
parameter-image: make binary! 4096
check (codegen-module parameter-ir parameter-image 0) = 0
	"one-parameter codegen failed"
check all [
	(length? parameter-image) = 324
	(word-at parameter-image 8) = 3
	(word-at parameter-image 12) = 3
	(word-at parameter-image 20) = 1
	(word-at parameter-image 24) = 41
	(word-at parameter-image 28) = 224
	(word-at parameter-image 32) = 81
]["one-parameter image header changed"]
check all [
	(word-at parameter-image 44) = 0
	(word-at parameter-image 48) = 6
	(word-at parameter-image 52) = 31
	(word-at parameter-image 56) = 19
	(word-at parameter-image 80) = 6
	(word-at parameter-image 84) = 4
	(word-at parameter-image 88) = 50
	(word-at parameter-image 92) = 31
	(word-at parameter-image 116) = 10
	(word-at parameter-image 124) = 0
	(word-at parameter-image 128) = 31
	(word-at parameter-image 176) = 23
	(copy/part at parameter-image 181 41) =
		to binary! "helpermain***-mainkernel32.dllExitProcess"
]["one-parameter metadata changed"]
check all [
	(copy/part at parameter-image (224 + 31 + 15 + 1) 2) = #{89C8}
	(word-at parameter-image (224 + 50 + 20)) = 42
	(copy/part at parameter-image (224 + 50 + 25 + 1) 4) = #{D0FFFFFF}
]["one-parameter ABI encoding changed"]

forward-parameter-source: [
	Red/System []
	node-handle!: alias integer!
	identity: func [value [node-handle!] return: [integer!]][value]
	relay: func [value [node-handle!] return: [integer!]][identity value]
	main: func [return: [integer!]][relay 42]
]
forward-parameter-ir: compiler-rsir-frontend/compile
	forward-parameter-source 'glue
check binary? forward-parameter-ir ["frontend rejected parameter forwarding: "
	mold compiler-rsir-frontend/last-error]
forward-parameter-image: make binary! 4096
check (codegen-module forward-parameter-ir forward-parameter-image 0) = 0
	"parameter-forwarding codegen failed"
check all [
	(length? forward-parameter-image) = 396
	(word-at forward-parameter-image 8) = 4
	(word-at forward-parameter-image 12) = 4
	(word-at forward-parameter-image 24) = 48
	(word-at forward-parameter-image 28) = 272
	(word-at forward-parameter-image 32) = 107
	(word-at forward-parameter-image 52) = 31
	(word-at forward-parameter-image 88) = 50
	(word-at forward-parameter-image 124) = 76
	(word-at forward-parameter-image 160) = 0
	(word-at forward-parameter-image 164) = 31
	(word-at forward-parameter-image 212) = 23
]["parameter-forwarding metadata changed"]
check all [
	(copy/part at forward-parameter-image (272 + 31 + 15 + 1) 2) = #{89C8}
	(copy/part at forward-parameter-image (272 + 50 + 19 + 1) 5) = #{E8D5FFFFFF}
	(word-at forward-parameter-image (272 + 76 + 20)) = 42
	(copy/part at forward-parameter-image (272 + 76 + 25 + 1) 4) = #{C9FFFFFF}
]["parameter-forwarding ABI encoding changed"]

ir: first generate 'glue 'i32
small: make binary! 64
check (codegen-module ir small 0) = 4 "bounded output was accepted"
check empty? small "bounded-output failure committed bytes"

bad: copy ir
change/part bad int-to-bin/to-bin32 4 4
artifact: make binary! 4096
check (codegen-module bad artifact 0) = 2 "invalid RSIR kind was accepted"
check empty? artifact "invalid RSIR committed bytes"

artifact: make binary! 4096
check (codegen-module ir artifact 2) = 3 "unsupported opt level was accepted"
check empty? artifact "unsupported opt level committed bytes"

artifact: make binary! 4096
append artifact 1
before: copy artifact
check (codegen-module ir artifact 0) = 1 "nonempty output was accepted"
check artifact = before "invalid output mutation was not atomic"

print "PASS: compact RSIR -> native x64 codegen -> linker image"
