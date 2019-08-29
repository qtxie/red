Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

probe "abc"

win: make gob! [size: 1000x1000 color: red]
?? win
;loop 10000 [append win make gob! compose [size: (random 100x100) offset: (random 1000x1000) alpha: (random 255) color: (random 255.255.255)]]

probe "fjdksafjldsjfklsdafj"
view win
probe "done"