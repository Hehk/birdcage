use std::mem::ManuallyDrop;
use std::ptr::null_mut;

use crate::abi::{self, RocStr};

fn take_string(value: RocStr) -> String {
    let text = value.as_str().to_owned();
    unsafe { value.decref(&abi::make_roc_host(null_mut())) };
    text
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_read(path: RocStr) -> abi::FileReadResult {
    let result = std::fs::read_to_string(take_string(path));
    let host = abi::make_roc_host(null_mut());
    match result {
        Ok(text) => abi::FileReadResult {
            tag: abi::FileReadResultTag::Ok,
            payload: abi::FileReadResultPayload {
                ok: ManuallyDrop::new(RocStr::from_str(&text, &host)),
            },
        },
        Err(error) => abi::FileReadResult {
            tag: abi::FileReadResultTag::Err,
            payload: abi::FileReadResultPayload {
                err: ManuallyDrop::new(RocStr::from_str(&error.to_string(), &host)),
            },
        },
    }
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_write(path: RocStr, contents: RocStr) -> abi::FileWriteResult {
    let result = std::fs::write(take_string(path), take_string(contents));
    match result {
        Ok(()) => abi::FileWriteResult {
            tag: abi::FileWriteResultTag::Ok,
            payload: abi::FileWriteResultPayload { ok: [] },
        },
        Err(error) => abi::FileWriteResult {
            tag: abi::FileWriteResultTag::Err,
            payload: abi::FileWriteResultPayload {
                err: ManuallyDrop::new(RocStr::from_str(
                    &error.to_string(),
                    &abi::make_roc_host(null_mut()),
                )),
            },
        },
    }
}
