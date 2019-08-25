Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

hello: bb: none

win: view/no-wait [
	hello: button "Hello" [print "ok"]
	bb: base white on-down [face/color: red]
]