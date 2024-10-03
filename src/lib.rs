use std::ffi::{c_void, CStr, CString};

#[repr(C)]
/// string for csv ffi
pub struct CsvString {
    pub ptr: *const i8,
    pub len: u32,
    pub error: *const i8,
}

#[no_mangle]
pub extern "C" fn conn(url: *const i8) -> *const c_void {
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
pub extern "C" fn execute(c: *const c_void, sql: *const i8) -> i64 {
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
pub extern "C" fn copyout(c: *const c_void, copyout_sql: *const i8) -> CsvString {
    if c.is_null() {
        CsvString {
            ptr: std::ptr::null(),
            len: 0,
            error: CString::new("client is null").unwrap().into_raw(),
        }
    } else {
        let sql = unsafe { CStr::from_ptr(copyout_sql).to_str() };
        if sql.is_ok() {
            let client = unsafe { &mut *(c as *mut postgres::Client) };
            use std::io::Read;
            let reader = client.copy_out(sql.unwrap());
            if reader.is_ok() {
                let mut buf = vec![];
                reader.unwrap().read_to_end(&mut buf).unwrap();
                let size = buf.len();
                let csv = CString::new(buf).unwrap();

                CsvString {
                    ptr: csv.into_raw(),
                    len: size as u32,
                    error: std::ptr::null(),
                }
            } else {
                CsvString {
                    ptr: std::ptr::null(),
                    len: 0,
                    error: CString::new(format!("copyout failed:{}", reader.err().unwrap()))
                        .unwrap()
                        .into_raw(),
                }
            }
        } else {
            CsvString {
                ptr: std::ptr::null(),
                len: 0,
                error: CString::new(format!("invalid sql:{}", sql.err().unwrap()))
                    .unwrap()
                    .into_raw(),
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn free_csvstring(s: CsvString) {
    if !s.ptr.is_null() {
        let _ = unsafe { CString::from_raw(s.ptr as *mut i8) };
        println!("csvstring freed");
    }
    if !s.error.is_null() {
        let _ = unsafe { CString::from_raw(s.error as *mut i8) };
        println!("csvstring freed");
    }
}

#[no_mangle]
pub extern "C" fn disconnect(c: *mut c_void) {
    unsafe {
        if !c.is_null() {
            let client = Box::from_raw(c as *mut postgres::Client);
            client.close().unwrap();
            println!("client closed and destroyed");
        } else {
            println!("client is null");
        }
    };
}
