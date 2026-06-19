# AusStats.jl

AusStats.jl helps Julia users discover, download, read, and tidy
Australian Bureau of Statistics data.

The package is DataFrame-first. It keeps the generic workflows composable while
also providing convenience readers for common ABS publication families.

## Installation

From a local checkout:

```julia
pkg> dev .
```

## Common Workflow

```julia
using AusStats
using Dates

search_abs("labour")
files("6202.0")

df = read_abs("6202.0"; tables=1)
metadata = read_metadata("6202.0"; tables=1)
series = read_series("A84423043A"; cat_no="6202.0")

latest_date(df)
```

`read_abs` returns tidy long-format time-series data by default: one row per
series-date observation, with ABS metadata such as `series_id`, `unit`,
`frequency`, `series_type`, `table_no`, and `table_title` preserved where
available.

## Discovery, Downloads, And Historical Releases

```julia
catalogues()
refresh_abs!()

current = download_abs("6202.0")
historical = download_abs("6345.0"; release=Date(2019, 9, 1))

releases("6345.0")
```

Downloads are cached. Use `force=true` to redownload a workbook.

## Local Files, URLs, Vectors, And Directories

```julia
read_abs_local(current; tables=1)
read_abs_url("https://www.abs.gov.au/path/to/workbook.xlsx"; tables=1)

read_abs_local(["jan.xlsx", "feb.xlsx"]; tables=1)
read_abs_local("data/abs"; tables=1, recursive=true)
```

Set `tidy=false` when you need a raw sheet-shaped read for inspection.

## Cubes, API, And Convenience Readers

```julia
cube = read_cube("6202.0"; cube="gross flows")
cube_files("6202.0")

structure = datastructure("CPI")
observations = read_api("CPI"; filters=(measure="1",), start_period="2024-Q1")

cpi = read_cpi(; table=1)
grossflows = read_lfs_grossflows()
```

The generic APIs remain the source of truth; convenience readers forward to
`read_abs` or `read_cube` with documented catalogue defaults.

## Cache And Reproducibility

```julia
default_cache_dir()
cache_info()
clear_cache!(:workbooks)
clear_cache!(:parsed)
clear_cache!()
```

Parsed `DataFrame` outputs are cached by default. The cache key includes source
workbook identity, file size, modified time, parser version, package version,
and read options. Pass `cache_parsed=false` for a one-off uncached read or
`refresh=true` to force a reparse.

Offline tests are deterministic. Online integration tests are opt-in:

```julia
ENV["AusStats_ONLINE_TESTS"] = "true"
include("test/runtests.jl")
```
