use std::env;
use std::path::PathBuf;

fn main() {
    let build = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap()).join("build");
    for name in ["libapp.a", "roc_platform_abi.rs"] {
        let path = build.join(name);
        println!("cargo:rerun-if-changed={}", path.display());
        assert!(path.is_file(), "Missing {name}; run `just build` first");
    }
    println!("cargo:rustc-link-search=native={}", build.display());
    println!("cargo:rustc-link-lib=static=app");
}
