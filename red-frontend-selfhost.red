Red [
	Title: "Red self-hosting frontend"
	File:  %red-frontend-selfhost.red
]

compiler-root: system/options/path

#include %compiler/host-compat.red

#include %system/compiler-host.red
#include %compiler/sha256.red
#include %compiler/modules.red
#include %compiler/version.red
#include %compiler/int-to-bin.red
#include %compiler/ieee-754.red
#include %compiler/lexer.red
#include %compiler/preprocessor.red
#include %compiler/extractor.red
#include %compiler/redbin.red
#include %compiler/crush.red
#include %compiler/source-parity.red
#include %compiler/frontend.red

print-usage: does [
	print "Usage: red-frontend-selfhost --version | --check-source | --check-load | --check-redbin | --check-all"
]

check-source: has [root current port missing extra retired current-redbin port-redbin missing-redbin][
	root: system/options/path
	current: compiler-source-parity/inventory/legacy root/encapper/compiler.r 'red
	port: compiler-source-parity/inventory root/compiler/frontend.red 'red
	current-redbin: compiler-source-parity/inventory root/utils/redbin.r none
	port-redbin: compiler-source-parity/inventory
		root/compiler/redbin-emitter.red
		none
	missing: exclude copy current port
	extra: exclude copy port current
	retired: sort [
		date-special? encap-preprocess float-special? in-cache? map-value?
		money-value? percent-value? point-value? ref-value? tuple-value?
		type-value? unicode-char?
	]
	missing-redbin: exclude copy current-redbin port-redbin
	either all [
		missing = retired
		empty? extra
		empty? missing-redbin
	][
		print [
			"current Red frontend source: OK methods:" length? port
			"Redbin methods:" length? port-redbin
		]
		0
	][
		print [
			"current Red frontend source mismatch"
			"missing:" mold missing
			"extra:" mold extra
			"Redbin missing:" mold missing-redbin
		]
		1
	]
]

check-load: does [
	either all [
		object? compiler-frontend
		function? :compiler-frontend/compile
		same? compiler-frontend/redbin compiler-redbin-emitter
	][
		print ["current Red frontend load: OK fields:" length? words-of compiler-frontend]
		0
	][
		print "current Red frontend load: FAILED"
		1
	]
]

check-redbin: has [value payload decoded][
	value: [none true false 0 63 64 -1 1.5 "ASCII" "é" #{CAFE} #0- [2]]
	compiler-redbin-emitter/index: 0
	compiler-redbin-emitter/init
	compiler-redbin-emitter/emit-block value
	compiler-redbin-emitter/finish []
	payload: copy compiler-redbin-emitter/buffer
	decoded: compiler-redbin/decode payload
	either all [
		compiler-redbin/header? payload
		1 = compiler-redbin/version-of payload
		decoded = value
	][
		print ["current Red frontend Redbin: OK bytes:" length? payload]
		0
	][
		print [
			"current Red frontend Redbin mismatch:"
			mold payload
			mold decoded
		]
		1
	]
]

check-all: has [failures][
	failures: 0
	failures: failures + check-source
	failures: failures + check-load
	failures: failures + check-redbin
	failures
]

args: system/options/args
either empty? args [
	print-usage
	quit/return 2
][
	switch/default first args [
		"--version" [print compiler-version quit/return 0]
		"--check-source" [quit/return check-source]
		"--check-load" [quit/return check-load]
		"--check-redbin" [quit/return check-redbin]
		"--check-all" [quit/return check-all]
	][
		print-usage
		quit/return 2
	]
]
