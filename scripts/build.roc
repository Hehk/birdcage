app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst" }

import pf.Cmd
import pf.Path
import pf.Stdout

main! = |_args| {
	Path.create_all!("build")?
	common = [Path.utf8("scripts/build.roc"), ".tools/roc/roc", ".tools/roc/pins"]
	platform_sources = sources!("platform")?

	if stale!("build/roc_platform_abi.rs", common.concat(platform_sources).append(".tools/roc/RustGlue.roc"))? {
		Stdout.line!("Generating Rust bindings")?
		Cmd.call!(".tools/roc/roc", ["glue", ".tools/roc/RustGlue.roc", "build/glue", "platform/main.roc"])?
		Path.rename!("build/glue/roc_platform_abi.rs", "build/roc_platform_abi.rs")?
	}

	if stale!("build/libapp.a", common.concat(platform_sources).concat(sources!("src")?))? {
		Stdout.line!("Compiling Roc")?
		Cmd.call!(".tools/roc/roc", ["build", "--opt=dev", "--target=x64glibc", "--output=build/libapp.next.a", "src/main.roc"])?
		Path.rename!("build/libapp.next.a", "build/libapp.a")?
	}

	Cmd.call!("cargo", ["build", "--quiet"])
}

stale! = |output, inputs| {
	if !Path.exists!(output)? {
		return Ok(True)
	}
	modified = Path.time_modified!(output)?
	for input in inputs {
		if Path.time_modified!(input)? > modified {
			return Ok(True)
		}
	}
	Ok(False)
}

sources! = |directory| {
	var $sources = [directory]
	for path in Path.list!(directory)? {
		name = Path.filename(path)?.display()
		if !name.starts_with(".") {
			if Path.is_dir!(path)? {
				$sources = $sources.concat(sources!(path)?)
			} else if name.ends_with(".roc") {
				$sources = $sources.append(path)
			}
		}
	}
	Ok($sources)
}
