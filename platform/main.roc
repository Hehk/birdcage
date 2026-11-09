platform "birdcage"
	requires {
		main! : List(Str) => I32
	}
	exposes [File, Stderr, Stdout]
	packages {}
	provides {
		"roc_main": main_for_host!,
		"roc_read_completed": read_completed!,
		"roc_write_completed": write_completed!,
	}
	hosted {
		"roc_file_read": File.read!,
		"roc_file_write": File.write!,
		"roc_stderr_line": Stderr.line!,
		"roc_stdout_line": Stdout.line!,
	}
	targets: {
		x64glibc: {
			inputs: [app],
			output: Archive,
		},
	}

import Stdout
import Stderr
import File

main_for_host! : List(Str) => I32
main_for_host! = main!

read_completed! : Box(Try(Str, Str) => {}), Try(Str, Str) => {}
read_completed! = |callback, result| callback.unbox()(result)

write_completed! : Box(Try({}, Str) => {}), Try({}, Str) => {}
write_completed! = |callback, result| callback.unbox()(result)
