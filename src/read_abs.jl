"""
    read_abs(source; tables=nothing, release=:latest, tidy=true, cache=true, cache_parsed=true, refresh=false)

Read ABS data from a catalogue number, URL, or local workbook path. Time-series
workbooks are returned as tidy long-format `DataFrame`s by default. Parsed
`DataFrame`s are cached by default and invalidated when the source workbook,
parser version, package version, or read options change.
"""
function read_abs(source::AbstractString; tables=nothing, release=:latest, tidy::Bool=true, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false)
    if _is_url(source)
        return read_abs_url(source; tables=tables, tidy=tidy, cache=cache, cache_parsed=cache_parsed, refresh=refresh)
    elseif isfile(source)
        return read_abs_local(source; tables=tables, tidy=tidy, cache_parsed=cache_parsed, refresh=refresh)
    end

    refresh && files(source; refresh=true)
    row = _select_file(source; release=release, cube=false)
    path = cache ? download_abs(source; file=row.filename, release=release) : _download_file(row.url; dest=mktempdir(), filename=row.filename, force=true)
    return _read_workbook(path; tables=tables, tidy=tidy, cat_no=row.cat_no, release_date=row.release_date, cache_parsed=cache_parsed, refresh=refresh)
end

"""
    read_abs_url(url; tables=nothing, tidy=true, cache=true, cache_parsed=true, refresh=false)

Read an ABS workbook directly from `url`.
"""
function read_abs_url(url::AbstractString; tables=nothing, tidy::Bool=true, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false)
    dest = cache ? _cache_subdir(:workbooks) : mktempdir()
    path = _download_file(url; dest=dest, force=!cache)
    return _read_workbook(path; tables=tables, tidy=tidy, cache_parsed=cache_parsed, refresh=refresh)
end

"""
    read_abs_local(path; tables=nothing, tidy=true, recursive=false, cache_parsed=true, refresh=false)

Read ABS workbooks from a local file, vector of files, or directory. Directory
reads include `.xls` and `.xlsx` files and are non-recursive by default.
"""
function read_abs_local(path::AbstractString; tables=nothing, tidy::Bool=true, recursive::Bool=false, cache_parsed::Bool=true, refresh::Bool=false)
    if isdir(path)
        paths = _local_workbook_paths(path; recursive)
        return _read_local_workbooks(paths; tables=tables, tidy=tidy, cache_parsed=cache_parsed, refresh=refresh)
    end

    _validate_local_workbook(path)
    return _read_workbook(path; tables=tables, tidy=tidy, cache_parsed=cache_parsed, refresh=refresh)
end

function read_abs_local(paths::AbstractVector; tables=nothing, tidy::Bool=true, recursive::Bool=false, cache_parsed::Bool=true, refresh::Bool=false)
    isempty(paths) && throw(ArgumentError("no local workbook paths were supplied"))

    workbooks = String[]
    for (index, path) in enumerate(paths)
        path isa AbstractString || throw(ArgumentError("local workbook path at index $index must be a string, got $(typeof(path))"))
        if isdir(path)
            append!(workbooks, _local_workbook_paths(path; recursive))
        else
            _validate_local_workbook(path; context="path at index $index")
            push!(workbooks, abspath(path))
        end
    end

    unique!(workbooks)
    isempty(workbooks) && throw(ArgumentError("no local Excel workbooks were found"))
    return _read_local_workbooks(workbooks; tables=tables, tidy=tidy, cache_parsed=cache_parsed, refresh=refresh)
end

"""
    read_metadata(source; tables=nothing)

Return one row per ABS series with the metadata available in `source`.
"""
function read_metadata(source::AbstractString; tables=nothing)
    path, cat_no, release_date = _metadata_source(source)
    return _read_metadata_workbook(path; tables, cat_no, release_date)
end

"""
    read_series(series_id; cat_no=nothing, tables=nothing, release=:latest, cache=true, cache_parsed=true)

Read observations for one or more ABS series identifiers.
"""
function read_series(series_id; cat_no=nothing, tables=nothing, release=:latest, cache::Bool=true, cache_parsed::Bool=true)
    ids = series_id isa AbstractString ? [series_id] : collect(series_id)
    needles = Set(lowercase(strip(string(id))) for id in ids)

    catalogue_list = cat_no === nothing ? catalogues().cat_no : (cat_no isa AbstractString ? [cat_no] : collect(cat_no))
    out = _empty_tidy_abs()

    for catalogue in catalogue_list
        df = try
            read_abs(string(catalogue); tables=tables, release=release, tidy=true, cache=cache, cache_parsed=cache_parsed)
        catch
            continue
        end
        matches = _series_matches(df, needles)
        isempty(matches) || append!(out, matches)
    end

    return out
end

"""
    separate_series(df; column=:series, names=nothing, remove_totals=false, drop_missing=false)

Split a descriptive ABS series column into simple component columns. Components
are split on semicolons, pipes, or repeated comma-separated phrases.

By default, generated columns are named after the source column, for example
`series_part_1`. Pass `names` as a vector of symbols or strings to use custom
column names. Set `remove_totals=true` to drop standalone aggregate labels such
as `Total` or `All groups` from the split components. Set `drop_missing=true`
to remove rows where any split component is missing.
"""
function separate_series(df::DataFrame; column=:series, names=nothing, remove_totals::Bool=false, drop_missing::Bool=false)
    name = Symbol(column)
    hasproperty(df, name) || throw(ArgumentError("column `$column` was not found"))

    parts = [ismissing(value) ? String[] : _series_parts(string(value); remove_totals) for value in df[!, name]]
    max_parts = maximum(length, parts; init=0)
    output_names = _series_part_names(name, max_parts, names)
    out = copy(df)

    for (index, output_name) in enumerate(output_names)
        out[!, output_name] = [index <= length(row_parts) ? row_parts[index] : missing for row_parts in parts]
    end

    return drop_missing && !isempty(output_names) ? dropmissing(out, output_names) : out
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

function _read_workbook(path::AbstractString; tables=nothing, tidy::Bool=true, cat_no=missing, release_date=missing, cache_parsed::Bool=true, refresh::Bool=false)
    options = (tables=tables, tidy=tidy, cat_no=cat_no, release_date=release_date)
    return _with_parsed_cache(path; kind=:read_abs, options=options, cache_parsed=cache_parsed, refresh=refresh) do
        if tidy
            return _read_tidy_workbook(path; tables=tables, cat_no=cat_no, release_date=release_date)
        end

        return _read_raw_workbook(path; tables=tables)
    end
end

function _metadata_source(source::AbstractString)
    if _is_url(source)
        path = _download_file(source; dest=_cache_subdir(:workbooks))
        return (path, missing, something(_release_from_url(source), missing))
    elseif isfile(source)
        return (source, missing, missing)
    elseif ispath(source)
        throw(ArgumentError("metadata source must be a workbook file, not a directory: `$source`"))
    end

    row = _select_file(source; release=:latest, cube=false)
    path = download_abs(source; file=row.filename)
    return (path, row.cat_no, row.release_date)
end

function _read_metadata_workbook(path::AbstractString; tables=nothing, cat_no=missing, release_date=missing)
    _validate_local_workbook(path; context="metadata source")
    out = _empty_abs_metadata()
    source_workbook = abspath(path)

    XLSX.openxlsx(path) do xf
        sheetnames = XLSX.sheetnames(xf)
        selected = tables === nothing ? sheetnames : _matching_tables(sheetnames, tables)
        for sheetname in selected
            sheet_index = findfirst(==(sheetname), sheetnames)
            metadata = try
                _metadata_sheet(
                    xf[sheetname],
                    sheetname;
                    cat_no,
                    release_date,
                    sheet_index=something(sheet_index, 1),
                    source_workbook,
                )
            catch error
                throw(ArgumentError("failed to extract metadata from sheet `$sheetname` in `$path`: $(sprint(showerror, error))"))
            end
            isempty(metadata) || append!(out, metadata)
        end
    end

    return unique(out)
end

function _read_local_workbooks(paths; tables=nothing, tidy::Bool=true, cache_parsed::Bool=true, refresh::Bool=false)
    combined = DataFrame()

    for path in paths
        table = try
            _read_workbook(path; tables=tables, tidy=tidy, cache_parsed=cache_parsed, refresh=refresh)
        catch error
            message = sprint(showerror, error)
            throw(ArgumentError("failed to read local workbook `$path`: $message"))
        end

        table[!, :source_file] = fill(abspath(path), nrow(table))
        if isempty(combined) && ncol(combined) == 0
            combined = table
        else
            append!(combined, table; cols=:union)
        end
    end

    return combined
end

function _local_workbook_paths(directory::AbstractString; recursive::Bool=false)
    ispath(directory) || throw(ArgumentError("local path does not exist: `$directory`"))
    isdir(directory) || throw(ArgumentError("local path is not a directory: `$directory`"))

    roots = recursive ? [root for (root, _, _) in walkdir(directory)] : [directory]
    cache_workbooks = joinpath(directory, "workbooks")
    if !recursive && isdir(cache_workbooks)
        push!(roots, cache_workbooks)
    end

    paths = String[]
    for root in unique(roots)
        for name in readdir(root)
            path = joinpath(root, name)
            isfile(path) || continue
            _is_excel_workbook(path) && push!(paths, abspath(path))
        end
    end

    sort!(unique!(paths))
    isempty(paths) && throw(ArgumentError("directory `$directory` contains no .xls or .xlsx workbooks$(recursive ? "" : "; pass `recursive=true` to search subdirectories")"))
    return paths
end

function _validate_local_workbook(path::AbstractString; context::AbstractString="path")
    ispath(path) || throw(ArgumentError("$context does not exist: `$path`"))
    isfile(path) || throw(ArgumentError("$context is not a file: `$path`"))
    _is_excel_workbook(path) || throw(ArgumentError("unsupported local file `$path`; expected a .xls or .xlsx workbook"))
    return abspath(path)
end

function _is_excel_workbook(path::AbstractString)
    return lowercase(splitext(path)[2]) in (".xls", ".xlsx")
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

function _series_parts(value::AbstractString; remove_totals::Bool=false)
    delimiter = occursin(";", value) ? r"\s*;\s*" : occursin("|", value) ? r"\s*\|\s*" : r"\s*,\s*"
    parts = [strip(part) for part in split(value, delimiter) if !isempty(strip(part))]
    return remove_totals ? [part for part in parts if !_is_aggregate_series_part(part)] : parts
end

function _series_part_names(column::Symbol, count::Int, names)
    if names === nothing
        return [Symbol("$(column)_part_$index") for index in 1:count]
    end

    names isa AbstractString && throw(ArgumentError("names must be a vector or tuple of symbols or strings"))
    provided = collect(names)
    length(provided) == count || throw(ArgumentError("names must contain $count entries; got $(length(provided))"))
    return Symbol.(provided)
end

function _is_aggregate_series_part(value::AbstractString)
    key = replace(lowercase(strip(value)), r"\s+" => " ")
    return key in _aggregate_series_tokens()
end

function _aggregate_series_tokens()
    return Set([
        "total",
        "totals",
        "all",
        "all groups",
        "all sectors",
        "all states",
        "all territories",
        "all industries",
        "all persons",
        "all employees",
    ])
end

function _is_url(value::AbstractString)
    text = lowercase(strip(value))
    return startswith(text, "http://") || startswith(text, "https://")
end

function _empty_series_value(value)
    return ismissing(value) || isempty(strip(string(value)))
end
