Red [
	Title: "Red compiler phase timing"
	File:  %phase-timer.red
]

phase-timer: context [
	active?: false
	started: make map! 16
	records: make block! 24

	reset: does [
		clear started
		clear records
	]

	begin: func [name [word! string!]][
		if active? [put started name now/precise/utc]
	]

	finish: func [
		name [word! string!]
		/local start-time duration record
	][
		unless active? [return none]
		unless start-time: select started name [
			make error! rejoin ["phase was not started: " mold name]
		]
		duration: difference now/precise/utc start-time
		record: find/skip records name 3
		unless record [
			repend records [name 0 0:0:0]
			record: skip tail records -3
		]
		record/2: record/2 + 1
		record/3: record/3 + duration
		remove/key started name
		duration
	]

	snapshot: does [copy/deep records]
]
