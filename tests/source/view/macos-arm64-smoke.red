Red [
	Title: "macOS ARM64 native View smoke test"
	Needs: View
]

output-dir: get-env "RED_VIEW_TEST_OUTPUT_DIR"
marker: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.ok"]
][%macos-arm64-view-smoke.ok]
error-file: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.error"]
][%macos-arm64-view-smoke.error]
if exists? marker [delete marker]
if exists? error-file [delete error-file]

fail: func [message [string!]][
	print rejoin ["MACOS-ARM64-VIEW-ERROR: " message]
	write error-file message
	unview/all
	quit/return 1
]

unless system/platform = 'macOS [fail "wrong platform"]
unless all [block? system/view/screens not empty? system/view/screens][
	fail "no screens discovered"
]

screen-face: first system/view/screens
unless all [
	pair? screen-face/size
	screen-face/size/x > 0
	screen-face/size/y > 0
	block? screen-face/state
	handle? screen-face/state/1
][fail "invalid screen face"]

click-count: 0
create-count: 0
time-count: 0
timer-face: none
clicker: none
field-face: none
empty-field-face: none
area-face: none
unicode-face: none
check-face: none
slider-face: none
progress-face: none
drop-face: none
list-face: none
tabs-face: none
left-align-face: none
center-align-face: none
right-align-face: none
styled-face: none
top-align-face: none
middle-align-face: none
bottom-align-face: none
multiline-align-face: none
button-align-panel: none
button-top-left: none
button-middle-center: none
button-bottom-right: none
scroll-face: none
calendar-face: none
canvas: none
base-text-face: none
image-text-face: none
radio-on: none
radio-off: none
radio-result: none
rich-box: none
console-font: none
console-metrics-box: none
console-metrics: none
window: none
result: none
secondary: none
snapshot-file: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.png"]
][%macos-arm64-view-smoke.png]
unicode-text: rejoin ["View " to char! 937 " " to char! 19990 to char! 30028]
image-background: make image! [160x44 230.235.240]
rich-box: make face! [
	type: 'rich-text
	text: unicode-text
	size: 160x40
	data: make block! 4
]
console-font: make font! [
	name: system/view/fonts/fixed
	size: 11
]
console-metrics-box: make face! [
	type: 'rich-text
	tabs: none
	line-spacing: none
	handles: none
]
console-metrics-box/font: console-font
console-metrics-box/text: "XXXXXXXXXX"

result: try/all [
	window: view/no-wait/options [
		title "Red Apple Silicon View smoke"
		on-created [create-count: create-count + 1]
		below
		timer-face: text "Native controls" font-size 16 rate 20
		on-time [time-count: time-count + 1 face/rate: none]
		across
		clicker: button "Dispatch" 100x28 [click-count: click-count + 1]
		field-face: field "initial" 150x28
		empty-field-face: field 150x28
		check-face: check "Enabled" tri-state
		return
		slider-face: slider 35% 150x24
		progress-face: progress 45% 150x18
		drop-face: drop-list 130x26 data ["One" "Two" "Three"] select 1
		return
		list-face: text-list 170x90 data ["Alpha" "Beta" "Gamma"] select 1
		tabs-face: tab-panel 240x90 [
			"First" [text "First tab"]
			"Second" [base 80x30 230.240.250]
		]
		return
		canvas: base 180x120 white cursor hand draw [
			pen red
			line 5x5 175x115
			fill-pen blue
			box 30x20 150x100 6
			fill-pen yellow
			circle 90x60 22
		]
		unicode-face: text "" 260x24
		area-face: area "" 260x60
		return
		left-align-face: text "ARM64" 120x24 white left font-color black
		center-align-face: text "ARM64" 120x24 white center font-color black
		right-align-face: text "ARM64" 120x24 white right font-color black
		styled-face: text "Styled" 120x24 white underline strike
		return
		top-align-face: text "Vertical" 100x64 white left top font-color black
		middle-align-face: text "Vertical" 100x64 white left middle font-color black
		bottom-align-face: text "Vertical" 100x64 white left bottom font-color black
		multiline-align-face: base "Line one^/Line two" 100x64 white left top font-color black
		return
		button-align-panel: panel 340x90 [
			across
			button-top-left: button "X" 100x70 left top
			button-middle-center: button "X" 100x70 center middle
			button-bottom-right: button "X" 100x70 right bottom
		]
		return
		base-text-face: base "Base text" 160x44 white font-color black
		image-text-face: image image-background "Image text" 160x44 font-color black
		return
		radio-on: radio "on" [radio-result/text: "on"]
		radio-off: radio "off" [radio-result/text: "off"]
		radio-result: field 170 "????"
		return
		scroll-face: base 140x60 white scrollable draw [
			pen blue
			line 4x4 136x56
		]
		calendar-face: calendar 160x80
	][
		menu: [
			"File" [
				"Smoke item" smoke-item
				"Untagged item"
			]
		]
	]
]
if error? result [fail mold result]

repeat count 20 [
	do-events/no-wait
	wait 0.01
]

unless create-count = 1 [fail "on-created actor was not dispatched"]
unless time-count = 1 [fail "native time actor was not dispatched"]
unless string? empty-field-face/text [fail "empty field text was not initialized"]
do-actor clicker none 'click
unless click-count = 1 [fail "click actor was not dispatched"]

radio-on/data: on
show radio-on
do-actor radio-on none 'change
unless all [radio-on/data radio-result/text = "on"][
	fail "radio selection did not dispatch its change actor"
]

field-face/text: "updated"
unicode-face/text: unicode-text
area-face/text: unicode-text
check-face/data: true
slider-face/data: 70%
progress-face/data: 80%
list-face/selected: 2
drop-face/selected: 2
tabs-face/selected: 2
show [
	field-face unicode-face area-face check-face slider-face progress-face
	list-face drop-face tabs-face
]

repeat count 20 [
	do-events/no-wait
	wait 0.01
]

unless all [
	field-face/text = "updated"
	unicode-face/text = unicode-text
	area-face/text = unicode-text
	check-face/data = true
	list-face/selected = 2
	drop-face/selected = 2
	tabs-face/selected = 2
][fail "native facet update failed"]

unless all [block? window/menu not empty? window/menu][fail "native menu was not created"]

append canvas/draw reduce ['pen black 'text 4x4 rich-box]
show canvas
repeat count 10 [do-events/no-wait wait 0.01]

caret-before-end: caret-to-offset rich-box (length? rich-box/text)
caret-at-end: caret-to-offset rich-box (1 + (length? rich-box/text))
unless all [
	point2D? caret-before-end
	point2D? caret-at-end
	caret-before-end/x < caret-at-end/x
	caret-before-end/y = caret-at-end/y
][fail "caret moved to a different line before end of text"]

console-metrics: size-text console-metrics-box
unless all [
	point2D? console-metrics
	console-metrics/x > 40.0
	console-metrics/y > 0.0
	console-metrics/x > (console-metrics/y * 3.0)
][fail rejoin ["unconstrained rich-text measurement wrapped: " mold console-metrics]]

measured: size-text/with unicode-face unicode-text
unless all [point2D? measured measured/x > 0.0 measured/y > 0.0][
	fail "Unicode text measurement failed"
]

target-size: window/size + 20x20
window/size: target-size
show window
repeat count 20 [do-events/no-wait wait 0.01]
unless window/size = target-size [
	fail rejoin [
		"native window resize failed: target=" mold target-size
		" actual=" mold window/size
	]
]

button-dark-bounds: func [
	image [image!]
	face [object!]
	parent [object!]
	/local scale-x scale-y margin-x margin-y left top right bottom min-x min-y max-x max-y xy pixel
][
	scale-x: image/size/x / parent/size/x
	scale-y: image/size/y / parent/size/y
	margin-x: to integer! (10 * scale-x)
	margin-y: to integer! (10 * scale-y)
	left: to integer! (face/offset/x * scale-x)
	top: to integer! (face/offset/y * scale-y)
	right: left + to integer! (face/size/x * scale-x)
	bottom: top + to integer! (face/size/y * scale-y)
	min-x: right
	min-y: bottom
	max-x: left
	max-y: top
	repeat y image/size/y [
		repeat x image/size/x [
			if all [
				x > (left + margin-x) x < (right - margin-x)
				y > (top + margin-y) y < (bottom - margin-y)
			][
				xy: as-pair x y
				pixel: image/:xy
				if all [pixel/1 < 64 pixel/2 < 64 pixel/3 < 64][
					min-x: min min-x x
					min-y: min min-y y
					max-x: max max-x x
					max-y: max max-y y
				]
			]
		]
	]
	reduce [min-x - left min-y - top max-x - left max-y - top]
]

show button-align-panel
repeat count 5 [do-events/no-wait wait 0.01]
button-image: to-image button-align-panel
button-top-left-bounds: button-dark-bounds button-image button-top-left button-align-panel
button-middle-center-bounds: button-dark-bounds button-image button-middle-center button-align-panel
button-bottom-right-bounds: button-dark-bounds button-image button-bottom-right button-align-panel
unless all [
	button-top-left-bounds/1 < button-middle-center-bounds/1
	button-middle-center-bounds/1 < button-bottom-right-bounds/1
	button-top-left-bounds/2 < button-middle-center-bounds/2
	button-middle-center-bounds/2 < button-bottom-right-bounds/2
][
	fail rejoin [
		"button alignment bounds are invalid: "
		mold reduce [
			button-top-left-bounds
			button-middle-center-bounds
			button-bottom-right-bounds
		]
	]
]

snapshot: to-image canvas
unless all [image? snapshot snapshot/size/x > 0 snapshot/size/y > 0][
	fail "to-image returned an invalid image"
]

corner: snapshot/(1x1)
center: snapshot/(as-pair (snapshot/size/x / 2) (snapshot/size/y / 2))
if corner = center [fail "Draw capture appears blank"]

text-visible?: func [face [object!] /local image background changed xy x y][
	image: to-image face
	background: image/(1x1)
	changed: 0
	repeat y image/size/y [
		repeat x image/size/x [
			xy: as-pair x y
			if image/:xy <> background [changed: changed + 1]
		]
	]
	changed > 10
]
unless text-visible? base-text-face [fail "base face text was not rendered"]
unless text-visible? image-text-face [fail "image face text was not rendered"]

dark-text-bounds: function [face [object!] /local image min-y max-y xy pixel][
	image: to-image face
	min-y: image/size/y
	max-y: 0
	repeat y image/size/y [
		repeat x image/size/x [
			xy: as-pair x y
			pixel: image/:xy
			if all [pixel/1 < 128 pixel/2 < 128 pixel/3 < 128][
				min-y: min min-y y
				max-y: max max-y y
			]
		]
	]
	reduce [min-y max-y]
]

top-bounds: dark-text-bounds top-align-face
middle-bounds: dark-text-bounds middle-align-face
bottom-bounds: dark-text-bounds bottom-align-face
multiline-bounds: dark-text-bounds multiline-align-face
unless all [
	top-bounds/1 < middle-bounds/1
	middle-bounds/1 < bottom-bounds/1
	(multiline-bounds/2 - multiline-bounds/1) > (top-bounds/2 - top-bounds/1)
][
	fail rejoin [
		"text alignment bounds are invalid: "
		mold reduce [top-bounds middle-bounds bottom-bounds multiline-bounds]
	]
]

if system/build/date/year = 1970 [fail "compiler build date is still the Unix epoch"]

if exists? snapshot-file [delete snapshot-file]
save/as snapshot-file snapshot 'png
unless all [exists? snapshot-file not empty? read/binary snapshot-file][
	fail "PNG encoding produced no data"
]
delete snapshot-file

repeat count 5 [
	secondary: view/no-wait [
		title "Red Apple Silicon window stress"
		base 48x32 20.80.140
	]
	repeat event-count 5 [do-events/no-wait wait 0.01]
	unless all [block? secondary/state handle? secondary/state/1][
		fail "secondary window has no native handle"
	]
	unview/only secondary
	repeat event-count 5 [do-events/no-wait wait 0.01]
	secondary: none
	recycle
]

unview/all
repeat count 20 [do-events/no-wait]

write marker "MACOS-ARM64-VIEW-OK"
print "MACOS-ARM64-VIEW-OK"
