"""
    read_abs(source; tables=nothing, release=:latest, tidy=true, cache=true)

Read ABS data from a catalogue number, URL, or local workbook path. Time-series
workbooks are returned as tidy long-format `DataFrame`s by default.
"""
function read_abs(source::AbstractString; tables=nothing, release=:latest, tidy::Bool=true, cache::Bool=true)
    if _is_url(source)
        return read_abs_url(source; tables, tidy, cache)
    elseif isfile(source)
        return read_abs_local(source; tables, tidy)
    end

    row = _select_file(source; release, cube=false)
    path = cache ? download_abs(source; file=row.filename, release) : _download_file(row.url; dest=mktempdir(), filename=row.filename, force=true)
    return _read_workbook(path; tables, tidy, cat_no=row.cat_no, release_date=row.release_date)
end

"""
    read_abs_url(url; tables=nothing, tidy=true, cache=true)

Read an ABS workbook directly from `url`.
"""
function read_abs_url(url::AbstractString; tables=nothing, tidy::Bool=true, cache::Bool=true)
    dest = cache ? _cache_subdir(:workbooks) : mktempdir()
    path = _download_file(url; dest, force=!cache)
    return _read_workbook(path; tables, tidy)
end

"""
    read_abs_local(path; tables=nothing, tidy=true)

Read an ABS workbook from a local file.
"""
function read_abs_local(path::AbstractString; tables=nothing, tidy::Bool=true)
    return _read_workbook(path; tables, tidy)
end

"""
    read_metadata(source; tables=nothing)

Return one row per ABS series with the metadata available in `source`.
"""
function read_metadata(source::AbstractString; tables=nothing)
    df = read_abs(source; tables, tidy=true)
    isempty(df) && return select(df, Not([:date, :value]))
    cols = [name for name in names(df) if name ∉ ("date", "value")]
    return unique(select(df, cols))
end

"""
    read_series(series_id; cat_no=nothing, tables=nothing, release=:latest, cache=true)

Read observations for one or more ABS series identifiers.
"""
function read_series(series_id; cat_no=nothing, tables=nothing, release=:latest, cache::Bool=true)
    ids = series_id isa AbstractString ? [series_id] : collect(series_id)
    needles = Set(lowercase(strip(string(id))) for id in ids)

    catalogue_list = cat_no === nothing ? catalogues().cat_no : (cat_no isa AbstractString ? [cat_no] : collect(cat_no))
    out = _empty_tidy_abs()

    for catalogue in catalogue_list
        df = try
            read_abs(string(catalogue); tables, release, tidy=true, cache)
        catch
            continue
        end
        matches = _series_matches(df, needles)
        isempty(matches) || append!(out, matches)
    end

    return out
end

"""
    separate_series(df; column=:series)

Split a descriptive ABS series column into simple component columns. Components
are split on semicolons, pipes, or repeated comma-separated phrases.
"""
function separate_series(df::DataFrame; column=:series)
    name = Symbol(column)
    hasproperty(df, name) || throw(ArgumentError("column `$column` was not found"))

    parts = [ismissing(value) ? String[] : _series_parts(string(value)) for value in df[!, name]]
    max_parts = maximum(length, parts; init=0)
    out = copy(df)

    for index in 1:max_parts
        out[!, Symbol("$(name)_part_$index")] = [index <= length(row_parts) ? row_parts[index] : missing for row_parts in parts]
    end

    return out
end

"""
    latest_date(df; date=:date)

Return the latest non-missing date in `df`.
"""
function latest_date(df::DataFrame; date=:date)
    name = Symbol(date)
    hasproperty(df, name) || throw(ArgumentError("column `$date` was not found"))
    values = collect(skipmissing(df[!, name]))
    isempty(values) && return missing
    return maximum(values)
end

function _read_workbook(path::AbstractString; tables=nothing, tidy::Bool=true, cat_no=missing, release_date=missing)
    if tidy
        return _read_tidy_workbook(path; tables, cat_no, release_date)
    end

    return _read_raw_workbook(path; tables)
end

function _read_tidy_workbook(path::AbstractString; tables=nothing, cat_no=missing, release_date=missing)
    if tables === nothing
        return tidy_abs(path; cat_no, release_date)
    end

    out = _empty_tidy_abs()
    XLSX.openxlsx(path) do xf
        sheetnames = XLSX.sheetnames(xf)
        selected = _matching_tables(sheetnames, tables)
        for sheetname in selected
            sheet_index = findfirst(==(sheetname), sheetnames)
            table = _tidy_sheet(xf[sheetname], sheetname; cat_no, release_date, sheet_index=something(sheet_index, 1))
            isempty(table) || append!(out, table)
        end
    end
    return out
end

function _read_raw_workbook(path::AbstractString; tables=nothing)
    XLSX.openxlsx(path) do xf
        sheetnames = XLSX.sheetnames(xf)
        selected = tables === nothing ? [first(sheetnames)] : _matching_tables(sheetnames, tables)
        return _read_sheet(xf[first(selected)])
    end
end

function _matching_tables(sheetnames, tables)
    requested = _table_requests(tables)
    matches = String[]

    for request in requested
        append!(matches, [sheetname for sheetname in sheetnames if _table_matches(sheetname, request)])
    end

    unique_matches = unique(matches)
    isempty(unique_matches) && throw(ArgumentError("no sheets matched tables $(collect(requested)); available sheets are: $(join(sheetnames, ", "))"))
    return unique_matches
end

function _table_requests(tables)
    if tables isa Integer || tables isa AbstractString
        return [tables]
    end

    return collect(tables)
end

function _table_matches(sheetname::AbstractString, request)
    sheet_key = _table_key(sheetname)
    request_key = _table_key(request)
    isempty(request_key) && return false

    sheet_key == request_key && return true

    request_number = _request_table_number(request)
    if request_number !== nothing
        return any(number -> number == request_number, _numbers_in_text(sheetname))
    end

    return occursin(request_key, sheet_key)
end

function _table_key(value)
    return replace(lowercase(strip(string(value))), r"\s+" => "")
end

function _request_table_number(value)
    value isa Integer && return string(Int(value))
    text = string(value)
    match_result = match(r"\d+[a-z]?", lowercase(text))
    match_result === nothing && return nothing
    return match_result.match
end

function _numbers_in_text(value)
    return [match.match for match in eachmatch(r"\d+[a-z]?", lowercase(string(value)))]
end

function _series_matches(df::DataFrame, needles::Set{String})
    isempty(df) && return df

    keep = map(df.series_id) do candidate
        lowercase(strip(string(candidate))) in needles
    end

    return df[keep, :]
end

function _series_parts(value::AbstractString)
    delimiter = occursin(";", value) ? r"\s*;\s*" : occursin("|", value) ? r"\s*\|\s*" : r"\s*,\s*"
    parts = [strip(part) for part in split(value, delimiter) if !isempty(strip(part))]
    return parts
end

function _is_url(value::AbstractString)
    text = lowercase(strip(value))
    return startswith(text, "http://") || startswith(text, "https://")
end

function _empty_series_value(value)
    return ismissing(value) || isempty(strip(string(value)))
end
