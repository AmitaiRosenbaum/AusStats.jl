const PARSED_CACHE_VERSION = "1"

function _with_parsed_cache(
    f::Function,
    path::AbstractString;
    kind::Symbol,
    options,
    cache_parsed::Bool,
    refresh::Bool,
)
    cache_parsed || return f()

    key = _parsed_cache_key(path; kind=kind, options=options)
    cache_path = _parsed_cache_path(key)
    expected = _parsed_cache_metadata(path; kind=kind, options=options)

    if !refresh && isfile(cache_path)
        cached = _read_parsed_cache(cache_path, expected)
        cached === nothing || return cached
    end

    parsed = f()
    parsed isa DataFrame || return parsed
    _write_parsed_cache(cache_path, expected, parsed)
    return parsed
end

function _parsed_cache_key(path::AbstractString; kind::Symbol, options)
    metadata = _parsed_cache_metadata(path; kind=kind, options=options)
    text = join(
        (
            metadata.source_path,
            metadata.source_size,
            metadata.source_mtime,
            metadata.parser_version,
            metadata.package_version,
            metadata.kind,
            metadata.options,
        ),
        "\n",
    )
    return bytes2hex(sha1(collect(codeunits(text))))
end

function _parsed_cache_path(key::AbstractString)
    return joinpath(_cache_subdir(:parsed), string(key, ".jls"))
end

function _parsed_cache_metadata(path::AbstractString; kind::Symbol, options)
    source = abspath(path)
    return (
        source_path=source,
        source_size=filesize(source),
        source_mtime=_source_mtime_ns(source),
        parser_version=PARSED_CACHE_VERSION,
        package_version=_package_version(),
        kind=String(kind),
        options=repr(options),
    )
end

function _source_mtime_ns(path::AbstractString)
    return round(Int, mtime(path) * 1_000_000_000)
end

function _read_parsed_cache(cache_path::AbstractString, expected)
    payload = try
        open(deserialize, cache_path)
    catch
        return nothing
    end

    payload isa NamedTuple || return nothing
    :metadata in keys(payload) || return nothing
    :data in keys(payload) || return nothing
    isequal(payload.metadata, expected) || return nothing
    payload.data isa DataFrame || return nothing
    return copy(payload.data)
end

function _write_parsed_cache(cache_path::AbstractString, metadata, data::DataFrame)
    mkpath(dirname(cache_path))
    payload = (metadata=metadata, data=copy(data))
    open(cache_path, "w") do io
        serialize(io, payload)
    end
    return cache_path
end
