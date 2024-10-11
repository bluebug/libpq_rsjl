use std::{
    ffi::{c_char, c_void, CStr, CString},
    ptr::{null, null_mut},
};

#[repr(C)]
#[derive(PartialEq)]
pub enum DTypes {
    I8 = 0,
    I32 = 1,
    I64 = 2,
    F32 = 3,
    F64 = 4,
    Str = 5,
}

#[repr(C)]
pub struct DFrame {
    /// number of fields
    pub width: u32,
    /// number of rows
    pub height: u32,
    /// field names
    pub fields: *mut *const u8,
    /// field types
    pub types: *mut DTypes,
    // field values
    pub values: *mut *const c_void,
    /// error code, 0 means success, >0 means failed
    pub err_code: u32,
    /// error message
    pub err_msg: *mut u8,
}

#[repr(C)]
pub struct Copyout {
    /// csv string or error message
    pub body: *const u8,
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
            dbg!("connect failed:{}", client.err().unwrap());
            std::ptr::null()
        }
    } else {
        dbg!("invalid url:{}", url.err().unwrap());
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
        dbg!("client is null");
        return -1;
    }
    let sql = unsafe { CStr::from_ptr(sql).to_str() };
    if sql.is_ok() {
        let res = (unsafe { &mut *(c as *mut postgres::Client) }).execute(sql.unwrap(), &[]);
        if res.is_ok() {
            res.unwrap() as i64
        } else {
            dbg!("execute failed:{}", res.err().unwrap());
            -2
        }
    } else {
        dbg!("invalid sql:{}", sql.err().unwrap());
        -3
    }
}

#[no_mangle]
/// query a sql and return a dataframe
pub extern "C" fn pq_query_native(c: *const c_void, sql: *const i8) -> DFrame {
    let mut width = 0;
    let mut height = 0;
    let mut fields = null_mut();
    let mut types = null_mut();
    let mut values = null_mut();
    let mut err_code = 0;
    let mut err_msg = null_mut();

    if c.is_null() {
        err_code = 1;
        err_msg = CString::new("client is null").unwrap().into_raw();
    } else {
        let sql = unsafe { CStr::from_ptr(sql).to_str() };
        if sql.is_ok() {
            let res = (unsafe { &mut *(c as *mut postgres::Client) }).query(sql.unwrap(), &[]);
            if res.is_ok() {
                let rows = res.as_ref().unwrap();
                height = rows.len() as u32;
                if height > 0 {
                    let row = &rows[0];
                    let columns = row.columns();
                    width = columns.len() as u32;
                    let mut fs = vec![];
                    let mut ts = vec![];
                    let mut vs = vec![];
                    for (col_index, col) in columns.iter().enumerate() {
                        fs.push(CString::new(col.name()).unwrap().into_raw());
                        match col.type_() {
                            &postgres::types::Type::BOOL => {
                                ts.push(DTypes::I8);
                                let mut v = vec![0i8; height as usize];
                                for (row_index, row) in rows.iter().enumerate() {
                                    v[row_index] = row.get::<usize, i8>(col_index);
                                }
                                vs.push(Box::into_raw(v.into_boxed_slice()) as *const c_void);
                            }
                            &postgres::types::Type::INT4 => {
                                ts.push(DTypes::I32);
                                let mut v = vec![0i32; height as usize];
                                for (row_index, row) in rows.iter().enumerate() {
                                    v[row_index] = row.get::<usize, i32>(col_index);
                                }
                                vs.push(Box::into_raw(v.into_boxed_slice()) as *const c_void);
                            }
                            &postgres::types::Type::INT8 => {
                                ts.push(DTypes::I64);
                                let mut v = vec![0i64; height as usize];
                                for (row_index, row) in rows.iter().enumerate() {
                                    v[row_index] = row.get::<usize, i64>(col_index);
                                }
                                vs.push(Box::into_raw(v.into_boxed_slice()) as *const c_void);
                            }
                            &postgres::types::Type::FLOAT4 => {
                                ts.push(DTypes::F32);
                                let mut v = vec![f32::NAN; height as usize];
                                for (row_index, row) in rows.iter().enumerate() {
                                    v[row_index] = row.try_get(col_index).unwrap_or(f32::NAN);
                                }
                                vs.push(Box::into_raw(v.into_boxed_slice()) as *const c_void);
                            }
                            &postgres::types::Type::FLOAT8 => {
                                ts.push(DTypes::F64);
                                let mut v = vec![0f64; height as usize];
                                for (row_index, row) in rows.iter().enumerate() {
                                    v[row_index] = row.try_get(col_index).unwrap_or(f64::NAN);
                                }
                                vs.push(Box::into_raw(v.into_boxed_slice()) as *const c_void);
                            }
                            &postgres::types::Type::TEXT | &postgres::types::Type::VARCHAR => {
                                ts.push(DTypes::Str);
                                let mut v = vec![null(); height as usize];
                                for (row_index, row) in rows.iter().enumerate() {
                                    let s =
                                        row.try_get::<usize, String>(col_index).unwrap_or_default();
                                    v[row_index] = CString::new(s).unwrap().into_raw();
                                }
                                vs.push(Box::into_raw(v.into_boxed_slice()) as *const c_void);
                            }
                            _ => panic!("unsupported type"),
                        };
                    }
                    fields = Box::into_raw(fs.into_boxed_slice()) as *mut *const u8;
                    types = Box::into_raw(ts.into_boxed_slice()) as *mut DTypes;
                    values = Box::into_raw(vs.into_boxed_slice()) as *mut *const c_void;
                }
            } else {
                err_code = 3;
                err_msg = CString::new(format!("query failed:{}", res.err().unwrap()).as_str())
                    .unwrap()
                    .into_raw();
            }
        } else {
            err_code = 2;
            err_msg = CString::new(format!("invalid sql:{}", sql.err().unwrap()).as_str())
                .unwrap()
                .into_raw();
        }
    }
    DFrame {
        width,
        height,
        fields,
        types,
        values,
        err_code,
        err_msg: err_msg as *mut u8,
    }
}

#[no_mangle]
/// free data frame
pub extern "C" fn pq_free_dframe(df: DFrame) {
    if !df.values.is_null() {
        let vs = unsafe { Vec::from_raw_parts(df.values, df.width as usize, df.width as usize) };
        if !df.types.is_null() {
            let ts = unsafe { Vec::from_raw_parts(df.types, df.width as usize, df.width as usize) };
            for (i, t) in ts.iter().enumerate() {
                if t == &DTypes::Str {
                    let v = unsafe {
                        Vec::from_raw_parts(
                            vs[i] as *mut *mut i8,
                            df.height as usize,
                            df.height as usize,
                        )
                    };
                    for f in v.iter() {
                        let _ = unsafe { CString::from_raw(*f) };
                    }
                }
            }
        }
    } else {
        if !df.types.is_null() {
            let _ = unsafe { Vec::from_raw_parts(df.types, df.width as usize, df.width as usize) };
        }
    }

    if !df.fields.is_null() {
        let fs = unsafe { Vec::from_raw_parts(df.fields, df.width as usize, df.width as usize) };
        for f in fs.iter() {
            let _ = unsafe { CString::from_raw(*f as *mut i8) };
        }
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
        body: CString::new(body.as_str()).unwrap().into_raw() as *const u8,
        len: body.len() as u32,
        err,
    }
}

#[no_mangle]
pub extern "C" fn pq_show_copyout(s: Copyout) {
    if !s.body.is_null() {
        let body = unsafe { CStr::from_ptr(s.body as *const i8) };
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
