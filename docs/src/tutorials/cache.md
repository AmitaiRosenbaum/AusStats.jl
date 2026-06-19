# Cache Management

Downloaded ABS workbooks are stored in a package cache managed by Scratch.jl.

## Cache Location

Use [`default_cache_dir`](@ref) to see where files are cached:

```julia
default_cache_dir()
```

This is the default destination used by [`download_abs`](@ref).

## Inspect Cached Files

Use [`cache_info`](@ref):

```julia
cache_info()
```

The result is a `DataFrame` with:

- `file`
- `path`
- `size`
- `modified`

## Reuse or Force Downloads

By default, downloads are reused:

```julia
path = download_abs("6202.0")
```

Force a fresh download:

```julia
path = download_abs("6202.0"; force=true)
```

You can also choose a different destination:

```julia
path = download_abs("6202.0"; dest=tempdir())
```

## Clear the Cache

Use [`clear_cache!`](@ref) to remove cached package files:

```julia
clear_cache!()
```

The function returns the number of cached files removed.
