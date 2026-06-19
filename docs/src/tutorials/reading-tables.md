# Reading Tables

ABS time-series workbooks often contain many sheets. [`read_abs`](@ref) provides a forgiving `tables` filter so you can select sheets without knowing the exact workbook name.

## Tidy Reads

Tidy reads are the default:

```julia
df = read_abs("6202.0"; tables=1)
```

The output is long-format time-series data with source table and sheet metadata.
Each non-date workbook column becomes its own ABS series, and workbook metadata
rows are converted into columns such as `series_id`, `unit`, `series_type`,
`data_type`, `frequency`, and `series`.

Parsed outputs are cached by default. Use `cache_parsed=false` to disable this
for one read, or `refresh=true` to force a reparse.

## Forgiving Table Matching

The `tables` keyword:

- is case-insensitive
- ignores spaces
- accepts integers or strings
- matches table numbers embedded in sheet names

These are equivalent for a workbook with a `Data1` sheet:

```julia
read_abs("6202.0"; tables=["1"])
read_abs("6202.0"; tables=["Table 1"])
read_abs("6202.0"; tables=["Data1"])
read_abs("6202.0"; tables=1)
```

Read multiple tables by passing a vector:

```julia
df = read_abs("6202.0"; tables=[1, 2])
```

## Catalogue Numbers, Local Files, And URLs

Use the same workflow for supported source types:

```julia
read_abs("6202.0"; tables=1)

path = download_abs("6202.0")
read_abs_local(path; tables=1)

read_abs_url("https://www.abs.gov.au/path/to/workbook.xlsx"; tables=1)
```

`read_abs` dispatches by source shape: URLs are downloaded, existing local files
are read directly, and other strings are treated as catalogue numbers.

## Reading Multiple Local Workbooks

Pass a vector of paths to combine local workbooks:

```julia
df = read_abs_local(["january.xlsx", "february.xlsx"]; tables=1)
```

Pass a directory to read all `.xls` and `.xlsx` files directly inside it:

```julia
df = read_abs_local("data/abs"; tables=1)
```

Subdirectories are ignored by default. Enable recursive discovery explicitly:

```julia
df = read_abs_local("data/abs"; tables=1, recursive=true)
```

When a directory contains a `workbooks` subdirectory, such as the package cache
layout, that directory is included in a non-recursive read. Combined results
include `source_file` alongside the existing sheet and table provenance.

Invalid paths, empty directories, unsupported file types, and mixed invalid
vector inputs raise `ArgumentError`s with the offending path included.

## Raw Sheet Reads

Set `tidy=false` to read the first matched sheet as a raw table.

```julia
raw = read_abs("6202.0"; tables=1, tidy=false)
```

Raw reads are useful when you are inspecting an unfamiliar workbook layout.

## Reading From The Cache

The default cache has subdirectories for workbooks and cubes. You can read a
cached catalogue folder directly when you want to combine several downloaded
workbooks:

```julia
cache = default_cache_dir()
df = read_abs_local(joinpath(cache, "workbooks"); tables=1)
```

No local read performs network access. Use `download_abs`, `download_cube`, or a
URL reader explicitly when a file needs to be fetched.
