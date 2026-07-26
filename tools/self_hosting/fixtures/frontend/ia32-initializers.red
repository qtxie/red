Red [
	Title: "IA-32 target initializer probe"
]

target: context [
	target: little-endian?: struct-align: ptr-size: void-ptr: none
	default-align: stack-width: stack-slot-max:
	branch-offset-size: locals-offset: def-locals-offset: none

	emit-casting: emit-call-syscall: emit-call-import:
	emit-call-native: emit-not: emit-push: emit-pop: none

	divide-sym: first [/]
	left-shift-sym: first [<<]
	right-shift-sym: first [>>]
	unsigned-right-shift-sym: first [-**]

	math-op: compose [+ - * / // (to word! first [%])]
]

print [
	mold target/divide-sym
	mold target/left-shift-sym
	mold target/right-shift-sym
	mold target/unsigned-right-shift-sym
	mold target/math-op
]

foreach source ["/" "<<" ">>" "-**" "%"] [
	value: transcode/one source
	print [mold source type? :value mold :value]
]
