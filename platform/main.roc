platform "birdcage"
	requires {
		main! : List(Str) => I32
	}
	exposes [File, Host, Stderr, Stdout]
	packages {}
	provides {
		"roc_deferred": deferred!,
		"roc_main": main_for_host!,
		"roc_read_completed": read_completed!,
		"roc_write_completed": write_completed!,
	}
	hosted {
		"roc_defer": Host.defer!,
		"roc_exit_code": Host.exit_code!,
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
import Host

main_for_host! : List(Str) => I32
main_for_host! = main!

deferred! : Box(() => {}) => {}
deferred! = |callback| callback.unbox()()

read_completed! : Box(Try(Str, Str) => {}), Try(Str, Str) => {}
read_completed! = |callback, result| callback.unbox()(result)

write_completed! : Box(Try({}, Str) => {}), Try({}, Str) => {}
write_completed! = |callback, result| callback.unbox()(result)
