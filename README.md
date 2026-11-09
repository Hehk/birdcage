# Birdcage

## Run

```sh
nix develop
just build
just run review feature --into main
just test
just fmt
just lint
```

`review` currently only parses the request in scripted fixture mode. It does not
inspect a repository. `file-demo <path>` is a development-only async I/O fixture;
unlike review, it writes the specified file.

`Cargo.toml` uses `platform/host.rs` as the Rust binary and Tokio for async I/O.
`just build` prepares the Roc archive and bindings, then runs Cargo.
The default executable is `target/debug/birdcage`. Run, test, and clean commands
respect Cargo's output directory, including `CARGO_TARGET_DIR`.

After that, normal `cargo build`, `cargo test`, and `cargo clippy` work for Rust.
Use `just build` after Roc changes. `just lint` checks Roc and runs Clippy;
`just fmt` formats both languages, leaving generated bindings alone.

Roc pins live in `scripts/setup.sh`. Changing them refreshes the installed tools
and invalidates the Roc build automatically.
