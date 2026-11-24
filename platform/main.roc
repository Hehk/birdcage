platform "birdcage"
	requires {
		main! : List(Str) => I32
	}
	exposes [Env, File, Host, Http, Random, Stderr, Stdout]
	packages {}
	provides {
		"roc_deferred": deferred!,
		"roc_main": main_for_host!,
	}
	hosted {
		"roc_defer": Host.defer!,
		"roc_env_var": Env.var!,
		"roc_exit_code": Host.exit_code!,
		"roc_file_read": File.read!,
		"roc_file_write": File.write!,
		"roc_http_send": Http.send!,
		"roc_random_bytes": Random.bytes!,
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
import Env
import Host
import Http
import Random

main_for_host! : List(Str) => I32
main_for_host! = main!

deferred! : Box(() => {}) => {}
deferred! = |callback| callback.unbox()()
