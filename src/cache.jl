"""
    default_cache_dir()

Return the cache directory used for downloaded ABS workbooks.
"""
function default_cache_dir()
    return Scratch.@get_scratch!("cache")
end

"""
    cache_info()

Return a `DataFrame` describing files currently stored in the package cache.
"""
function cache_info()
    dir = default_cache_dir()
    info = DataFrame(file=String[], path=String[], size=Int64[], modified=DateTime[])

    isdir(dir) || return info

    for path in sort(_cache_entries(dir))
        isfile(path) || continue
        push!(info, (basename(path), path, filesize(path), unix2datetime(mtime(path))))
    end

    return info
end

"""
    clear_cache!()

Delete cached files for this package.
"""
function clear_cache!()
    dir = default_cache_dir()
    isdir(dir) || return 0

    removed = 0
    for path in _cache_entries(dir)
        rm(path; force=true, recursive=true)
        removed += 1
    end

    return removed
end

function _cache_entries(dir::AbstractString)
    return [joinpath(root, file) for (root, _, files) in walkdir(dir) for file in files]
end
