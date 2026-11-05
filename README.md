# Birdcage

## Run

```sh
nix develop
just build
just run
just test
just fmt
just lint
```

`Cargo.toml` uses `platform/host.rs` as the Rust binary, with no third-party
crates. `just build` prepares the Roc archive and bindings, then runs Cargo.
The default executable is `target/debug/birdcage`. Run, test, and clean commands
respect Cargo's output directory, including `CARGO_TARGET_DIR`.

After that, normal `cargo build`, `cargo test`, and `cargo clippy` work for Rust.
Use `just build` after Roc changes. `just lint` checks Roc and runs Clippy;
`just fmt` formats both languages, leaving generated bindings alone.

Roc pins live in `scripts/setup.sh`. Changing them refreshes the installed tools
and invalidates the Roc build automatically.
