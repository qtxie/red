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
scroll-face: none
calendar-face: none
canvas: none
rich-box: none
window: none
result: none
secondary: none
snapshot-file: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.png"]
][%macos-arm64-view-smoke.png]
unicode-text: rejoin ["View " to char! 937 " " to char! 19990 to char! 30028]
rich-box: make face! [
	type: 'rich-text
	text: unicode-text
	size: 160x40
	data: make block! 4
]

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
		left-align-face: text "ARM64" 120x24 white left
		center-align-face: text "ARM64" 120x24 white center
		right-align-face: text "ARM64" 120x24 white right
		styled-face: text "Styled" 120x24 white underline strike
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
do-actor clicker none 'click
unless click-count = 1 [fail "click actor was not dispatched"]

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

snapshot: to-image canvas
unless all [image? snapshot snapshot/size/x > 0 snapshot/size/y > 0][
	fail "to-image returned an invalid image"
]

corner: snapshot/(1x1)
center: snapshot/(as-pair (snapshot/size/x / 2) (snapshot/size/y / 2))
if corner = center [fail "Draw capture appears blank"]

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
