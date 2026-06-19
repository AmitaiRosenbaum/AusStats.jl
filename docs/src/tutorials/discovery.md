# Discovery

AustralianStatistics.jl keeps a local index of ABS catalogues and downloadable files. Seed entries are available offline, and [`refresh_abs!`](@ref) can update the index from ABS publication pages.

## Search

```julia
search_abs("wage price")
```

Search matches catalogue numbers, titles, descriptions, file titles, and filenames.

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

## Refresh The Index

```julia
refresh_abs!()
```

Refreshing uses the ABS website and writes the discovered index into the package cache. If the network is unavailable, seed catalogue entries remain available.
