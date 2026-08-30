Red [
	Title: "Standalone toolchain View fixture"
	Needs: View
]

view/no-wait [
	title "Standalone Red toolchain"
	text "RED-TOOLCHAIN-VIEW-OK"
]

loop 20 [
	do-events/no-wait
	wait 0.01
]

unview/all
loop 20 [do-events/no-wait]
write %red-toolchain-view.ok "RED-TOOLCHAIN-VIEW-OK"
print "RED-TOOLCHAIN-VIEW-OK"
