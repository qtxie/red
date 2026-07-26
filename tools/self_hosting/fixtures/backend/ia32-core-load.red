Red [Title: "Current IA-32 emitter Red load check"]

compiler-stub: context [
	throw-error: func [message][make error! form message]
	quit-on-error: does [quit/return 1]
]
system-dialect: context [compiler: compiler-stub]

#include %../../../../compiler/int-to-bin.red
#include %../../../../compiler/ieee-754.red
#include %../../../../compiler/virtual-struct.red
#include %../../../../system/emitter.red
#include %../../../../system/linker.red
#include %../../../../system/linker-static.red

job: object [target: 'IA-32 PIC?: false PIE?: false]
emitter/init false job

clear emitter/bits-buf
bitmap-offset: emitter/store-ptr-bitmap [1 1073741824 -2147483648]
bitmap-ok?: all [
	bitmap-offset = 0
	emitter/bits-buf = #{010000000000004000000080}
]

append emitter/data-buf #{01}
emitter/rodata?: false
emitter/pad-data-buf 4
data-ok?: emitter/data-buf = #{01000000}

append emitter/rodata-buf #{0102}
emitter/rodata?: true
emitter/pad-data-buf 4
rodata-ok?: all [
	emitter/rodata-buf = #{01020000}
	(emitter/tag-ref 4) = -4
]

link-job: object [sections: [data [0 #{00000000}]]]
linker/set-integer-at link-job 0 01020304h
linker-ok?: all [
	linker/target-64? 'ARM64
	not linker/target-64? 'IA-32
	virtual-struct/is? linker/line-record!
	link-job/sections/data/2 = #{04030201}
]

static-link-ok?: all [
	static-link/library? "sample.obj"
	static-link/archive? "sample.a"
	not static-link/library? "sample.dll"
	static-link/framework? "/System/Library/Thing.framework/Thing"
	(static-link/resolve-libname "sample" 'PE true) = "sample.lib"
	(static-link/resolve-libname "sample" 'ELF false) = "sample.so"
	(static-link/le32 01020304h) = #{04030201}
]

either all [
	emitter/target/target = 'IA-32
	emitter/target/ptr-size = 4
	virtual-struct/is? emitter/pointer
	bitmap-ok?
	data-ok?
	rodata-ok?
	linker-ok?
	static-link-ok?
][
	print "current IA-32 emitter Red load: OK"
quit/return 0
][
	print "current IA-32 emitter Red load: FAILED"
	quit/return 1
]
