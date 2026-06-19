"""
    default_cache_dir()

Return the cache directory used for downloaded ABS files and indexes.
"""
function default_cache_dir()
    configured = Preferences.@load_preference("cache_dir", nothing)
    configured === nothing || return String(configured)
    return Scratch.@get_scratch!("cache")
end

"""
    cache_info()

Return a `DataFrame` describing files currently stored in the package cache.
"""
function cache_info()
    dir = default_cache_dir()
    info = DataFrame(kind=String[], file=String[], path=String[], size=Int64[], modified=DateTime[])

    isdir(dir) || return info

    for path in sort(_cache_entries(dir))
        isfile(path) || continue
        push!(info, (_cache_kind(dir, path), basename(path), path, filesize(path), unix2datetime(mtime(path))))
    end

    return info
end

"""
    clear_cache!(what=:all)

Delete cached files for this package. `what` can be `:all`, `:indexes`,
`:workbooks`, `:cubes`, or `:api`.
"""
function clear_cache!(what=:all)
    dir = default_cache_dir()
    isdir(dir) || return 0

    removed = 0
    for path in _cache_entries(dir)
        _cache_matches(dir, path, what) || continue
        rm(path; force=true, recursive=true)
        removed += 1
    end

    return removed
end

function _cache_entries(dir::AbstractString)
    return [joinpath(root, file) for (root, _, files) in walkdir(dir) for file in files]
end

function _cache_subdir(kind::Symbol)
    dir = joinpath(default_cache_dir(), String(kind))
    mkpath(dir)
    return dir
end

function _cache_kind(dir::AbstractString, path::AbstractString)
    rel = relpath(path, dir)
    first_part = first(splitpath(rel))
    return first_part == "." ? "other" : first_part
end

function _cache_matches(dir::AbstractString, path::AbstractString, what)
    what == :all && return true
    kind = Symbol(_cache_kind(dir, path))
    what == kind && return true
    what == :indexes && kind == :indexes && return true
    what == :workbooks && kind == :workbooks && return true
    what == :cubes && kind == :cubes && return true
    what == :api && kind == :api && return true
    return false
end
