Red [
	Title: "Self-hosted IEEE-754 packing test"
	File:  %ieee-754-test.red
]

#include %../../compiler/int-to-bin.red
#include %../../compiler/ieee-754.red

cases: [
	0.0					#{0000000000000000}
	-0.0				#{8000000000000000}
	1.0					#{3FF0000000000000}
	-1.0				#{BFF0000000000000}
	0.5					#{3FE0000000000000}
	1.5					#{3FF8000000000000}
	12345.6789			#{40C81CD6E631F8A1}
	4.94065645841247E-324	#{0000000000000001}
	1.7976931348623157e308	#{7FEFFFFFFFFFFFFF}
	-1.7976931348623157e308	#{FFEFFFFFFFFFFFFF}
	1.#INF				#{7FF0000000000000}
	-1.#INF				#{FFF0000000000000}
]

failed: 0
foreach [value expected] cases [
	actual: ieee-754/to-binary64 value
	unless actual = expected [
		failed: failed + 1
		print [
			"FAIL IEEE-754 packing:" mold value mold actual
			"expected" mold expected
		]
	]
]

if positive? failed [quit/return 1]
print ["PASS IEEE-754 packing:" (length? cases) / 2 "values"]
