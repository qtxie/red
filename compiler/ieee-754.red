Red [
	Title:   "Red/System IEEE-754 library"
	Author:  "Nenad Rakocevic"
	File:    %ieee-754.red
	Tabs:    4
	Rights:  "Copyright (C) 2000-2011-2015 Eric Long, -2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

; Based on the Red port from commit 688f2bdc. Red now exposes canonical
; big-endian binary64 conversion, so only binary32 still needs manual packing.
ieee-754: context [
	special32: [
		#INF	#{7F800000}
		#INF-	#{FF800000}
		#NaN	#{7FC00000}
		#0-		#{80000000}
	]
	special64: [
		#INF	#{7FF0000000000000}
		#INF-	#{FFF0000000000000}
		#NaN	#{7FF8000000000000}
		#0-		#{8000000000000000}
	]

	split32: func [
		"Returns the sign, exponent, and fraction of a single-precision value"
		n [number!]
		/local sign exponent fraction
	][
		sign: either negative? n [n: negate n 1][0]

		either zero? n [
			exponent: fraction: 0
		][
			either zero? (128 - exponent: to integer! log-2 n) [
				exponent: 127
			][
				if positive? ((2 ** exponent) - n) [exponent: exponent - 1]
			]
			fraction: n / (2 ** exponent)

			either positive? exponent: exponent + 127 [
				fraction: (fraction - 1) * (2 ** 23)
			][
				fraction: (2 ** (22 + exponent)) * fraction
				exponent: 0
			]
			fraction: to integer! fraction + 0.5
			if fraction = 8388608 [
				fraction: 0
				exponent: exponent + 1
			]
		]
		reduce [sign exponent fraction]
	]

	to-binary32: func [
		value [number! issue!]
		/rev
		/local out sign exponent fraction
	][
		out: case [
			issue? value [copy select special32 value]
			NaN? value [copy select special32 #NaN]
			same? value 1.#INF [copy select special32 #INF]
			same? value -1.#INF [copy select special32 #INF-]
			same? value -0.0 [copy select special32 #0-]
			true [
				set [sign exponent fraction] split32 value
				rejoin [
					int-to-bin/to-bin8 to integer! ((128 * sign) + (exponent / 2))
					int-to-bin/to-bin8 (
						to integer! (
							(128 * (exponent and 1)) +
							(shift/logical fraction 16)
						)
					)
					int-to-bin/to-bin8 to integer! (shift/logical fraction 8)
					int-to-bin/to-bin8 to integer! fraction
				]
			]
		]
		either rev [reverse copy out][out]
	]

	to-binary64: func [
		value [number! issue!]
		/rev
		/rev4
		/split
		/local out
	][
		out: either issue? value [
			copy select special64 value
	][
			to binary! to float! value
		]
		case [
			rev [reverse copy out]
			rev4 [
				out: reverse out
				append out copy/part out 4
				copy skip out 4
			]
			split [
				reduce [
					to integer! copy/part out 4
					to integer! skip out 4
				]
			]
			true [out]
		]
	]
]
