# Getting Started

This tutorial covers the shortest path from search to tidy ABS time-series data.

## Load The Package

```julia
using AustralianStatistics
using DataFrames
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
