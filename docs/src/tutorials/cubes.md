# Data Cubes

ABS data cubes vary more than standard time-series workbooks. AustralianStatistics.jl treats them as practical table-shaped `DataFrame`s rather than forcing every cube into one tidy schema.

## Search For Cubes

```julia
search_cubes("labour")
```

Limit the search to one catalogue:

```julia
search_cubes("gross flows"; cat_no="6202.0")
```

## Download A Cube

```julia
path = download_cube("6202.0"; cube="gross flows")
```

The `cube` keyword can match a file title or filename.

## Read A Cube

```julia
cube = read_cube(path)
```

You can also read from a catalogue number or URL:

```julia
cube = read_cube("6202.0"; cube="gross flows")

cube = read_cube("https://www.abs.gov.au/path/to/cube.xlsx")
```

The result includes a `sheet` column so rows can be traced back to their workbook sheet.
