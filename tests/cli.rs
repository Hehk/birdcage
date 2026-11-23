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
    let result = birdcage(&[
        "review",
        &source,
        "--into",
        "main",
        "--script",
        "single-read",
    ]);
    assert!(result.status.success(), "{result:?}");
    let output = String::from_utf8(result.stdout).unwrap();
    assert!(output.starts_with(&format!(
        "Scripted fixture mode; no repository inspection.\nModel request: {source} into main\n"
    )));
    assert!(output.ends_with("Scripted review report (1 findings)\n[high] src/auth.roc:1 The fixture authorizes every caller.\nEvidence: authorize = |_user| True\n"));
    assert_eq!(output.matches("Model request:").count(), 2);
    let tool_start = output
        .find("Tool request: read-auth read_file src/auth.roc")
        .unwrap();
    let tool_end = output.find("Tool result:").unwrap();
    let next_model = output.rfind("Model request:").unwrap();
    assert!(tool_start < tool_end && tool_end < next_model);
    assert!(output[next_model..].contains("ToolResult"));
    assert!(output[next_model..].contains("read-auth"));
    assert!(output[next_model..].contains("authorize = |_user| True"));
    assert!(result.stderr.is_empty());
}

#[test]
fn model_scripts_choose_different_multi_round_investigations() {
    for (script, tools) in [
        (
            "diff-first",
            vec![
                "diff git_diff",
                "list-src list_files src",
                "search-auth search authorize",
                "read-auth read_file src/auth.roc",
            ],
        ),
        (
            "search-first",
            vec![
                "search-auth search authorize",
                "read-auth read_file src/auth.roc",
                "diff git_diff",
            ],
        ),
        ("final", vec![]),
    ] {
        let result = birdcage(&["review", "feature", "--into", "main", "--script", script]);
        assert!(result.status.success(), "{script}: {result:?}");
        let output = String::from_utf8(result.stdout).unwrap();
        let actual: Vec<_> = output
            .lines()
            .filter_map(|line| line.strip_prefix("Tool request: "))
            .collect();
        assert_eq!(actual, tools);
        assert_eq!(output.matches("Model request:").count(), tools.len() + 1);
        assert_eq!(output.matches("Tool result:").count(), tools.len());
        assert_eq!(output.matches("Scripted review report").count(), 1);
        assert!(result.stderr.is_empty());
    }
}

#[test]
fn a_batch_runs_one_tool_at_a_time_before_requesting_the_model() {
    let result = birdcage(&["review", "feature", "--into", "main", "--script", "batch"]);
    assert!(result.status.success(), "{result:?}");
    let output = String::from_utf8(result.stdout).unwrap();
    let events: Vec<_> = output
        .lines()
        .filter_map(|line| {
            if line.starts_with("Model request:") {
                Some("model")
            } else if line.starts_with("Tool request:") {
                Some("start")
            } else if line.starts_with("Tool result:") {
                Some("finish")
            } else {
                None
            }
        })
        .collect();
    assert_eq!(
        events,
        [
            "model", "start", "finish", "start", "finish", "start", "finish", "start", "finish",
            "model"
        ]
    );
    let next_request = &output[output.rfind("Model request:").unwrap()..];
    assert_eq!(next_request.matches("ToolResult(").count(), 4);
    for id in ["diff", "list-src", "search-auth", "read-auth"] {
        assert_eq!(
            next_request
                .matches(&format!("ToolResult({{ id: \"{id}\""))
                .count(),
            1
        );
    }
    assert!(output.contains("Scripted review report (1 findings)"));
    assert!(result.stderr.is_empty());
}

#[test]
fn invalid_tools_and_read_failures_return_to_the_model_without_writes() {
    let directory =
        std::env::temp_dir().join(format!("birdcage-tool-errors-{}", std::process::id()));
    std::fs::create_dir(&directory).unwrap();
    let result = Command::new(env!("CARGO_BIN_EXE_birdcage"))
        .args([
            "review",
            "feature",
            "--into",
            "main",
            "--script",
            "tool-errors",
        ])
        .current_dir(&directory)
        .output()
        .unwrap();
    let files: Vec<_> = std::fs::read_dir(&directory).unwrap().collect();
    std::fs::remove_dir_all(directory).unwrap();
    assert!(files.is_empty(), "A scripted review wrote files");
    assert!(result.status.success(), "{result:?}");
    let output = String::from_utf8(result.stdout).unwrap();
    let dispatched: Vec<_> = output
        .lines()
        .filter_map(|line| line.strip_prefix("Tool request: "))
        .collect();
    assert_eq!(
        dispatched,
        [
            "missing read_file missing.roc",
            "read-auth read_file src/auth.roc"
        ]
    );
    assert_eq!(output.matches("Model request:").count(), 3);
    let final_request = &output[output.rfind("Model request:").unwrap()..];
    assert_eq!(final_request.matches("ToolResult(").count(), 5);
    for error in [
        "Unknown tool: shell",
        "read_file expects exactly one path argument",
        "Expected a normalized relative path",
        "Fixture file not found: missing.roc",
    ] {
        assert!(
            final_request.contains(error),
            "Missing model-visible error: {error}"
        );
    }
    assert!(output.contains("Scripted review report (1 findings)"));
    assert!(result.stderr.is_empty());
}

#[test]
fn protocol_and_model_failures_exit_nonzero_without_a_report() {
    for (script, error, dispatches) in [
        ("duplicate-ids", "Model reused tool-call ID: read-auth", 0),
        ("reused-id", "Model reused tool-call ID: read-auth", 1),
        ("empty-id", "Model returned an empty tool-call ID", 0),
        ("empty-calls", "Model returned an empty tool-call batch", 0),
        ("wrong-result-id", "Tool result has the wrong call ID", 1),
        (
            "invalid-report",
            "A finding needs an explanation and evidence",
            0,
        ),
        ("model-error", "Scripted model transport failure", 0),
    ] {
        let result = birdcage(&["review", "feature", "--into", "main", "--script", script]);
        assert_eq!(result.status.code(), Some(1), "{script}: {result:?}");
        assert_eq!(
            result.stderr,
            format!("Review failed: {error}\n").as_bytes()
        );
        let output = String::from_utf8(result.stdout).unwrap();
        assert!(!output.contains("Scripted review report"), "{script}");
        assert_eq!(
            output.matches("Tool request:").count(),
            dispatches,
            "{script}"
        );
    }
}

#[test]
fn unknown_scripts_do_not_start_a_review() {
    let result = birdcage(&["review", "feature", "--into", "main", "--script", "unknown"]);
    assert_eq!(result.status.code(), Some(2));
    assert!(result.stdout.is_empty());
    assert_eq!(result.stderr, b"Unknown script: unknown\n");
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
fn file_write_failure_is_returned_to_roc() {
    let path = std::env::temp_dir()
        .join(format!("birdcage-missing-parent-{}", std::process::id()))
        .join("file");
    let result = birdcage(&["file-demo", path.to_str().unwrap()]);
    assert_eq!(result.status.code(), Some(1), "{result:?}");
    assert!(result.stdout.is_empty());
    assert!(String::from_utf8(result.stderr)
        .unwrap()
        .starts_with("File demo failed: "));
    assert!(!path.exists());
}

#[test]
fn direct_file_fixture_preserves_heap_values() {
    let path =
        std::env::temp_dir().join(format!("birdcage-file-fixture-{}.txt", std::process::id()));
    let result = birdcage(&["file-demo", path.to_str().unwrap()]);
    assert!(result.status.success(), "{result:?}");
    assert_eq!(result.stdout, b"File round-trip verified\n");
    assert_eq!(
        std::fs::read_to_string(&path).unwrap(),
        "Async Roc → Rust → Roc 🦜\n".repeat(16)
    );
    std::fs::remove_file(path).unwrap();
}
