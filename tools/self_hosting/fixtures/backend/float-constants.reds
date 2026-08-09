Red/System [
	Title: "O2 floating-point constant coverage"
]

f64-literal: func [return: [float!]][1.5]

f64-negative-zero: func [return: [float!]][-0.0]

f64-literal-math: func [
	value [float!]
	return: [float!]
][
	value + 2.25
]

f32-literal: func [return: [float32!]][as float32! 1.5]

f32-literal-math: func [
	value [float32!]
	return: [float32!]
][
	value + as float32! 2.25
]

i32-to-f64: func [value [integer!] return: [float!]][as float! value]
i32-to-f32: func [value [integer!] return: [float32!]][as float32! value]
f64-to-i32: func [value [float!] return: [integer!]][as integer! value]
f32-to-i32: func [value [float32!] return: [integer!]][as integer! value]
f32-to-f64: func [value [float32!] return: [float!]][as float! value]
f64-to-f32: func [value [float!] return: [float32!]][as float32! value]
i32-bits-to-f32: func [value [integer!] return: [float32!]][as float32! keep value]
f32-bits-to-i32: func [value [float32!] return: [integer!]][as integer! keep value]

score: 0
if f64-literal = 1.5 [score: score + 1]
if (f64-literal-math 1.25) = 3.5 [score: score + 1]
if (1.0 / f64-negative-zero) = -1.#INF [score: score + 1]
if f32-literal = as float32! 1.5 [score: score + 1]
if (f32-literal-math as float32! 1.25) = as float32! 3.5 [score: score + 1]
if (i32-to-f64 -42) = -42.0 [score: score + 1]
if (i32-to-f32 123) = as float32! 123.0 [score: score + 1]
if (f64-to-i32 -3.75) = -3 [score: score + 1]
if (f32-to-i32 as float32! 123.8) = 123 [score: score + 1]
if (f32-to-f64 as float32! 1.25) = 1.25 [score: score + 1]
if (f64-to-f32 2.5) = as float32! 2.5 [score: score + 1]
if (i32-bits-to-f32 1069547520) = as float32! 1.5 [score: score + 1]
if (f32-bits-to-i32 as float32! 1.5) = 1069547520 [score: score + 1]
print-line score
