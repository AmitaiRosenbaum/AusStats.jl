"""
    search_cubes(query; cat_no=nothing, refresh=false)

Search known ABS data cube files.
"""
function search_cubes(query::AbstractString; cat_no=nothing, refresh::Bool=false)
    cubes = cube_files(cat_no; refresh)
    needle = lowercase(strip(query))
    isempty(needle) && return cubes

    keep = map(eachrow(cubes)) do row
        haystack = lowercase(join((
            row.cat_no,
            row.title,
            row.description,
            row.file_title,
            row.table_title,
            row.filename,
            row.url,
        ), " "))
        occursin(needle, haystack)
    end

    return cubes[keep, :]
end

"""
    cube_files(cat_no=nothing; release=nothing, refresh=false)

Return known ABS data cube files. When `cat_no` is supplied, only cube files for
that catalogue are returned. Pass a `Date` release to inspect files discovered
for a historical release.
"""
function cube_files(cat_no=nothing; release=nothing, refresh::Bool=false)
    df = if release isa Date
        cat_no === nothing && throw(ArgumentError("cat_no is required when release is a Date"))
        _files_for_release(string(cat_no), release; refresh, strict=refresh)
    elseif release === nothing
        cat_no === nothing ? files(; refresh) : files(cat_no; refresh)
    else
        all_files = cat_no === nothing ? files(; refresh) : files(cat_no; refresh)
        release_key = lowercase(strip(string(release)))
        all_files[lowercase.(all_files.release_date) .== release_key, :]
    end

    isempty(df) && return df
    return df[df.is_cube, :]
end

"""
    read_cube(source; cube=nothing, release=:latest, cache=true, family=:auto)

Read an ABS data cube from a catalogue number, URL, or local workbook path.
Data cubes are returned as `DataFrame`s with source workbook and sheet
provenance. `family=:auto` tries known cube parsers before falling back to the
generic sheet-shaped parser. Use `family=:generic` to force the fallback parser.
"""
function read_cube(source::AbstractString; cube=nothing, release=:latest, cache::Bool=true, family::Symbol=:auto)
    path, metadata = if _is_url(source)
        dest = cache ? _cache_subdir(:cubes) : mktempdir()
        (_download_file(source; dest, force=!cache), _cube_metadata(; url=source))
    elseif isfile(source)
        (source, _cube_metadata())
    else
        row = _select_file(source; file=cube, release, cube=true)
        downloaded = cache ? download_cube(source; cube, release) :
            _download_file(row.url; dest=mktempdir(), filename=row.filename, force=true)
        (downloaded, _cube_metadata(row))
    end

    return _read_cube_workbook(path; family, metadata)
end

function _read_cube_workbook(path::AbstractString; family::Symbol=:auto, metadata=_cube_metadata())
    family in (:auto, :generic, :labelled_matrix) || throw(ArgumentError("unsupported cube parser family `$family`; expected :auto, :generic, or :labelled_matrix"))
    out = DataFrame()
    source_file = abspath(path)

    XLSX.openxlsx(path) do xf
        for sheetname in XLSX.sheetnames(xf)
            rows = _sheet_rows(xf[sheetname])
            _cube_notes_sheet(sheetname, rows) && continue
            table = if family == :generic
                _read_generic_cube_sheet(rows, sheetname, source_file, metadata)
            elseif family == :labelled_matrix
                _read_labelled_matrix_cube_sheet(rows, sheetname, source_file, metadata)
            else
                parsed = _read_labelled_matrix_cube_sheet(rows, sheetname, source_file, metadata)
                isempty(parsed) ? _read_generic_cube_sheet(rows, sheetname, source_file, metadata) : parsed
            end
            isempty(table) && continue
            if isempty(out)
                out = table
            else
                append!(out, table; cols=:union)
            end
        end
    end

    return out
end

function _read_generic_cube_sheet(rows, sheetname::AbstractString, source_file::AbstractString, metadata)
    table = _read_rows_as_sheet(rows)
    isempty(table) && return table
    _add_cube_provenance!(table, sheetname, source_file, metadata)
    return table
end

function _read_rows_as_sheet(rows; header_row::Union{Int,Nothing}=nothing)
    clean_rows = [row for row in rows if !_row_is_empty(row)]
    isempty(clean_rows) && return DataFrame()

    first_data_row = something(header_row, _detect_header_row(clean_rows))
    names = _column_names(clean_rows[first_data_row])
    data_rows = clean_rows[(first_data_row + 1):end]

    table = DataFrame([name => Any[] for name in names])
    for row in data_rows
        _cube_footer_row(row) && break
        values = Any[_clean_cell(get(row, i, missing)) for i in eachindex(names)]
        push!(table, values)
    end

    return table
end

function _read_labelled_matrix_cube_sheet(rows, sheetname::AbstractString, source_file::AbstractString, metadata)
    header_row = _cube_matrix_header_row(rows)
    header_row === nothing && return DataFrame()

    header = rows[header_row]
    period_cols = [index for (index, value) in enumerate(header) if _parse_abs_period(value) !== nothing]
    isempty(period_cols) && return DataFrame()

    first_period_col = minimum(period_cols)
    dimension_cols = [index for index in 1:(first_period_col - 1) if !_empty_series_value(get(header, index, missing))]
    isempty(dimension_cols) && return DataFrame()

    dimension_names = _cube_dimension_names(header, dimension_cols)
    out = DataFrame(
        source_file = String[],
        cat_no = Union{Missing,String}[],
        release_date = Union{Missing,String}[],
        cube = Union{Missing,String}[],
        cube_title = Union{Missing,String}[],
        sheet = String[],
        date = Date[],
        frequency = String[],
        value = Union{Missing,Float64}[],
    )
    for name in dimension_names
        out[!, name] = Union{Missing,String}[]
    end

    for row in rows[(header_row + 1):end]
        _row_is_empty(row) && continue
        _cube_footer_row(row) && break

        dimensions = [_clean_text(get(row, col, missing)) for col in dimension_cols]
        all(isempty, dimensions) && continue

        for period_col in period_cols
            period = _parse_abs_period(get(header, period_col, missing))
            period === nothing && continue
            value = _parse_abs_float(get(row, period_col, missing))
            record = Any[
                source_file,
                metadata.cat_no,
                metadata.release_date,
                metadata.cube,
                metadata.cube_title,
                sheetname,
                period.date,
                period.frequency,
                value,
            ]
            append!(record, [isempty(value) ? missing : value for value in dimensions])
            push!(out, record)
        end
    end

    return out
end

function _cube_matrix_header_row(rows)
    for (index, row) in enumerate(rows)
        period_cols = [col for (col, value) in enumerate(row) if _parse_abs_period(value) !== nothing]
        isempty(period_cols) && continue
        first_period_col = minimum(period_cols)
        first_period_col > 1 || continue
        dimension_labels = count(col -> !_empty_series_value(get(row, col, missing)), 1:(first_period_col - 1))
        dimension_labels > 0 || continue
        return index
    end

    return nothing
end

function _cube_dimension_names(header, dimension_cols)
    raw_names = [_clean_text(get(header, col, missing)) for col in dimension_cols]
    names = Symbol[]
    seen = Dict{Symbol,Int}()

    for (index, raw_name) in enumerate(raw_names)
        base = isempty(raw_name) ? Symbol("dimension_$index") : Symbol(_normalise_name(raw_name))
        count = get(seen, base, 0) + 1
        seen[base] = count
        push!(names, count == 1 ? base : Symbol("$(base)_$count"))
    end

    return names
end

function _cube_footer_row(row)
    text = lowercase(strip(join((_clean_text(value) for value in row if !_empty_series_value(value)), " ")))
    isempty(text) && return false
    return startswith(text, "note") ||
        startswith(text, "source") ||
        startswith(text, "footnote") ||
        startswith(text, "comments") ||
        startswith(text, "©") ||
        occursin("cells in this table", text)
end

function _cube_notes_sheet(sheetname::AbstractString, rows)
    name = lowercase(strip(sheetname))
    occursin("note", name) && return true
    occursin("contents", name) && return true
    occursin("cover", name) && return true

    for row in rows[1:min(length(rows), 3)]
        text = lowercase(strip(join((_clean_text(value) for value in row if !_empty_series_value(value)), " ")))
        isempty(text) && continue
        startswith(text, "note") && return true
        startswith(text, "explanatory") && return true
    end

    return false
end

function _cube_metadata(; cat_no=missing, release_date=missing, cube=missing, cube_title=missing, url=missing)
    title = ismissing(cube_title) && !ismissing(url) ? basename(split(string(url), "?")[1]) : cube_title
    return (
        cat_no = _missing_or_string(cat_no),
        release_date = _missing_or_string(release_date),
        cube = _missing_or_string(cube),
        cube_title = _missing_or_string(title),
    )
end

function _cube_metadata(row::DataFrameRow)
    return _cube_metadata(;
        cat_no = row.cat_no,
        release_date = row.release_date,
        cube = row.filename,
        cube_title = row.file_title,
    )
end

function _add_cube_provenance!(table::DataFrame, sheetname::AbstractString, source_file::AbstractString, metadata)
    table[!, :source_file] = fill(source_file, nrow(table))
    table[!, :cat_no] = fill(metadata.cat_no, nrow(table))
    table[!, :release_date] = fill(metadata.release_date, nrow(table))
    table[!, :cube] = fill(metadata.cube, nrow(table))
    table[!, :cube_title] = fill(metadata.cube_title, nrow(table))
    table[!, :sheet] = fill(sheetname, nrow(table))
    return table
end
