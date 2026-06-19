# Getting Started

This tutorial shows the basic workflow: find a catalogue, download its workbook, read a table, and produce tidy data.

## Load the Package

```julia
using AustralianStatistics
using DataFrames
```

## Search for a Publication

Use [`search_abs`](@ref) to search the local catalogue map. Search is case-insensitive and matches catalogue number, title, and description.

```julia
search_abs("labour")
```

The result is a `DataFrame` with:

- `cat_no`
- `title`
- `description`
- `supported`

For example, searching for `"labour"` returns the supported Labour Force catalogue `6202.0`.

## Download a Workbook

Use [`download_abs`](@ref) with a supported ABS catalogue number:

```julia
path = download_abs("6202.0")
```

The workbook is saved in the package cache. If the file already exists, it is reused by default.

To force a fresh download:

```julia
path = download_abs("6202.0"; force=true)
```

## Read an ABS Table

Use [`read_abs`](@ref) with `tables` to read ABS time-series sheets into tidy long format.

```julia
df = read_abs("6202.0"; tables=["1"])
```

The result has one row per series-date observation. Metadata rows such as `Unit`, `Series Type`, `Data Type`, `Frequency`, and `Series ID` are extracted into columns, not returned as data rows.

You can still read the first worksheet as a raw table by omitting `tables`:

```julia
df = read_abs(path)
```

## Produce Tidy Time-Series Data

Use [`tidy_abs`](@ref) to convert an ABS workbook into long-form data.

```julia
tidy = tidy_abs(path)
```

The tidy output includes metadata columns where they can be found:

- `table`
- `date`
- `series_id`
- `value`
- `unit`
- `series_type`
- `data_type`
- `frequency`
- `series`

## Find a Single Series

Use [`read_abs_series`](@ref) when you know the ABS series identifier.

```julia
series = read_abs_series("A84423043A"; cat_no="6202.0")
```

If you omit `cat_no`, the package searches all currently supported catalogues:

```julia
series = read_abs_series("A84423043A")
```
