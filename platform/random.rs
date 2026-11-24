use std::mem::ManuallyDrop;
use std::ptr::null_mut;

use crate::abi::{self, RandomBytesResult, RandomBytesResultPayload, RandomBytesResultTag};

#[unsafe(no_mangle)]
extern "C" fn roc_random_bytes(count: u8) -> RandomBytesResult {
    let mut buffer = [0; u8::MAX as usize];
    let bytes = &mut buffer[..usize::from(count)];
    let host = abi::make_roc_host(null_mut());
    match getrandom::getrandom(bytes) {
        Ok(()) => RandomBytesResult {
            tag: RandomBytesResultTag::Ok,
            payload: RandomBytesResultPayload {
                ok: ManuallyDrop::new(unsafe { abi::RocListWith::from_slice(bytes, &host) }),
            },
        },
        Err(error) => RandomBytesResult {
            tag: RandomBytesResultTag::Err,
            payload: RandomBytesResultPayload {
                err: ManuallyDrop::new(abi::RocStr::from_str(&error.to_string(), &host)),
            },
        },
    }
}
