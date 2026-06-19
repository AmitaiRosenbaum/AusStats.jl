# Discovery

AustralianStatistics.jl keeps a local index of ABS catalogues and downloadable files. Seed entries are available offline, and [`refresh_abs!`](@ref) can update the index from ABS publication pages.

## Search

```julia
search_abs("wage price")
```

Search matches catalogue numbers, titles, descriptions, file titles, and filenames.

The result is a `DataFrame` with catalogue metadata and downloadable-file
metadata where available, including `cat_no`, `title`, `description`,
`release_date`, `file_title`, `url`, `filename`, `file_type`, `table_no`,
`table_title`, `is_timeseries`, and `is_cube`.

## List Catalogues

```julia
catalogues()
```

Refresh the index first:

```julia
catalogues(; refresh=true)
```

## List Files

```julia
files("6202.0")
```

The file index includes release information, URLs, file titles, filenames, and flags for time-series workbooks or data cubes.

Use the file index to inspect ABS structure before reading:

```julia
lf_files = files("6202.0"; refresh=true)
lf_files[:, [:cat_no, :release_date, :file_title, :table_no, :is_cube]]
```

## List Releases

Use [`releases`](@ref) to inspect known release pages for a catalogue:

```julia
releases("6345.0")
```

Release dates are returned as `Date` values representing the release month.

Download a historical workbook by passing a `Date`:

```julia
download_abs("6345.0"; release=Date(2019, 9, 1))
```

If an exact release is not available, the error message includes nearby known
release dates where discovery has found them.

## Refresh The Index

```julia
refresh_abs!()
```

Refreshing uses the ABS website and writes the discovered index into the package cache. If the network is unavailable, seed catalogue entries remain available.

Use `refresh=true` on discovery functions for one call, or `refresh_abs!()` when
you want to update the cached file index explicitly:

```julia
search_abs("cpi"; refresh=true)
files("6401.0"; refresh=true)
```
