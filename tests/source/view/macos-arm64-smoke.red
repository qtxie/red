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
canvas: none
window: none
result: none
secondary: none
unicode-text: rejoin ["View " to char! 937 " " to char! 19990 to char! 30028]

result: try/all [
	window: view/no-wait/options [
		title "Red Apple Silicon View smoke"
		on-created [create-count: create-count + 1]
		below
		text "Native controls" font-size 16
		across
		clicker: button "Dispatch" 100x28 [click-count: click-count + 1]
		field-face: field "initial" 150x28
		check-face: check "Enabled"
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
		canvas: base 180x120 white draw [
			pen red
			line 5x5 175x115
			fill-pen blue
			box 30x20 150x100 6
			fill-pen yellow
			circle 90x60 22
		]
		unicode-face: text "" 260x24
		area-face: area "" 260x60
	][
		menu: [
			"File" [
				"Smoke item" smoke-item
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
