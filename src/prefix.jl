using StringViews

Base.length(cs::Cstring) = ccall(:strlen, Cint, (Cstring,), cs)
CStringView(cs::Cstring) = StringView(unsafe_wrap(Array, Ptr{UInt8}(cs), length(cs)))
Base.write(io::IO, cs::Cstring) = write(io, CStringView(cs))
Base.print(io::IO, cs::Cstring) = (write(io, CStringView(cs)); nothing)
Base.show(io::IO, cs::Cstring) = (write(io, CStringView(cs)); nothing)

Base.length(cs::Ptr{UInt8}) = ccall(:strlen, Cint, (Ptr{UInt8},), cs)
CStringView(cs::Ptr{UInt8}) = StringView(unsafe_wrap(Array, cs, length(cs)))
Base.write(io::IO, cs::Ptr{UInt8}) = write(io, CStringView(cs))
Base.print(io::IO, cs::Ptr{UInt8}) = (write(io, CStringView(cs)); nothing)
Base.show(io::IO, cs::Ptr{UInt8}) = (write(io, CStringView(cs)); nothing)

export CStringView

const libpq_path = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq.$(Sys.iswindows() ? "dll" : "so")"))
