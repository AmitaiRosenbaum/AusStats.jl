# Metadata

ABS time-series workbooks store series metadata above the observation rows. AusStats.jl extracts that metadata into columns.

## Read Observation Data

```julia
df = read_abs("6202.0"; tables=1)
```

Common columns include:

- `cat_no`
- `release_date`
- `table`
- `table_no`
- `table_title`
- `sheet`
- `sheet_no`
- `date`
- `series_id`
- `value`
- `unit`
- `series_type`
- `data_type`
- `frequency`
- `collection_month`
- `series_start`
- `series`
- `source_workbook` (metadata-only reads)

## Read Metadata Only

Use [`read_metadata`](@ref) to return one row per series:

```julia
metadata = read_metadata("6202.0"; tables=1)
```

This is useful for finding series ids, units, and adjustment types before downloading or analysing a full table.

`read_metadata` also handles metadata-only sheets that contain series headers but
no observation rows. It extracts catalogue and release information, table titles,
sheet names, table numbers, units, frequencies, and the source workbook path when
those values are available. Empty notes sheets are ignored.

The metadata result is intentionally a `DataFrame`, not a custom metadata
object, so it can be filtered and joined with observation data:

```julia
metadata = read_metadata("6401.0"; tables=1)
cpi_series = metadata[metadata.frequency .== "quarterly", :]
```

Local paths and URLs use the same extraction path:

```julia
metadata = read_metadata("data/cpi.xlsx"; tables="Table 1")
```

## Periods And Frequency

ABS labels such as `Jan-2024`, `2024-01`, `2024-Q1`, `Q1 2024`, and `2024` are converted to `Date` values representing the period start. Frequency is reported as `monthly`, `quarterly`, `annual`, or `unknown`.

When the workbook has no usable observation rows, `read_metadata` still tries to
extract sheet-level and series-level metadata. Parser failures are isolated to
the affected workbook or sheet and reported with the source path.
