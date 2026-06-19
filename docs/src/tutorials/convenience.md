# Convenience Readers

The generic readers, [`read_abs`](@ref) and [`read_cube`](@ref), are the source
of truth. Convenience readers provide short, Julian entry points for common ABS
families while keeping the same output formats.

## Time-Series Workbooks

Each time-series convenience reader returns the same tidy long-format
`DataFrame` as `read_abs` by default. Use `table` to select workbook sheets.

```julia
cpi = read_cpi(; table=1)
awe = read_awe(; table=1)
erp = read_erp(; table=1)
jobs = read_job_mobility(; table=1)
payrolls = read_payrolls(; table=1)
```

The catalogue defaults are:

- `read_cpi`: Consumer Price Index, Australia (`6401.0`)
- `read_awe`: Average Weekly Earnings, Australia (`6302.0`)
- `read_erp`: National, state and territory population / ERP (`3101.0`)
- `read_job_mobility`: Job Mobility, Australia (`6226.0`)
- `read_payrolls`: Weekly Payroll Jobs and Wages in Australia (`6160.0.55.001`)

Pass a historical release with a `Date` where the ABS archive can be discovered:

```julia
cpi = read_cpi(; release=Date(2024, 3, 1), table=1)
```

Set `tidy=false` to inspect the raw workbook sheet:

```julia
raw = read_cpi(; table=1, tidy=false)
```

## Labour Force Cubes

Labour Force cube helpers return the same practical sheet-shaped `DataFrame` as
[`read_cube`](@ref).

```julia
grossflows = read_lfs_grossflows()
cube = read_lfs_cube(; cube="detailed")
```

Use `refresh=true` if you want to refresh the local ABS file index before
selecting a file:

```julia
grossflows = read_lfs_grossflows(; refresh=true)
```

For less common catalogues, unusual file choices, or direct URLs, use the
generic readers:

```julia
df = read_abs("6202.0"; tables=1)
cube = read_cube("6202.0"; cube="gross flows")
```

## Choosing The Right Reader

Convenience readers are useful in scripts and notebooks once the ABS family is
known. Generic readers are better during exploration because they expose
catalogue discovery, file selection, local paths, URLs, and directory inputs.

```julia
files("6401.0"; refresh=true)
cpi = read_cpi(; table=1)
```

If ABS changes a publication structure, convenience readers raise an informative
error that points back to the generic discovery functions.
