# Cache Management

AustralianStatistics.jl caches indexes, workbooks, data cubes, and API metadata under the package cache directory.

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
clear_cache!(:api)
```

The function returns the number of files removed.
