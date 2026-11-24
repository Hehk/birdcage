use std::fs::{self, DirBuilder, OpenOptions};
use std::io::{self, Write};
use std::mem::ManuallyDrop;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
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
                err: ManuallyDrop::new(file_error(error)),
            },
        },
    }
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_write(path: RocStr, contents: RocStr) -> abi::FileAppendResult {
    unit_result(fs::write(take_string(path), take_string(contents)))
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_create_dir_all(path: RocStr) -> abi::FileAppendResult {
    unit_result(
        DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(take_string(path)),
    )
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_create_new(path: RocStr, contents: RocStr) -> abi::FileAppendResult {
    let path = take_string(path);
    let contents = take_string(contents);
    unit_result(
        OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(path)
            .and_then(|mut file| file.write_all(contents.as_bytes())),
    )
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_append(path: RocStr, contents: RocStr) -> abi::FileAppendResult {
    let path = take_string(path);
    let contents = take_string(contents);
    unit_result(
        OpenOptions::new()
            .append(true)
            .open(path)
            .and_then(|mut file| file.write_all(contents.as_bytes())),
    )
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_list_files(path: RocStr) -> abi::FileListFilesResult {
    use abi::{
        FileListFilesResult as Result, FileListFilesResultPayload as Payload,
        FileListFilesResultTag as Tag,
    };
    match list_files(&take_string(path)) {
        Ok(names) => Result {
            tag: Tag::Ok,
            payload: Payload {
                ok: ManuallyDrop::new(crate::roc_strings(&names)),
            },
        },
        Err(error) => Result {
            tag: Tag::Err,
            payload: Payload {
                err: ManuallyDrop::new(file_error(error)),
            },
        },
    }
}

fn list_files(path: &str) -> io::Result<Vec<String>> {
    let mut names = Vec::new();
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        if entry.file_type()?.is_file() {
            if let Ok(name) = entry.file_name().into_string() {
                names.push(name);
            }
        }
    }
    Ok(names)
}

fn unit_result(result: io::Result<()>) -> abi::FileAppendResult {
    use abi::{
        FileAppendResult as Result, FileAppendResultPayload as Payload, FileAppendResultTag as Tag,
    };
    match result {
        Ok(()) => Result {
            tag: Tag::Ok,
            payload: Payload { ok: [] },
        },
        Err(error) => Result {
            tag: Tag::Err,
            payload: Payload {
                err: ManuallyDrop::new(file_error(error)),
            },
        },
    }
}

fn file_error(error: io::Error) -> abi::AnonStructCc42f5227e7c3b8b {
    use abi::AddrInUseOrAddrNotAvailableOrAlreadyExistsOrBrokenPipeOrConnectionAbortedOrConnectionRefusedOrConnectionResetOrInterruptedOrInvalidDataOrInvalidInputOrNotConnectedOrNotFoundOrOtherOrOutOfMemoryOrPermissionDeniedOrTimedOutOrUnexpectedEofOrUnsupportedOrWouldBlockOrWriteZero as Kind;
    use abi::{
        NoOsCodeOrOsCode as Code, NoOsCodeOrOsCodePayload as Payload, NoOsCodeOrOsCodeTag as Tag,
    };
    use io::ErrorKind as RustKind;

    let kind = match error.kind() {
        RustKind::NotFound => Kind::NotFound,
        RustKind::PermissionDenied => Kind::PermissionDenied,
        RustKind::ConnectionRefused => Kind::ConnectionRefused,
        RustKind::ConnectionReset => Kind::ConnectionReset,
        RustKind::ConnectionAborted => Kind::ConnectionAborted,
        RustKind::NotConnected => Kind::NotConnected,
        RustKind::AddrInUse => Kind::AddrInUse,
        RustKind::AddrNotAvailable => Kind::AddrNotAvailable,
        RustKind::BrokenPipe => Kind::BrokenPipe,
        RustKind::AlreadyExists => Kind::AlreadyExists,
        RustKind::WouldBlock => Kind::WouldBlock,
        RustKind::InvalidInput => Kind::InvalidInput,
        RustKind::InvalidData => Kind::InvalidData,
        RustKind::TimedOut => Kind::TimedOut,
        RustKind::WriteZero => Kind::WriteZero,
        RustKind::Interrupted => Kind::Interrupted,
        RustKind::Unsupported => Kind::Unsupported,
        RustKind::UnexpectedEof => Kind::UnexpectedEof,
        RustKind::OutOfMemory => Kind::OutOfMemory,
        _ => Kind::Other,
    };
    let os_code = match error.raw_os_error() {
        Some(code) => Code {
            tag: Tag::OsCode,
            payload: Payload {
                os_code: ManuallyDrop::new(code),
            },
        },
        None => Code {
            tag: Tag::NoOsCode,
            payload: Payload { no_os_code: [] },
        },
    };
    abi::AnonStructCc42f5227e7c3b8b {
        kind,
        os_code,
        detail: RocStr::from_str(&error.to_string(), &abi::make_roc_host(null_mut())),
    }
}
