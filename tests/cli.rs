use std::process::{Command, Output};

fn birdcage(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_birdcage"))
        .args(args)
        .output()
        .unwrap()
}

#[test]
fn review_arguments_reach_roc_intact() {
    let source = "feature/🦜 long enough to require a heap string".repeat(4);
    let result = birdcage(&["review", &source, "--into", "main"]);
    assert!(result.status.success(), "{result:?}");
    let output = String::from_utf8(result.stdout).unwrap();
    assert!(output.starts_with(&format!(
        "Scripted fixture mode; no repository inspection.\nModel request: {source} into main\n"
    )));
    assert!(output.ends_with("Scripted review report (1 findings)\n[high] src/auth.roc:2 The fixture authorizes every caller.\nEvidence: authorize = |_user| True\n"));
    assert_eq!(output.matches("Model request:").count(), 1);
    assert!(result.stderr.is_empty());
}

#[test]
fn invalid_commands_fail_without_starting_work() {
    for args in [
        vec![],
        vec!["unknown"],
        vec!["review", "feature", "--into"],
        vec!["review", "feature", "--into", ""],
        vec!["review", "--bad", "--into", "main"],
        vec!["review", "feature", "--into", "main", "extra"],
    ] {
        let result = birdcage(&args);
        assert_eq!(result.status.code(), Some(2), "{args:?}: {result:?}");
        assert!(result.stdout.is_empty());
        assert!(String::from_utf8(result.stderr).unwrap().contains("Usage:"));
    }
}

#[test]
fn invalid_utf8_is_rejected_without_lossy_conversion() {
    use std::os::unix::ffi::OsStringExt;
    let result = Command::new(env!("CARGO_BIN_EXE_birdcage"))
        .arg(std::ffi::OsString::from_vec(vec![0xff]))
        .output()
        .unwrap();
    assert_eq!(result.status.code(), Some(2));
    assert_eq!(result.stderr, b"Arguments must be valid UTF-8\n");
}

#[test]
fn asynchronous_file_fixture_preserves_heap_captures() {
    let path =
        std::env::temp_dir().join(format!("birdcage-file-fixture-{}.txt", std::process::id()));
    let result = birdcage(&["file-demo", path.to_str().unwrap()]);
    assert!(result.status.success(), "{result:?}");
    assert_eq!(
        result.stdout,
        b"File I/O submitted\nFile round-trip verified\n"
    );
    assert_eq!(
        std::fs::read_to_string(&path).unwrap(),
        "Async Roc → Rust → Roc 🦜\n".repeat(16)
    );
    std::fs::remove_file(path).unwrap();
}
