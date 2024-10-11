### Purpose:
Use the rust postgres library to generate a postgresql client that can be quickly imported, and provide a copyout method to quickly obtain csv results.

### Prerequisites:
1. Rust environment
2. Julia environment with Clang.jl
3. Postgresql database
4. Modify the database link and test code in build.jl

### Flow of development:
Interop rust and julia together without jirs.
``` mermaid 
flowchart LR;

rust[rust cdylib] -- cbindgen -->c[c header];
c -- Clang.jl
[with prefix and postfix]-->julia[julia library];

```

### Compile method:
using global julia env
1. build step by step
``` julia
include("build.jl")

build_rs()
build_jl()
test()
```

2. or build once
``` cmd
julia build.jl
```

### howto:
Refer to the test code in build.jl

### changelog:
- 2024-10-10 v0.2.1: 
    - replace unsafe_string with StringViews.jl, to avoid memory copy for Cstring
    - add property `buf` for Copyout, return a IOBuffer object for CSV.jl
    
- 2024-10-10 v0.2.0: 
    - add pq_query_native(rs)/pq_query(jl) function to get dframe from postgresql
    - add pq_free_dframe(rs) function to release dframe, but not sure if the rust code releases the memory correctly💣
    - add test code for dframe in build.jl
    - call unsafe_string only when call copyout.body

- 2024-10-09 v0.1.1: 
    - using Clang.jl to generate julia library
    - use mutable struct Copyout so that rust memory can be freed auto
    - refactor project name and interface
    - rewrite build.jl

- 2024-10-03 v0.1.0: initial version
