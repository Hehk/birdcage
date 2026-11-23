use std::error::Error;
use std::mem::ManuallyDrop;
use std::ptr::null_mut;
use std::time::Duration;

use crate::abi::{self, RocList, RocListWith, RocStr};

#[unsafe(no_mangle)]
extern "C" fn roc_http_send(request: abi::HttpSendArg0) -> abi::HttpSendResult {
    let result = send(&request);
    let host = abi::make_roc_host(null_mut());
    unsafe { request.decref(&host) };
    match result {
        Ok(response) => abi::HttpSendResult {
            tag: abi::HttpSendResultTag::Ok,
            payload: abi::HttpSendResultPayload {
                ok: ManuallyDrop::new(response),
            },
        },
        Err(error) => abi::HttpSendResult {
            tag: abi::HttpSendResultTag::Err,
            payload: abi::HttpSendResultPayload {
                err: ManuallyDrop::new(RocStr::from_str(&error.to_string(), &host)),
            },
        },
    }
}

fn send(request: &abi::HttpSendArg0) -> Result<abi::HttpSendOk, Box<dyn Error>> {
    if request.timeout_ms == 0 {
        return Err("HTTP timeout must be greater than zero".into());
    }
    let agent: ureq::Agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_millis(request.timeout_ms)))
        .http_status_as_error(false)
        .max_redirects(0)
        .build()
        .into();
    let mut builder = ureq::http::Request::builder()
        .method(request.method.as_str())
        .uri(request.url.as_str());
    for header in request.headers.as_slice() {
        builder = builder.header(header.name.as_str(), header.value.as_str());
    }
    let mut response = agent.run(builder.body(request.body.as_slice())?)?;
    let bytes = response.body_mut().read_to_vec()?;
    let headers: Vec<_> = response
        .headers()
        .iter()
        .map(|(name, value)| Ok((name.as_str(), value.to_str()?)))
        .collect::<Result<_, ureq::http::header::ToStrError>>()?;
    let host = abi::make_roc_host(null_mut());
    let body = unsafe { RocListWith::<u8, false>::allocate(bytes.len(), &host) };
    if !bytes.is_empty() {
        unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), body.elements, bytes.len()) };
    }
    let roc_headers = unsafe { RocList::<abi::HttpSendOkHeaders>::allocate(headers.len(), &host) };
    for (index, (name, value)) in headers.into_iter().enumerate() {
        unsafe {
            roc_headers
                .elements
                .add(index)
                .write(abi::HttpSendOkHeaders {
                    name: RocStr::from_str(name, &host),
                    value: RocStr::from_str(value, &host),
                });
        }
    }
    Ok(abi::HttpSendOk {
        status: response.status().as_u16(),
        headers: roc_headers,
        body,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;

    #[test]
    fn sends_requests_and_returns_http_responses_without_redirecting() {
        for status in [200, 401, 302] {
            let listener = TcpListener::bind("127.0.0.1:0").unwrap();
            let url = format!("http://{}/message", listener.local_addr().unwrap());
            let server = std::thread::spawn(move || {
                let (mut socket, _) = listener.accept().unwrap();
                socket
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                let mut headers = Vec::new();
                while !headers.ends_with(b"\r\n\r\n") {
                    let mut byte = [0];
                    socket.read_exact(&mut byte).unwrap();
                    headers.push(byte[0]);
                }
                let headers = String::from_utf8(headers).unwrap().to_lowercase();
                assert!(headers.starts_with("post /message http/1.1\r\n"));
                assert!(headers.contains("x-test: birdcage\r\n"));
                let mut body = [0; 2];
                socket.read_exact(&mut body).unwrap();
                assert_eq!(body, [0, 255]);
                write!(socket, "HTTP/1.1 {status} Test\r\nContent-Length: 2\r\nX-Reply: hello\r\nLocation: http://127.0.0.1:1/redirect\r\nConnection: close\r\n\r\n").unwrap();
                socket.write_all(&[255, 0]).unwrap();
            });
            let host = abi::make_roc_host(null_mut());
            let body = unsafe { RocListWith::<u8, false>::allocate(2, &host) };
            let headers = unsafe { RocList::<abi::HttpSendArg0Headers>::allocate(1, &host) };
            unsafe {
                body.elements.write(0);
                body.elements.add(1).write(255);
                headers.elements.write(abi::HttpSendArg0Headers {
                    name: RocStr::from_str("X-Test", &host),
                    value: RocStr::from_str("birdcage", &host),
                });
            }
            let result = roc_http_send(abi::HttpSendArg0 {
                method: RocStr::from_str("POST", &host),
                url: RocStr::from_str(&url, &host),
                timeout_ms: 1000,
                headers,
                body,
            });
            server.join().unwrap();
            assert_eq!(result.tag, abi::HttpSendResultTag::Ok);
            let response = unsafe { result.borrow_payload_ok_unchecked() };
            assert_eq!(response.status, status);
            assert_eq!(response.body.as_slice(), [255, 0]);
            assert!(response.headers.as_slice().iter().any(|header| {
                header.name.as_str() == "x-reply" && header.value.as_str() == "hello"
            }));
            unsafe { result.decref(&host) };
        }
    }
}
