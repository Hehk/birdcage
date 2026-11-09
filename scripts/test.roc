app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst" }

import pf.Cmd

main! = |_args| {
	Cmd.call!(".tools/roc/roc", ["test", "src/main.roc"])?
	Cmd.call!("cargo", ["test", "--quiet"])?
	Ok({})
}
