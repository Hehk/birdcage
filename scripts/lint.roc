app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst" }

import pf.Cmd
import pf.Path

main! = |_args| {
	Cmd.call!(".tools/roc/roc", ["scripts/fmt.roc", "--check"])?
	Cmd.call!(".tools/roc/roc", ["check", "src/main.roc"])?
	for path in Path.list!("scripts")? {
		if path.display().ends_with(".roc") {
			Cmd.call!(".tools/roc/roc", ["check", Path.to_os_str(path)])?
		}
	}
	Cmd.call!("cargo", ["clippy", "--all-targets", "--", "-D", "warnings"])
}
