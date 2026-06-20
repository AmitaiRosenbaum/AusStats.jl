# [API Reference](@id api-reference)

This page documents the full public API for AusStats.jl.

## Discovery

```@docs
providers
datasets
datafiles
search_data
search_abs
catalogues
files
releases
refresh_abs!
search_rba
rba_tables
rba_files
```

## Downloading

```@docs
download_data
download_abs
download_cube
download_rba
```

## Reading

```@docs
read_data
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
read_rba
read_rba_cash_rate
read_rba_balance_sheet
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
