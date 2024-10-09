using Pkg
using Clang.Generators

function build_rs()
    println("📌 start to build rust library debug version")
    run(`cargo build`)
    println()
    println("📌 start to build rust library release version")
    run(`cargo build --release`)
    println()
end

function build_jl()
    println("📌 start to gen jll")
    options = Dict{String,Any}(
        "general" => Dict{String,Any}(
            "library_name" => "libpq_path",
            "output_file_path" => "./src/libpq.jl",
            "module_name" => "libpq",
            "prologue_file_path" => "./src/prefix.jl",
            "epilogue_file_path" => "./src/postfix.jl",
            "export_symbol_prefixes" => ["pq_"],
            "auto_mutability" => true,
            "auto_mutability_with_new" => false,
        ))

    args = get_default_args()  # Note you must call this function firstly and then append your own flags
    headers = [joinpath(@__DIR__, "include", "libpq.h")]
    ctx = create_context(headers, args, options)
    build!(ctx)
    println()

    println("📌 start to package julia library dev(local) ")
    Pkg.develop(path=normpath(dirname(@__FILE__)))
    Pkg.precompile("libpq")
end

function test()
    println("📌 do some test")
    @eval begin
        @time "  ✔️ imports          " import libpq as pq, CSV
        function real_test()
            @time "  ✔️ conn         " client = pq.pq_conn("postgresql://test:test@localhost:5434/test")

            @time "  ✔️ drop table   " pq.pq_execute(client, "DROP TABLE IF EXISTS test")
            @time "  ✔️ create table " pq.pq_execute(client, "CREATE TABLE test (a int, b float, c varchar(255))")

            @time "  ✔️ insert 1     " pq.pq_execute(client, "INSERT INTO test VALUES (1, 2.3, 'abc')")
            @time "  ✔️ insert 2     " pq.pq_execute(client, "INSERT INTO test VALUES (2, 8.3, 'def')")
            @time "  ✔️ insert 3     " pq.pq_execute(client, "INSERT INTO test VALUES (3, -4.5, 'ghi')")
            @time "  ✔️ insert 4     " pq.pq_execute(client, "INSERT INTO test VALUES (4, -242.315, '📌📌📌')")
            delim = '\t'
            @time "  ✔️ copyout      " csv = pq.pq_copyout(client, "SELECT * FROM test"; delim=delim) # default delim is \t 
            println()
            @time "  ✔️ print by rs  " pq.pq_show_copyout(csv)
            println()
            @time "  ✔️ print by jl  " println(csv)
            println()

            @time "  ✔️ read by CSV  " file = CSV.File(IOBuffer(unsafe_wrap(Array, Ptr{UInt8}(csv.body), csv.len)); delim=delim)
            println("a: ", file.a, "\nb: ", file.b, "\nc: ", file.c)
            println()

            @time "  ✔️ drop table   " pq.pq_execute(client, "DROP TABLE IF EXISTS test")
            @time "  ✔️ disconnect   " pq.pq_disconn(client)
            println()
        end
    end

    @eval real_test()
end

if !isinteractive()
    build_rs()
    build_jl()
    test()
end