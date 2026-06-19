# Cache Management

AusStats.jl caches indexes, workbooks, data cubes, parsed
`DataFrame`s, and API metadata under the package cache directory.

## Cache Location

```julia
default_cache_dir()
```

The default location is managed by Scratch.jl.

## Inspect Cached Files

```julia
cache_info()
```

The result includes:

- `kind`
- `file`
- `path`
- `size`
- `modified`

## Clear Cached Files

Clear everything:

```julia
clear_cache!()
```

Clear one group:

```julia
clear_cache!(:indexes)
clear_cache!(:workbooks)
clear_cache!(:cubes)
clear_cache!(:parsed)
clear_cache!(:api)
```

The function returns the number of files removed.

## Parsed Data Cache

Parsed `DataFrame` outputs are cached by default for [`read_abs`](@ref),
[`read_abs_local`](@ref), [`read_abs_url`](@ref), and [`read_cube`](@ref).
They are stored with Julia's native `Serialization` format.

```julia
df = read_abs("6202.0"; tables=1)
```

The parsed cache key includes the source workbook identity, file size, modified
time, parser version, package version, and read options such as `tables`,
`tidy`, and cube parser family. If the source workbook changes, the cache key
changes and the workbook is parsed again.

Disable parsed caching for a read:

```julia
df = read_abs("6202.0"; tables=1, cache_parsed=false)
```

Force a reparse and overwrite the current parsed cache entry:

```julia
df = read_abs("6202.0"; tables=1, refresh=true)
```

`refresh=true` does not delete unrelated cache entries. Use `clear_cache!` when
you want to remove cached files:

```julia
clear_cache!(:parsed)
clear_cache!(:api)
```

For reproducible projects, record the package version, the requested catalogue
or release date, and the relevant cached source workbook from `cache_info()`.
