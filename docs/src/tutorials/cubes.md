# Data Cubes

ABS data cubes vary more than standard time-series workbooks. Use
[`read_abs`](@ref) for regular time-series spreadsheets where ABS series IDs
and dates are already arranged as a time-series workbook. Use cubes when ABS
publishes richer cross-tabulations or detailed dimensions that do not fit the
standard time-series layout.

AustralianStatistics.jl keeps [`read_cube`](@ref) generic, with specialized
parsers for recurring cube layouts where that improves the output.

## Search For Cubes

```julia
search_cubes("labour")
```

Limit the search to one catalogue:

```julia
search_cubes("gross flows"; cat_no="6202.0")
```

List known cube downloads directly:

```julia
cube_files("6202.0")
```

The result is filtered from the same catalogue/file index used by
[`files`](@ref), so it includes catalogue numbers, release labels, URLs,
filenames, file titles, and inferred cube/table titles where discovery can find
them.

## Download A Cube

```julia
path = download_cube("6202.0"; cube="gross flows")
```

The `cube` keyword can match a file title or filename.

Direct URLs are also supported:

```julia
path = download_cube("https://www.abs.gov.au/path/to/cube.xlsx")
```

Use a historical release where ABS archive discovery can identify cube files:

```julia
path = download_cube("6202.0"; cube="gross flows", release=Date(2024, 1, 1))
```

## Read A Cube

```julia
cube = read_cube(path)
```

You can also read from a catalogue number or URL:

```julia
cube = read_cube("6202.0"; cube="gross flows")

cube = read_cube("https://www.abs.gov.au/path/to/cube.xlsx")
```

The result includes provenance columns such as `source_file`, `sheet`,
`cat_no`, `release_date`, `cube`, and `cube_title` where they are known.

## Parser Families

The default `family=:auto` tries specialized parsers first and falls back to the
generic sheet reader when a sheet does not match a known cube layout.

```julia
cube = read_cube(path; family=:auto)
```

Use `family=:generic` to inspect the workbook in a sheet-shaped form:

```julia
raw_cube = read_cube(path; family=:generic)
```

For recurring labelled matrix cubes, where dimension columns are followed by
period columns, `family=:auto` returns a long table with `date`, `frequency`,
`value`, dimension columns, and source metadata.

## Cubes Versus Time-Series Workbooks

Use [`read_abs`](@ref) when the ABS file is a standard time-series workbook with
series IDs and dates. Use [`read_cube`](@ref) when the file is a data cube with
richer dimensions, cross-tabulations, or non-standard workbook structure.

```julia
timeseries = read_abs("6202.0"; tables=1)
cube = read_cube("6202.0"; cube="gross flows")
```
