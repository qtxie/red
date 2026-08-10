Red [
	Title: "Red compiler phase timing"
	File:  %phase-timer.red
]

phase-timer: context [
	active?: false
	started: make map! 16
	records: make block! 48

	reset: does [
		clear started
		clear records
	]

	begin: func [name [word! string!] /local stack][
		if active? [
			stack: select started name
			either block? stack [
				append stack now/precise/utc
			][
				put started name reduce [now/precise/utc]
			]
		]
	]

	finish: func [
		name [word! string!]
		/local stack start-time duration record
	][
		unless active? [return none]
		unless all [stack: select started name not empty? stack][
			make error! rejoin ["phase was not started: " mold name]
		]
		start-time: take/last stack
		duration: difference now/precise/utc start-time
		record: find/skip records name 3
		unless record [
			repend records [name 0 0:0:0]
			record: skip tail records -3
		]
		record/2: record/2 + 1
		record/3: record/3 + duration
		duration
	]

	balanced?: does [
		foreach [name stack] started [
			unless empty? stack [return no]
		]
		yes
	]

	snapshot: does [copy/deep records]

	report: does [
		foreach [name count duration] records [
			print ["...profile phase   :" name "count:" count "time:" duration]
		]
	]
]
