# Getting Started

This tutorial covers the shortest path from search to tidy ABS time-series data.

## Load The Package

```julia
using AusStats
using DataFrames
using Dates
```

## Find A Publication

Use [`search_abs`](@ref) to search catalogue numbers, publication titles, descriptions, and known downloadable files.

```julia
search_abs("labour")
```

Use [`catalogues`](@ref) to list known catalogues:

```julia
catalogues()
```

## Read Tidy Time-Series Data

[`read_abs`](@ref) accepts a catalogue number and returns tidy long-format observations by default.

```julia
df = read_abs("6202.0"; tables=1)
```

The result has one row per series-date observation. Metadata rows from the workbook, such as `Series ID`, `Unit`, `Frequency`, and `Series Type`, become columns rather than data rows.

Typical columns include `table`, `date`, `series_id`, `value`, `unit`,
`series_type`, `data_type`, `frequency`, and `series`. Additional catalogue,
release, sheet, table-title, and source-file fields are included when they can
be inferred.

## Download First, Read Later

Downloads are cached.

```julia
path = download_abs("6202.0")

df = read_abs_local(path; tables=1)
```

Force a fresh download when needed:

```julia
path = download_abs("6202.0"; force=true)
```

Read a historical release with a `Date` when ABS archive pages expose the
release:

```julia
wpi_2019 = read_abs("6345.0"; release=Date(2019, 9, 1), tables=2)
```

## Inspect Metadata

Use [`read_metadata`](@ref) when you want one row per series rather than one row per observation.

```julia
metadata = read_metadata("6202.0"; tables=1)
```

## Find One Series

If you know the ABS series identifier, use [`read_series`](@ref):

```julia
series = read_series("A84423043A"; cat_no="6202.0")
```

Series matching is case-insensitive.

## Use A Convenience Reader

Once you know the publication family you need, convenience readers wrap the same
generic readers:

```julia
cpi = read_cpi(; table=1)
grossflows = read_lfs_grossflows()
```

Use the generic APIs when you need direct URLs, local files, directory reads, or
unusual file selection.
