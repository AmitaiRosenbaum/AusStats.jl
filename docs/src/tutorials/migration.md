# Workflow Migration

The generic functions are the most flexible way to work with ABS data. The
convenience readers are shorter entry points for common catalogue families.
They use the same internals and return the same output shapes.

## Start With Generic Workflows

When exploring an unfamiliar publication, start with discovery:

```julia
search_abs("payroll jobs")
files("6160.0.55.001"; refresh=true)
```

Then read a specific table:

```julia
payrolls = read_abs("6160.0.55.001"; tables=1)
```

For cubes:

```julia
search_cubes("gross flows"; cat_no="6202.0")
grossflows = read_cube("6202.0"; cube="gross flows")
```

## Move To Convenience Readers

Once the workflow is known, the convenience reader can make scripts clearer:

```julia
payrolls = read_payrolls(; table=1)
grossflows = read_lfs_grossflows()
```

The convenience readers keep the same keyword style:

```julia
cpi = read_cpi(;
    release=Date(2024, 3, 1),
    table=1,
    cache=true,
    cache_parsed=true,
)
```

## When To Stay Generic

Use the generic APIs when you need:

- a catalogue without a convenience reader
- a direct ABS URL
- a local workbook, vector of workbooks, or directory
- an explicit file selector
- a cube family or parser setting
- raw sheet inspection with `tidy=false`

```julia
raw = read_abs("6202.0"; tables=1, tidy=false)
local = read_abs_local("data/abs"; recursive=true)
cube = read_cube("6202.0"; cube="gross flows", family=:generic)
```

The package is inspired by established ABS spreadsheet workflows, but the API is
intended to feel natural in Julia: typed keywords, small composable functions,
and `DataFrame` results throughout.
