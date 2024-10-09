extern crate cbindgen;

use std::env;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .with_style(cbindgen::Style::Tag)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("include/libpq.h");

    println!("cargo:rerun-if-changed=lib.rs");
}
