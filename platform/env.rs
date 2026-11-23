use std::env::{self, VarError};
use std::mem::ManuallyDrop;
use std::ptr::null_mut;

use crate::abi::{self, InvalidUnicodeOrNotFound, RocStr};

#[unsafe(no_mangle)]
extern "C" fn roc_env_var(name: RocStr) -> abi::EnvVarResult {
    let result = env::var(name.as_str());
    let host = abi::make_roc_host(null_mut());
    unsafe { name.decref(&host) };
    match result {
        Ok(value) => abi::EnvVarResult {
            tag: abi::EnvVarResultTag::Ok,
            payload: abi::EnvVarResultPayload {
                ok: ManuallyDrop::new(RocStr::from_str(&value, &host)),
            },
        },
        Err(error) => abi::EnvVarResult {
            tag: abi::EnvVarResultTag::Err,
            payload: abi::EnvVarResultPayload {
                err: ManuallyDrop::new(match error {
                    VarError::NotPresent => InvalidUnicodeOrNotFound::NotFound,
                    VarError::NotUnicode(_) => InvalidUnicodeOrNotFound::InvalidUnicode,
                }),
            },
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;
    use std::process::Command;

    #[test]
    fn reads_environment_strictly() {
        const VARIABLE: &str = "BIRDCAGE_ENV_TEST_VALUE";
        const CASE: &str = "BIRDCAGE_ENV_TEST_CASE";
        let text = "hello 🦜".repeat(32);
        if let Ok(case) = env::var(CASE) {
            let host = abi::make_roc_host(null_mut());
            let result = roc_env_var(RocStr::from_str(VARIABLE, &host));
            match case.as_str() {
                "text" | "empty" => {
                    assert_eq!(result.tag, abi::EnvVarResultTag::Ok);
                    let expected = if case == "empty" { "" } else { &text };
                    assert_eq!(
                        unsafe { result.borrow_payload_ok_unchecked() }.as_str(),
                        expected
                    );
                }
                "missing" | "invalid" => {
                    assert_eq!(result.tag, abi::EnvVarResultTag::Err);
                    let expected = if case == "missing" {
                        InvalidUnicodeOrNotFound::NotFound
                    } else {
                        InvalidUnicodeOrNotFound::InvalidUnicode
                    };
                    assert_eq!(*unsafe { result.borrow_payload_err_unchecked() }, expected);
                }
                _ => panic!("unknown environment test case"),
            }
            unsafe { result.decref(&host) };
            return;
        }
        let mut cases = vec![
            ("text", Some(OsString::from(text))),
            ("empty", Some(OsString::new())),
            ("missing", None),
        ];
        #[cfg(unix)]
        {
            use std::os::unix::ffi::OsStringExt;
            cases.push(("invalid", Some(OsString::from_vec(vec![0xff]))));
        }
        for (case, value) in cases {
            let mut child = Command::new(env::current_exe().unwrap());
            child.args(["--exact", "env::tests::reads_environment_strictly"]);
            child.env(CASE, case).env_remove(VARIABLE);
            if let Some(value) = value {
                child.env(VARIABLE, value);
            }
            let output = child.output().unwrap();
            assert!(output.status.success(), "{case}: {output:?}");
        }
    }
}
