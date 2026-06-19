# Reading Tables

ABS workbooks often contain many sheets. [`read_abs`](@ref) provides a forgiving `tables` filter so you can select the sheet or sheets you want without needing to know the exact sheet name.

## Read the First Sheet

When no `sheet` or `tables` argument is supplied, [`read_abs`](@ref) reads the first worksheet.

```julia
df = read_abs("6202.0")
```

## Select Tables by Name or Number

The `tables` filter is forgiving:

- case-insensitive
- ignores spaces
- accepts integers or strings
- matches table numbers embedded in sheet names

These calls are all valid:

```julia
read_abs("6202.0"; tables=["1"])
read_abs("6202.0"; tables=["Table 1"])
read_abs("6202.0"; tables=["Data1"])
read_abs("6202.0"; tables=1)
```

If multiple sheets match, the result is combined into one `DataFrame` and a `table` column is added with the source sheet name.

```julia
df = read_abs("6202.0"; tables=["1", "2"])
```

## Read a Specific Sheet

You can still select an exact worksheet with `sheet`:

```julia
df = read_abs("6202.0"; sheet="Data1")
```

Use `tables` when you want forgiving matching. Use `sheet` when you know the exact worksheet name.

## Header Rows

Some ABS sheets include notes or title rows above the tabular data. The parser attempts to detect a header row automatically, but you can override it:

```julia
df = read_abs("6202.0"; tables=1, header_row=10)
```

## Reading URLs or Local Files

[`read_abs`](@ref) accepts:

- supported catalogue numbers, such as `"6202.0"`
- local workbook paths
- direct workbook URLs

```julia
path = download_abs("6401.0")
df = read_abs(path)
```
