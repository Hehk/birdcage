app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst" }

import pf.Cmd

main! = |args| {
	check = if args.contains("--check") {
		["--check"]
	} else {
		[]
	}
	Cmd.call!(".tools/roc/roc", ["fmt"].concat(check).concat(["src", "platform", "scripts"]))?
	Cmd.call!("cargo", ["fmt", "--all", "--"].concat(check))
}
