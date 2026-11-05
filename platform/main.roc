platform "birdcage"
	requires {
		main! : () => I32
	}
	exposes [Stdout]
	packages {}
	provides { "roc_main": main_for_host! }
	hosted { "roc_stdout_line": Stdout.line! }
	targets: {
		x64glibc: {
			inputs: [app],
			output: Archive,
		},
	}

import Stdout

main_for_host! : () => I32
main_for_host! = main!
