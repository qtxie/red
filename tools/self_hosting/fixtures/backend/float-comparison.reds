Red/System [
	Title: "O2 scalar floating-point comparison coverage"
]

f64-equal?: func [a [float!] b [float!] return: [logic!]][a = b]
f64-not-equal?: func [a [float!] b [float!] return: [logic!]][a <> b]
f64-less?: func [a [float!] b [float!] return: [logic!]][a < b]
f64-greater?: func [a [float!] b [float!] return: [logic!]][a > b]
f64-less-or-equal?: func [a [float!] b [float!] return: [logic!]][a <= b]
f64-greater-or-equal?: func [a [float!] b [float!] return: [logic!]][a >= b]

f32-equal?: func [a [float32!] b [float32!] return: [logic!]][a = b]
f32-not-equal?: func [a [float32!] b [float32!] return: [logic!]][a <> b]
f32-less?: func [a [float32!] b [float32!] return: [logic!]][a < b]
f32-greater?: func [a [float32!] b [float32!] return: [logic!]][a > b]
f32-less-or-equal?: func [a [float32!] b [float32!] return: [logic!]][a <= b]
f32-greater-or-equal?: func [a [float32!] b [float32!] return: [logic!]][a >= b]

f64-branch-equal: func [
	a [float!] b [float!] return: [integer!] /local result
][
	result: 0
	if a = b [result: 1]
	result
]

f64-branch-not-equal: func [
	a [float!] b [float!] return: [integer!] /local result
][
	result: 0
	if a <> b [result: 1]
	result
]

f64-branch-less: func [
	a [float!] b [float!] return: [integer!] /local result
][
	result: 0
	if a < b [result: 1]
	result
]

f64-branch-greater: func [
	a [float!] b [float!] return: [integer!] /local result
][
	result: 0
	if a > b [result: 1]
	result
]

f64-branch-less-or-equal: func [
	a [float!] b [float!] return: [integer!] /local result
][
	result: 0
	if a <= b [result: 1]
	result
]

f64-branch-greater-or-equal: func [
	a [float!] b [float!] return: [integer!] /local result
][
	result: 0
	if a >= b [result: 1]
	result
]

f64-integer-equal: func [a [float!] b [float!] return: [integer!]][as integer! a = b]
f64-integer-not-equal: func [a [float!] b [float!] return: [integer!]][as integer! a <> b]
f64-integer-less: func [a [float!] b [float!] return: [integer!]][as integer! a < b]
f64-integer-greater: func [a [float!] b [float!] return: [integer!]][as integer! a > b]
f64-integer-less-or-equal: func [a [float!] b [float!] return: [integer!]][as integer! a <= b]
f64-integer-greater-or-equal: func [a [float!] b [float!] return: [integer!]][as integer! a >= b]

score: 0
nan64: 0.0 / 0.0
nan32: as float32! 0.0 / 0.0

if f64-equal? 1.0 1.0 [score: score + 1]
if f64-not-equal? 1.0 2.0 [score: score + 1]
if f64-less? 1.0 2.0 [score: score + 1]
if f64-greater? 2.0 1.0 [score: score + 1]
if f64-less-or-equal? 1.0 1.0 [score: score + 1]
if f64-greater-or-equal? 1.0 1.0 [score: score + 1]
unless f64-equal? nan64 nan64 [score: score + 1]
if f64-not-equal? nan64 nan64 [score: score + 1]
unless f64-less? nan64 1.0 [score: score + 1]
unless f64-greater? nan64 1.0 [score: score + 1]
unless f64-less-or-equal? nan64 1.0 [score: score + 1]
unless f64-greater-or-equal? nan64 1.0 [score: score + 1]

if f32-equal? as float32! 1.0 as float32! 1.0 [score: score + 1]
if f32-not-equal? as float32! 1.0 as float32! 2.0 [score: score + 1]
if f32-less? as float32! 1.0 as float32! 2.0 [score: score + 1]
if f32-greater? as float32! 2.0 as float32! 1.0 [score: score + 1]
if f32-less-or-equal? as float32! 1.0 as float32! 1.0 [score: score + 1]
if f32-greater-or-equal? as float32! 1.0 as float32! 1.0 [score: score + 1]
unless f32-equal? nan32 nan32 [score: score + 1]
if f32-not-equal? nan32 nan32 [score: score + 1]
unless f32-less? nan32 as float32! 1.0 [score: score + 1]
unless f32-greater? nan32 as float32! 1.0 [score: score + 1]
unless f32-less-or-equal? nan32 as float32! 1.0 [score: score + 1]
unless f32-greater-or-equal? nan32 as float32! 1.0 [score: score + 1]

score: score + f64-branch-equal 1.0 1.0
score: score + f64-branch-not-equal 1.0 2.0
score: score + f64-branch-less 1.0 2.0
score: score + f64-branch-greater 2.0 1.0
score: score + f64-branch-less-or-equal 1.0 1.0
score: score + f64-branch-greater-or-equal 1.0 1.0
score: score + (1 - f64-branch-equal nan64 nan64)
score: score + f64-branch-not-equal nan64 nan64
score: score + (1 - f64-branch-less nan64 1.0)
score: score + (1 - f64-branch-greater nan64 1.0)
score: score + (1 - f64-branch-less-or-equal nan64 1.0)
score: score + (1 - f64-branch-greater-or-equal nan64 1.0)

score: score + f64-integer-equal 1.0 1.0
score: score + f64-integer-not-equal 1.0 2.0
score: score + f64-integer-less 1.0 2.0
score: score + f64-integer-greater 2.0 1.0
score: score + f64-integer-less-or-equal 1.0 1.0
score: score + f64-integer-greater-or-equal 1.0 1.0
score: score + (1 - f64-integer-equal nan64 nan64)
score: score + f64-integer-not-equal nan64 nan64
score: score + (1 - f64-integer-less nan64 1.0)
score: score + (1 - f64-integer-greater nan64 1.0)
score: score + (1 - f64-integer-less-or-equal nan64 1.0)
score: score + (1 - f64-integer-greater-or-equal nan64 1.0)

print-line score
