using StringViews

function CStringLength(cs)
    ptr = Ptr{UInt8}(cs)
    if ptr == C_NULL
        0
    else
        ccall(:strlen, Cint, (Ptr{UInt8},), ptr)
    end
end

function CStringView(cs)
    ptr = Ptr{UInt8}(cs)
    if ptr == C_NULL
        StringView("")
    else
        StringView(unsafe_wrap(Array, ptr, length(cs)))
    end
end
Base.length(cs::Cstring) = CStringLength(cs)
Base.write(io::IO, cs::Cstring) = write(io, CStringView(cs))
Base.print(io::IO, cs::Cstring) = (write(io, CStringView(cs)); nothing)
Base.show(io::IO, cs::Cstring) = show(io, CStringView(cs))

Base.length(cs::Ptr{UInt8}) = CStringLength(cs)
Base.write(io::IO, cs::Ptr{UInt8}) = write(io, CStringView(cs))
Base.print(io::IO, cs::Ptr{UInt8}) = (write(io, CStringView(cs)); nothing)
Base.show(io::IO, cs::Ptr{UInt8}) = show(io, CStringView(cs))

export CStringView

const libpq_path = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq.$(Sys.iswindows() ? "dll" : "so")"))
