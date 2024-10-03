println("1. start to build rust library debug version")
run(`cargo build`)
println("2. start to build rust library debug version")
run(`cargo build --release`)

println("3. start to package julia library dev(local) ")
using Pkg
Pkg.develop(path=normpath(dirname(@__FILE__)))
Pkg.precompile("pq")

println("4. do some test")

@timev "import pq" import pq
@timev "conn" client = pq.conn("postgresql://test:test@localhost:5432/test")

@timev "drop table" pq.execute(client, "DROP TABLE IF EXISTS test")
@timev "create table" pq.execute(client, "CREATE TABLE test (a int, b float, c varchar(255))")

pq.execute(client, "INSERT INTO test VALUES (1, 2.3, 'abc')")
pq.execute(client, "INSERT INTO test VALUES (2, 8.3, 'def')")
pq.execute(client, "INSERT INTO test VALUES (3, -4.5, 'ghi')")

@timev "copyout" csv = pq.copyout_csv(client, "SELECT * FROM test")
println(csv)
pq.free_csvstring(csv)

@timev "disconnect" pq.disconnect(client)
