function _selected_sheets(xf, sheets)
    available = XLSX.sheetnames(xf)
    sheets === nothing && return available
    sheets isa AbstractString && return [sheets]
    return collect(sheets)
end

function _read_sheet(sheet; header_row::Union{Int,Nothing}=nothing)
    rows = _sheet_rows(sheet)
    isempty(rows) && return DataFrame()

    first_data_row = something(header_row, _detect_header_row(rows))
    names = _column_names(rows[first_data_row])
    data_rows = rows[(first_data_row + 1):end]

    table = DataFrame([name => Any[] for name in names])
    for row in data_rows
        _row_is_empty(row) && continue
        values = Any[_clean_cell(get(row, i, missing)) for i in eachindex(names)]
        push!(table, values)
    end

    return table
end

function _sheet_rows(sheet)
    data = XLSX.getdata(sheet)
    isempty(data) && return Vector{Vector{Any}}()
    return [Any[_cell_value(data[row, column]) for column in axes(data, 2)] for row in axes(data, 1)]
end

function _cell_value(value)
    return value === nothing ? missing : value
end

function _detect_header_row(rows)
    scores = map(rows) do row
        count(value -> !ismissing(value) && !isempty(strip(string(value))), row)
    end
    index = findfirst(>(1), scores)
    return something(index, 1)
end

function _column_names(row)
    names = String[]
    seen = Dict{String,Int}()

    for (index, value) in enumerate(row)
        base = if ismissing(value) || isempty(strip(string(value)))
            "Column$index"
        else
            _normalise_name(string(value))
        end

        count = get(seen, base, 0) + 1
        seen[base] = count
        push!(names, count == 1 ? base : "$(base)_$count")
    end

    return Symbol.(names)
end

function _normalise_name(value::AbstractString)
    cleaned = replace(strip(value), r"\s+" => "_")
    cleaned = replace(cleaned, r"[^A-Za-z0-9_]" => "")
    return isempty(cleaned) ? "Column" : cleaned
end

function _row_is_empty(row)
    return all(value -> ismissing(value) || isempty(strip(string(value))), row)
end

function _clean_cell(value)
    ismissing(value) && return missing
    value isa Date && return value
    value isa DateTime && return Date(value)
    return value
end

"""
    tidy_abs(path; metadata=true, cat_no=missing, release_date=missing, cache_parsed=false, refresh=false)

Parse an ABS Excel time-series workbook into a tidy `DataFrame`.
"""
function tidy_abs(path::AbstractString; metadata::Bool=true, cat_no=missing, release_date=missing, cache_parsed::Bool=false, refresh::Bool=false)
    options = (metadata=metadata, cat_no=cat_no, release_date=release_date)
    return _with_parsed_cache(path; kind=:tidy_abs, options=options, cache_parsed=cache_parsed, refresh=refresh) do
        _parse_tidy_abs(path; metadata=metadata, cat_no=cat_no, release_date=release_date)
    end
end

function _parse_tidy_abs(path::AbstractString; metadata::Bool=true, cat_no=missing, release_date=missing)
    out = _empty_tidy_abs()

    XLSX.openxlsx(path) do xf
        for (sheet_index, sheetname) in enumerate(XLSX.sheetnames(xf))
            sheet_rows = _tidy_sheet(xf[sheetname], sheetname; metadata=metadata, cat_no=cat_no, release_date=release_date, sheet_index=sheet_index)
            isempty(sheet_rows) || append!(out, sheet_rows)
        end
    end

    return out
end

function _empty_tidy_abs()
    return DataFrame(
        cat_no = Union{Missing,String}[],
        release_date = Union{Missing,String}[],
        table = String[],
        table_no = Union{Missing,String}[],
        table_title = Union{Missing,String}[],
        sheet = String[],
        sheet_no = Int[],
        date = Date[],
        series_id = String[],
        value = Union{Missing,Float64}[],
        unit = Union{Missing,String}[],
        series_type = Union{Missing,String}[],
        data_type = Union{Missing,String}[],
        frequency = Union{Missing,String}[],
        collection_month = Union{Missing,String}[],
        series_start = Union{Missing,String}[],
        series = Union{Missing,String}[],
    )
end

function _empty_abs_metadata()
    return DataFrame(
        cat_no = Union{Missing,String}[],
        release_date = Union{Missing,String}[],
        table = String[],
        table_no = Union{Missing,String}[],
        table_title = Union{Missing,String}[],
        sheet = String[],
        sheet_no = Int[],
        series_id = String[],
        unit = Union{Missing,String}[],
        series_type = Union{Missing,String}[],
        data_type = Union{Missing,String}[],
        frequency = Union{Missing,String}[],
        collection_month = Union{Missing,String}[],
        series_start = Union{Missing,String}[],
        series = Union{Missing,String}[],
        source_workbook = String[],
    )
end

function _metadata_sheet(sheet, sheetname::AbstractString; cat_no=missing, release_date=missing, sheet_index::Int=1, source_workbook::AbstractString="")
    rows = _sheet_rows(sheet)
    isempty(rows) && return _empty_abs_metadata()
    all(_row_is_empty, rows) && return _empty_abs_metadata()

    context = _sheet_context(rows, sheetname, sheet_index, cat_no, release_date)
    if isempty(_date_rows_in_column(rows, 1))
        metadata_only = _metadata_only_time_down(rows, context, source_workbook)
        isempty(metadata_only) || return metadata_only
    end

    tidy = _tidy_sheet(sheet, sheetname; cat_no=context.cat_no, release_date=context.release_date, sheet_index)
    if !isempty(tidy)
        metadata = unique(select(tidy, Not([:date, :value])))
        metadata[!, :source_workbook] = fill(source_workbook, nrow(metadata))
        return metadata
    end

    return _metadata_only_time_down(rows, context, source_workbook)
end

function _metadata_only_time_down(rows, context, source_workbook::AbstractString)
    date_col = 1
    first_data_row = length(rows) + 1
    labels = _metadata_labels(rows, first_data_row, date_col)
    any(label -> haskey(labels, label), _series_id_labels()) || return _empty_abs_metadata()

    max_cols = maximum(length, rows; init=0)
    out = _empty_abs_metadata()
    for col in 2:max_cols
        series_id = _series_id_for_column(rows, col, first_data_row, labels)
        _looks_like_abs_series_id(series_id) || continue

        series = _series_name_for_column(rows, col, first_data_row, labels)
        unit = _metadata_for_column(rows, col, labels, _unit_labels())
        series_type = _metadata_for_column(rows, col, labels, _series_type_labels())
        data_type = _metadata_for_column(rows, col, labels, _data_type_labels())
        frequency = _normalise_frequency(_metadata_for_column(rows, col, labels, _frequency_labels()))
        collection_month = _metadata_for_column(rows, col, labels, _collection_month_labels())
        series_start = _metadata_for_column(rows, col, labels, _series_start_labels())
        ismissing(series) && (series = _series_column_name(col))

        push!(out, (
            context.cat_no,
            context.release_date,
            context.table,
            context.table_no,
            context.table_title,
            context.sheet,
            context.sheet_no,
            series_id,
            unit,
            series_type,
            data_type,
            frequency,
            collection_month,
            series_start,
            series,
            source_workbook,
        ))
    end

    return out
end

function _tidy_sheet(sheet, sheetname::AbstractString; metadata::Bool=true, cat_no=missing, release_date=missing, sheet_index::Int=1)
    rows = _sheet_rows(sheet)
    isempty(rows) && return _empty_tidy_abs()
    all(_row_is_empty, rows) && return _empty_tidy_abs()

    context = _sheet_context(rows, sheetname, sheet_index, cat_no, release_date)

    tidy = _tidy_sheet_time_down(rows, sheetname; metadata, context)
    isempty(tidy) || return tidy

    return _tidy_sheet_time_across(rows, sheetname; metadata, context)
end

function _tidy_sheet_time_down(rows, sheetname::AbstractString; metadata::Bool=true, context=_sheet_context(sheetname, 1, missing, missing))
    date_col = 1
    date_rows = _date_rows_in_column(rows, date_col)
    if isempty(date_rows)
        return _empty_tidy_abs()
    end

    first_date_row = first(date_rows)
    series_cols = _series_columns_time_down(rows, date_col, date_rows)
    isempty(series_cols) && return _empty_tidy_abs()

    labels = _metadata_labels(rows, first_date_row, date_col)
    out = _empty_tidy_abs()

    for col in series_cols
        series_id = _series_id_for_column(rows, col, first_date_row, labels)
        series = metadata ? _series_name_for_column(rows, col, first_date_row, labels) : missing
        unit = metadata ? _metadata_for_column(rows, col, labels, _unit_labels()) : missing
        series_type = metadata ? _metadata_for_column(rows, col, labels, _series_type_labels()) : missing
        data_type = metadata ? _metadata_for_column(rows, col, labels, _data_type_labels()) : missing
        frequency = metadata ? _normalise_frequency(_metadata_for_column(rows, col, labels, _frequency_labels())) : "unknown"
        collection_month = metadata ? _metadata_for_column(rows, col, labels, _collection_month_labels()) : missing
        series_start = metadata ? _metadata_for_column(rows, col, labels, _series_start_labels()) : missing
        frequency == "unknown" && (frequency = _infer_frequency([rows[row_index][date_col] for row_index in date_rows]))
        ismissing(series) && (series = _series_column_name(col))

        for row_index in date_rows
            date = _period_start(rows[row_index][date_col], frequency)
            date === nothing && continue

            value = _parse_abs_float(get(rows[row_index], col, missing))

            push!(out, (
                context.cat_no,
                context.release_date,
                context.table,
                context.table_no,
                context.table_title,
                context.sheet,
                context.sheet_no,
                date,
                series_id,
                value,
                unit,
                series_type,
                data_type,
                frequency,
                collection_month,
                series_start,
                series,
            ))
        end
    end

    return out
end

function _tidy_sheet_time_across(rows, sheetname::AbstractString; metadata::Bool=true, context=_sheet_context(sheetname, 1, missing, missing))
    header_row, date_cols = _best_date_header_row(rows)
    if header_row === nothing || isempty(date_cols)
        return _empty_tidy_abs()
    end

    out = _empty_tidy_abs()
    for row_index in (header_row + 1):length(rows)
        row = rows[row_index]
        _row_is_empty(row) && continue

        series_id = _series_id_for_row(row)
        isempty(series_id) && continue

        series = metadata ? _series_name_for_row(row, rows[header_row]) : missing
        unit = metadata ? _metadata_for_row(row, rows[header_row], _unit_labels()) : missing
        series_type = metadata ? _metadata_for_row(row, rows[header_row], _series_type_labels()) : missing
        data_type = metadata ? _metadata_for_row(row, rows[header_row], _data_type_labels()) : missing
        frequency = metadata ? _normalise_frequency(_metadata_for_row(row, rows[header_row], _frequency_labels())) : "unknown"
        collection_month = metadata ? _metadata_for_row(row, rows[header_row], _collection_month_labels()) : missing
        series_start = metadata ? _metadata_for_row(row, rows[header_row], _series_start_labels()) : missing
        frequency == "unknown" && (frequency = _infer_frequency([rows[header_row][col] for col in date_cols]))
        ismissing(series) && (series = _clean_text(isempty(row) ? missing : first(row)))

        for col in date_cols
            date = _period_start(rows[header_row][col], frequency)
            date === nothing && continue

            value = _parse_abs_float(get(row, col, missing))

            push!(out, (
                context.cat_no,
                context.release_date,
                context.table,
                context.table_no,
                context.table_title,
                context.sheet,
                context.sheet_no,
                date,
                series_id,
                value,
                unit,
                series_type,
                data_type,
                frequency,
                collection_month,
                series_start,
                series,
            ))
        end
    end

    return out
end

function _date_rows_in_column(rows, date_col::Int)
    date_rows = Int[]
    for (row_index, row) in enumerate(rows)
        date_col <= length(row) || continue
        _parse_abs_date(row[date_col]) === nothing || push!(date_rows, row_index)
    end
    return date_rows
end

function _best_date_column(rows)
    max_cols = maximum(length, rows; init=0)
    best_col = nothing
    best_rows = Int[]

    for col in 1:max_cols
        parsed_rows = Int[]
        for (row_index, row) in enumerate(rows)
            col <= length(row) || continue
            _parse_abs_date(row[col]) === nothing || push!(parsed_rows, row_index)
        end

        if length(parsed_rows) > length(best_rows)
            best_col = col
            best_rows = parsed_rows
        end
    end

    return best_col, best_rows
end

function _best_date_header_row(rows)
    best_row = nothing
    best_cols = Int[]

    for (row_index, row) in enumerate(rows)
        parsed_cols = Int[]
        for (col, value) in enumerate(row)
            _parse_abs_date(value) === nothing || push!(parsed_cols, col)
        end

        if length(parsed_cols) > length(best_cols)
            best_row = row_index
            best_cols = parsed_cols
        end
    end

    return best_row, best_cols
end

function _series_columns_time_down(rows, date_col::Int, date_rows)
    max_cols = maximum(length, rows; init=0)
    columns = Int[]

    for col in 1:max_cols
        col == date_col && continue
        _column_has_content(rows, col) && push!(columns, col)
    end

    return columns
end

function _column_has_content(rows, col::Int)
    return any(row -> col <= length(row) && !_empty_series_value(row[col]), rows)
end

function _metadata_labels(rows, first_date_row::Int, date_col::Int)
    labels = Dict{String,Int}()
    for row_index in 1:(first_date_row - 1)
        label = _metadata_label(get(rows[row_index], date_col, missing))
        isempty(label) || (labels[label] = row_index)
    end
    return labels
end

function _metadata_label(value)
    _empty_series_value(value) && return ""
    return _metadata_key(value)
end

function _series_id_for_column(rows, col::Int, first_date_row::Int, labels)
    for label in _series_id_labels()
        if haskey(labels, label)
            id = _clean_text(get(rows[labels[label]], col, missing))
            isempty(id) || return id
        end
    end

    for row_index in 1:(first_date_row - 1)
        id = _clean_text(get(rows[row_index], col, missing))
        _looks_like_abs_series_id(id) && return id
    end

    return _series_column_name(col)
end

function _metadata_for_column(rows, col::Int, labels, candidates)
    for candidate in candidates
        if haskey(labels, candidate)
            text = _clean_text(get(rows[labels[candidate]], col, missing))
            isempty(text) || return text
        end
    end
    return missing
end

function _series_name_for_column(rows, col::Int, first_date_row::Int, labels)
    value = _metadata_for_column(rows, col, labels, _series_labels())
    ismissing(value) || return value
    return missing
end

function _series_id_for_row(row)
    for value in row
        text = _clean_text(value)
        _looks_like_abs_series_id(text) && return text
    end
    return _clean_text(isempty(row) ? missing : first(row))
end

function _metadata_for_row(row, header, candidates)
    for (col, heading) in enumerate(header)
        label = _metadata_key(heading)
        if label in candidates
            text = _clean_text(get(row, col, missing))
            isempty(text) || return text
        end
    end
    return missing
end

function _series_name_for_row(row, header)
    value = _metadata_for_row(row, header, _series_labels())
    ismissing(value) || return value

    for value in row
        text = _clean_text(value)
        if !isempty(text) && !_looks_like_abs_series_id(text) && _parse_abs_date(text) === nothing && ismissing(_parse_abs_float(text))
            return text
        end
    end

    return missing
end

function _parse_abs_date(value)
    period = _parse_abs_period(value)
    return period === nothing ? nothing : period.date
end

function _parse_abs_period(value)
    ismissing(value) && return nothing
    value isa Date && return (date=value, frequency="unknown")
    value isa DateTime && return (date=Date(value), frequency="unknown")

    if value isa Real
        serial = round(Int, value)
        serial > 10_000 || return nothing
        return (date=Date(1899, 12, 30) + Day(serial), frequency="unknown")
    end

    text = strip(string(value))
    isempty(text) && return nothing

    year = match(r"^([0-9]{4})$", text)
    if year !== nothing
        return (date=Date(parse(Int, year.captures[1]), 1, 1), frequency="annual")
    end

    year_month = match(r"^([0-9]{4})[-/]([0-9]{1,2})$", text)
    if year_month !== nothing
        month = parse(Int, year_month.captures[2])
        1 <= month <= 12 || return nothing
        return (date=Date(parse(Int, year_month.captures[1]), month, 1), frequency="monthly")
    end

    quarter = match(r"^([0-9]{4})[- ]?Q([1-4])$"i, text)
    if quarter !== nothing
        year = parse(Int, quarter.captures[1])
        month = 3 * (parse(Int, quarter.captures[2]) - 1) + 1
        return (date=Date(year, month, 1), frequency="quarterly")
    end

    quarter = match(r"^Q([1-4])[- ]?([0-9]{4})$"i, text)
    if quarter !== nothing
        year = parse(Int, quarter.captures[2])
        month = 3 * (parse(Int, quarter.captures[1]) - 1) + 1
        return (date=Date(year, month, 1), frequency="quarterly")
    end

    month_year = match(r"^([A-Za-z]{3})[- ]?([0-9]{2}|[0-9]{4})$", text)
    if month_year !== nothing
        month = _month_number(month_year.captures[1])
        year = _parse_abs_year(month_year.captures[2])
        return (date=Date(year, month, 1), frequency="unknown")
    end

    for format in (dateformat"yyyy-mm-dd", dateformat"dd/mm/yyyy", dateformat"m/d/yyyy", dateformat"u yyyy", dateformat"U yyyy")
        parsed = tryparse(Date, text, format)
        parsed === nothing || return (date=parsed, frequency="unknown")
    end

    return nothing
end

function _period_start(value, frequency::AbstractString)
    period = _parse_abs_period(value)
    period === nothing && return nothing

    if frequency == "quarterly"
        quarter_month = 3 * div(month(period.date) - 1, 3) + 1
        return Date(year(period.date), quarter_month, 1)
    elseif frequency == "annual"
        return Date(year(period.date), 1, 1)
    end

    return period.date
end

function _parse_abs_year(text::AbstractString)
    year = parse(Int, text)
    return year < 100 ? 2000 + year : year
end

function _month_number(month::AbstractString)
    months = Dict("jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4, "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8, "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12)
    return months[lowercase(month[1:3])]
end

function _parse_abs_float(value)
    ismissing(value) && return missing
    value isa Bool && return missing
    value isa Real && return Float64(value)

    text = strip(string(value))
    isempty(text) && return missing
    lowercase(text) in ("na", "n/a", "np", "..", "-") && return missing

    cleaned = replace(text, "," => "")
    parsed = tryparse(Float64, cleaned)
    return parsed === nothing ? missing : parsed
end

function _infer_frequency(values)
    periods = [_parse_abs_period(value) for value in values]
    clean_periods = [period for period in periods if period !== nothing]
    isempty(clean_periods) && return "unknown"

    known = [period.frequency for period in clean_periods if period.frequency != "unknown"]
    !isempty(known) && all(frequency -> frequency == first(known), known) && return first(known)

    clean_dates = sort([period.date for period in clean_periods])
    length(clean_dates) < 2 && return "unknown"

    months = [_month_delta(clean_dates[index], clean_dates[index + 1]) for index in 1:(length(clean_dates) - 1)]
    isempty(months) && return "unknown"

    median_months = sort(months)[cld(length(months), 2)]
    if median_months == 1
        return "monthly"
    elseif median_months == 3
        return "quarterly"
    elseif median_months == 12
        return "annual"
    end

    return "unknown"
end

function _month_delta(start_date::Date, end_date::Date)
    return 12 * (year(end_date) - year(start_date)) + month(end_date) - month(start_date)
end

function _clean_text(value)
    _empty_series_value(value) && return ""
    return strip(string(value))
end

function _normalise_frequency(value)
    ismissing(value) && return "unknown"
    text = lowercase(strip(string(value)))
    isempty(text) && return "unknown"

    startswith(text, "month") && return "monthly"
    startswith(text, "quarter") && return "quarterly"
    startswith(text, "annual") && return "annual"
    startswith(text, "year") && return "annual"
    startswith(text, "week") && return "weekly"
    startswith(text, "fortnight") && return "fortnightly"
    (startswith(text, "biannual") || startswith(text, "semiannual") || startswith(text, "half-year")) && return "semiannual"
    startswith(text, "day") && return "daily"

    return "unknown"
end

function _metadata_key(value)
    _empty_series_value(value) && return ""
    text = lowercase(strip(string(value)))
    text = replace(text, r"\s+" => " ")
    return replace(text, r"[^a-z0-9]" => "")
end

_series_id_labels() = ("seriesid", "seriesnumber")
_series_labels() = ("dataitem", "series", "seriesdescription", "description", "title")
_unit_labels() = ("unit", "units", "unitofmeasure")
_frequency_labels() = ("frequency", "freq")
_series_type_labels() = ("seriestype", "series type", "seasonaladjustment", "seasonaladjustmenttype", "adjustment")
_data_type_labels() = ("datatype", "data type")
_collection_month_labels() = ("collectionmonth", "collection")
_series_start_labels() = ("seriesstart", "startdate", "start")

function _series_column_name(col::Int)
    return "Column $col"
end

function _looks_like_abs_series_id(text::AbstractString)
    isempty(text) && return false
    return occursin(r"^[A-Z][A-Z0-9]{5,}$", strip(text))
end

function _sheet_context(sheetname::AbstractString, sheet_index::Int, cat_no, release_date)
    table_no = something(_table_no(sheetname), missing)
    return (
        cat_no = _missing_or_string(cat_no),
        release_date = _missing_or_string(release_date),
        table = string(sheetname),
        table_no = table_no,
        table_title = string(sheetname),
        sheet = string(sheetname),
        sheet_no = sheet_index,
    )
end

function _sheet_context(rows, sheetname::AbstractString, sheet_index::Int, cat_no, release_date)
    table_title = _infer_table_title(rows, sheetname)
    table_no = something(_table_no(table_title), _table_no(sheetname), missing)
    inferred_cat_no = _infer_catalogue_number(rows)
    inferred_release = _infer_release_value(rows)
    return (
        cat_no = ismissing(_missing_or_string(cat_no)) ? inferred_cat_no : _missing_or_string(cat_no),
        release_date = ismissing(_missing_or_string(release_date)) ? inferred_release : _missing_or_string(release_date),
        table = string(sheetname),
        table_no = table_no,
        table_title = table_title,
        sheet = string(sheetname),
        sheet_no = sheet_index,
    )
end

function _infer_table_title(rows, sheetname::AbstractString)
    first_date_row = findfirst(row -> !isempty(row) && _parse_abs_date(first(row)) !== nothing, rows)
    metadata_end = something(first_date_row, length(rows) + 1) - 1
    limit = min(length(rows), metadata_end, 30)
    limit < 1 && return string(sheetname)

    candidates = String[]
    for row_index in 1:limit
        for value in rows[row_index]
            text = _clean_text(value)
            _looks_like_table_title(text) && push!(candidates, text)
        end
    end

    isempty(candidates) && return string(sheetname)
    scores = [_table_title_score(candidate) for candidate in candidates]
    return candidates[argmax(scores)]
end

function _looks_like_table_title(text::AbstractString)
    isempty(text) && return false
    key = _metadata_key(text)
    key in _all_metadata_labels() && return false
    occursin(r"(?i)^tables?\s*[0-9]+[a-z]?\b", text) && return true
    return occursin(r"(?i)\btable\s*[0-9]+[a-z]?\b", text) && length(text) > 12
end

function _table_title_score(text::AbstractString)
    score = min(length(text), 300)
    occursin(r"(?i)^tables?\s*[0-9]+[a-z]?\b", text) && (score += 1000)
    return score
end

function _infer_catalogue_number(rows)
    for row in first(rows, min(length(rows), 30))
        isempty(row) && continue
        key = _metadata_key(first(row))
        if key in ("cataloguenumber", "catalogueno", "catno", "catnumber")
            value = _first_matching_text(row[2:end], r"\b[0-9]{4}(?:\.[0-9]+)*\b")
            value === nothing || return value
        end

        for value in row
            text = _clean_text(value)
            m = match(r"(?i)catalogue\s*(?:number|no\.?)?\s*:?\s*([0-9]{4}(?:\.[0-9]+)*)", text)
            m === nothing || return m.captures[1]
        end
    end
    return missing
end

function _infer_release_value(rows)
    for row in first(rows, min(length(rows), 30))
        isempty(row) && continue
        key = _metadata_key(first(row))
        if key in ("releasedate", "released", "publicationdate", "referenceperiod")
            for value in row[2:end]
                text = _clean_text(value)
                isempty(text) || return _normalise_release_text(text)
            end
        end

        for value in row
            text = _clean_text(value)
            m = match(r"(?i)release(?:d| date)?\s*:?\s*(.+)$", text)
            m === nothing || return _normalise_release_text(m.captures[1])
        end
    end
    return missing
end

function _normalise_release_text(text::AbstractString)
    release_date = _release_date_from_text(text)
    return release_date === nothing ? strip(text) : _release_key(release_date)
end

function _first_matching_text(values, pattern)
    for value in values
        text = _clean_text(value)
        m = match(pattern, text)
        m === nothing || return m.match
    end
    return nothing
end

function _all_metadata_labels()
    return Set(vcat(
        collect(_series_id_labels()),
        collect(_series_labels()),
        collect(_unit_labels()),
        collect(_frequency_labels()),
        collect(_series_type_labels()),
        collect(_data_type_labels()),
        collect(_collection_month_labels()),
        collect(_series_start_labels()),
    ))
end

function _missing_or_string(value)
    ismissing(value) && return missing
    value === nothing && return missing
    text = strip(string(value))
    return isempty(text) ? missing : text
end
