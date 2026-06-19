# [API Reference](@id api-reference)

This page documents the full public API for AusStats.jl.

## Discovery

```@docs
search_abs
catalogues
files
releases
refresh_abs!
```

## Downloading

```@docs
download_abs
download_cube
```

## Reading

```@docs
read_abs
read_abs_local
read_abs_url
tidy_abs
read_metadata
read_series
separate_series
latest_date
search_cubes
cube_files
read_cube
```

## Convenience Readers

```@docs
read_cpi
read_awe
read_erp
read_job_mobility
read_payrolls
read_lfs_grossflows
read_lfs_cube
```

## ABS API

```@docs
dataflows
datastructure
api_key
read_api
read_api_url
```

## Cache

```@docs
default_cache_dir
cache_info
clear_cache!
```
