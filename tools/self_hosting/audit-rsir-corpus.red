Red [
	Title: "Audit loader-expanded Red/System corpus and direct frontend progress"
]

root: clean-path %../../
do append copy root %compiler/target-registry.red
do append copy root %compiler/system-job.red
do append copy root %compiler/lexer.red
do append copy root %compiler/system-source.red
do append copy root %compiler/system-loader.red
do append copy root %compiler/int-to-bin.red
do append copy root %compiler/rsir-frontend.red

current-corpus: append copy root %build/self-hosting/compact-hybrid-direct-stream.reds
source-file: either exists? current-corpus [current-corpus][
	append copy root %build/self-hosting/red-bootstrap-hybrid-thin.reds
]
if all [block? system/options/args not empty? system/options/args][
	source-file: clean-path to file! system/options/args/1
]
unless exists? source-file [
	print ["missing corpus:" source-file]
	quit/return 1
]

counts: make map! 64
types: make map! 128
controls: make map! 32
argument-counts: make map! 32
local-counts: make map! 64
return-types: make map! 32
control-words: [if either case switch while until loop repeat foreach forall return]
import-directive: to issue! "import"
enum-directive: to issue! "enum"
max-args: 0
max-locals: 0
max-context-depth: 0

inc: func [table [map!] key [string!] /local count][
	count: select table key
	put table key either count [count + 1][1]
]

note-type: func [type [block!]][
	inc types mold type
]

scan-spec: func [
	spec [block!]
	defined? [logic!]
	/local position item local? args locals
][
	args: 0
	locals: 0
	local?: false
	position: spec
	while [not tail? position][
		item: position/1
		case [
			refinement? item [
				inc counts "refinements"
				if item = /local [local?: true]
				position: next position
			]
			all [
				set-word? item
				item = to set-word! 'return
				not tail? next position
				block? position/2
			][
				inc counts "returns"
				note-type position/2
				if defined? [inc return-types mold position/2]
				position: skip position 2
			]
			all [
				any-word? item
				not tail? next position
				block? position/2
			][
				note-type position/2
				either local? [locals: locals + 1][args: args + 1]
				position: skip position 2
			]
			any-word? item [
				if local? [locals: locals + 1]
				position: next position
			]
			true [
				if block? item [inc counts "function-attributes"]
				position: next position
			]
		]
	]
	max-args: max max-args args
	max-locals: max max-locals locals
	if defined? [
		inc argument-counts form args
		inc local-counts form locals
	]
]

scan-imports: func [values [block!] /local position][
	position: values
	while [not tail? position][
		either all [
			set-word? position/1
			not tail? next position
			string? position/2
			not tail? skip position 2
			block? position/3
		][
			inc counts "import-symbols"
			scan-spec position/3 false
			position: skip position 3
		][
			if block? position/1 [scan-imports position/1]
			position: next position
		]
	]
]

walk: func [
	values [block!]
	function-depth [integer!]
	context-depth [integer!]
	/local position value
][
	max-context-depth: max max-context-depth context-depth
	position: values
	while [not tail? position][
		value: position/1
		case [
			all [
				set-word? value
				not tail? next position
				find [func function] position/2
				(length? position) >= 4
				block? position/3
				block? position/4
			][
				inc counts "functions"
				if function-depth > 0 [inc counts "nested-functions"]
				scan-spec position/3 true
				walk position/4 (function-depth + 1) context-depth
				position: skip position 4
			]
			all [
				set-word? value
				not tail? next position
				position/2 = 'context
				not tail? skip position 2
				block? position/3
			][
				inc counts "contexts"
				walk position/3 function-depth (context-depth + 1)
				position: skip position 3
			]
			all [
				value = 'with
				(length? position) >= 3
				block? position/3
			][
				inc counts "with-blocks"
				walk position/3 function-depth context-depth
				position: skip position 3
			]
			all [
				issue? value
				value = import-directive
				not tail? next position
				block? position/2
			][
				inc counts "import-blocks"
				scan-imports position/2
				position: skip position 2
			]
			all [
				set-word? value
				not tail? next position
				position/2 = 'alias
			][
				inc counts "aliases"
				position: next position
			]
			all [issue? value value = enum-directive][
				inc counts "enums"
				position: next position
			]
			all [set-word? value function-depth = 0][
				inc counts "global-sets"
				position: next position
			]
			block? value [
				walk value function-depth context-depth
				position: next position
			]
			any-word? value [
				if find control-words to word! value [inc controls form to word! value]
				position: next position
			]
			true [position: next position]
		]
	]
]

job: compiler-system-job/new 'Windows-X86-64
compiler-system-job/job-set job 'dev-mode? true
compiler-system-job/job-set job 'red-pass? true
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'unicode? true
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'opt-level 1

compiler-system-loader/job: job
compiler-system-loader/connect-compiler-state make block! 32 make block! 32
compiler-system-loader/init

started: now/time/precise
source-bytes: read/binary source-file
source: compiler-system-loader/process source-file
unless block? source [
	print [
		"could not expand corpus:" source-file
		mold compiler-system-loader/last-error
	]
	quit/return 1
]
walk source 0 0

print [
	"corpus" source-file
	"bytes" length? source-bytes
	"expand+scan" now/time/precise - started
]
foreach [name count] counts [print [name count]]
print ["max-args" max-args]
print ["max-locals" max-locals]
print ["max-context-depth" max-context-depth]
foreach [name count] controls [print ["control" name count]]
foreach [name count] argument-counts [print ["arguments" name count]]
foreach [name count] local-counts [print ["locals" name count]]
foreach [name count] return-types [print ["return" name count]]
foreach [name count] types [print ["type" name count]]

started: now/time/precise
ir: compiler-rsir-frontend/compile source 'glue
unless all [
	compiler-rsir-frontend/function-count = select counts "functions"
	compiler-rsir-frontend/import-count = select counts "import-symbols"
	((length? compiler-rsir-frontend/contexts) / 2) = select counts "contexts"
	((length? compiler-rsir-frontend/aliases) / 2) =
		((select counts "aliases") + select counts "enums")
][
	print [
		"FAIL: direct frontend declaration counts"
		compiler-rsir-frontend/function-count
		compiler-rsir-frontend/import-count
		((length? compiler-rsir-frontend/aliases) / 2)
		((length? compiler-rsir-frontend/contexts) / 2)
	]
	if compiler-rsir-frontend/last-error [
		print [
			"frontend error"
			compiler-rsir-frontend/last-error/code
			compiler-rsir-frontend/last-error/message
		]
	]
	quit/return 1
]
either binary? ir [
	print ["frontend complete" length? ir "bytes in" now/time/precise - started]
][
	print [
		"frontend stopped after"
		compiler-rsir-frontend/function-count "functions,"
		compiler-rsir-frontend/import-count "imports,"
		((length? compiler-rsir-frontend/aliases) / 2) "aliases,"
		((length? compiler-rsir-frontend/contexts) / 2) "contexts,"
		compiler-rsir-frontend/global-count "globals in"
		now/time/precise - started
	]
	print [
		"frontend error"
		compiler-rsir-frontend/last-error/code
		compiler-rsir-frontend/last-error/message
	]
]
