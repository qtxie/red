Red [
	Title: "Minimal Red script host for the test workflows"
	File:  %red-console.red
	Purpose: {
		Runs one Red script, which is all the workflows need:

			red-console <runner.red>

		It is not the packaged CLI console. That one cannot be built here:
		environment/console/CLI/console.red asks for Needs: [JSON CSV View]
		with Config: [GUI-engine: 'terminal], and building the terminal
		backend's runtime fails in the RSIR frontend -- "unsupported
		expression [0]" right next to set-console-cursor, which lives in
		runtime/platform/win32-ansi.reds and in the terminal View backend.
		Reusing a prebuilt libRedRT instead fails with "undefined symbol:
		symbol", because that runtime was built for another GUI engine.

		CI needs a host that `do`es a runner and nothing else -- no REPL, no
		auto-completion, no help system -- so that is what this is. `do` of a
		file auto-expands #include and #macro, so a runner and everything it
		pulls in load exactly as they would under the console.
	}
]

args: system/options/args
if string? args [args: reduce [args]]

if any [none? args empty? args][
	print "Usage: red-console <script.red> [runner arguments]"
	quit/return 2
]

script: clean-path to-red-file args/1

;; A runner reads system/options/args as the list of sources to run, so the
;; script has to come back out of it or every runner silently runs nothing.
;; Anything after the script is passed straight through.
system/options/args: copy next args

;; The runners resolve the repo root from system/options/path. A console sets
;; that to the script's own directory; a compiled program leaves it at the
;; working directory, which would send every runner looking for the repo one
;; level above it. Point it at the script instead.
dir: copy script
clear find/last dir "/"
system/options/path: dirize dir

do script
