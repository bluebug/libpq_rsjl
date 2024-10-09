use std::ffi::{c_char, c_void, CStr, CString};

#[repr(C)]
pub struct Copyout {
    /// csv string or error message
    pub body: *const i8,
    /// length of body without \0
    pub len: u32,
    /// 0 means success and body is csv string, >0 means failed and body is error message
    pub err: u32,
}

#[no_mangle]
pub extern "C" fn pq_conn(url: *const i8) -> *const c_void {
    let url = unsafe { CStr::from_ptr(url).to_str() };
    if url.is_ok() {
        let client = postgres::Client::connect(url.unwrap(), postgres::NoTls);
        if client.is_ok() {
            Box::into_raw(Box::new(client.unwrap())) as *const c_void
        } else {
            println!("connect failed:{}", client.err().unwrap());
            std::ptr::null()
        }
    } else {
        println!("invalid url:{}", url.err().unwrap());
        std::ptr::null()
    }
}

#[no_mangle]
/// Executes a statement, returning the number of rows modified.
///
/// Returns -1 if client is null
/// Returns -2 if execute failed
/// Returns -3 if invalid sql
pub extern "C" fn pq_execute(c: *const c_void, sql: *const i8) -> i64 {
    if c.is_null() {
        println!("client is null");
        return -1;
    }
    let sql = unsafe { CStr::from_ptr(sql).to_str() };
    if sql.is_ok() {
        let res = (unsafe { &mut *(c as *mut postgres::Client) }).execute(sql.unwrap(), &[]);
        if res.is_ok() {
            res.unwrap() as i64
        } else {
            println!("execute failed:{}", res.err().unwrap());
            -2
        }
    } else {
        println!("invalid sql:{}", sql.err().unwrap());
        -3
    }
}

#[no_mangle]
/// copy out query result to csv string
pub extern "C" fn pq_copyout_native(
    c: *const c_void,
    sql: *const i8,
    delim: c_char,
    header: u8,
) -> Copyout {
    let body;
    let mut err = 0;

    if c.is_null() {
        body = "client is null".to_owned();
        err = 1;
    } else {
        let sql = unsafe { CStr::from_ptr(sql).to_str() };
        if sql.is_ok() {
            let copyout_sql = format!(
                "COPY ({}) TO STDOUT (FORMAT CSV, {}, DELIMITER '{}', ENCODING 'utf-8');",
                sql.unwrap(),
                if header > 0 { "HEADER" } else { "" },
                delim as u8 as char
            );
            let client = unsafe { &mut *(c as *mut postgres::Client) };
            use std::io::Read;
            let reader = client.copy_out(copyout_sql.as_str());
            if reader.is_ok() {
                let mut buf = vec![];
                reader.unwrap().read_to_end(&mut buf).unwrap();
                body = String::from_utf8(buf).unwrap();
            } else {
                body = format!("copyout failed:{}", reader.err().unwrap());
                err = 3;
            }
        } else {
            body = format!("invalid sql:{}", sql.err().unwrap());
            err = 2;
        }
    }

    Copyout {
        body: CString::new(body.as_str()).unwrap().into_raw(),
        len: body.len() as u32,
        err,
    }
}

#[no_mangle]
pub extern "C" fn pq_show_copyout(s: Copyout) {
    if !s.body.is_null() {
        let body = unsafe { CStr::from_ptr(s.body) };
        println!("{}", body.to_str().unwrap());
    }
}

#[no_mangle]
pub extern "C" fn pq_free_copyout(s: Copyout) {
    if !s.body.is_null() {
        let _ = unsafe { CString::from_raw(s.body as *mut i8) };
    }
}

#[no_mangle]
pub extern "C" fn pq_disconn(c: *mut c_void) {
    unsafe {
        if !c.is_null() {
            let client = Box::from_raw(c as *mut postgres::Client);
            client.close().unwrap();
        }
    };
}
