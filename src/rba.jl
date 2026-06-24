const RBA_BASE_URL = "https://www.rba.gov.au"
const RBA_TABLES_URL = RBA_BASE_URL * "/statistics/tables/"
const RBA_SPECIAL_DATASETS = [
    (
        dataset_id="cash-rate-target",
        title="Cash Rate Target",
        description="Cash rate target decisions published by the Reserve Bank of Australia.",
        page_url=RBA_BASE_URL * "/statistics/cash-rate/",
        file_title="Cash Rate Target",
        filename="cash-rate-target.html",
        resource_kind=:html,
    ),
    (
        dataset_id="balance-sheet",
        title="Reserve Bank of Australia Balance Sheet",
        description="Latest Reserve Bank of Australia balance sheet summary.",
        page_url=RBA_BASE_URL * "/statistics/balance-sheet/",
        file_title="Reserve Bank of Australia Balance Sheet",
        filename="balance-sheet.html",
        resource_kind=:html,
    ),
]

"""
    rba_tables(; refresh=false)

Return known RBA datasets as a `DataFrame`.
"""
function rba_tables(; refresh::Bool=false)
    return _provider_datasets_from_files(rba_files(; refresh))
end

"""
    rba_files(table_id=nothing; refresh=false)

Return known RBA downloadable/statistical resources. When `table_id` is supplied,
only matching resources are returned.
"""
function rba_files(table_id=nothing; refresh::Bool=false)
    df = _rba_index(; refresh)
    table_id === nothing && return df
    needle = lowercase(strip(string(table_id)))
    keep = map(eachrow(df)) do row
        lowercase(row.dataset_id) == needle ||
            lowercase(row.file_id) == needle ||
            occursin(needle, lowercase(row.title)) ||
            occursin(needle, lowercase(row.file_title))
    end
    return df[keep, :]
end

"""
    search_rba(query; refresh=false)

Search known RBA datasets and downloadable/statistical resources.
"""
function search_rba(query::AbstractString; refresh::Bool=false)
    needle = lowercase(strip(query))
    df = rba_files(; refresh)
    isempty(needle) && return df
    keep = map(eachrow(df)) do row
        haystack = lowercase(
            join(
                (
                    row.dataset_id,
                    row.title,
                    row.description,
                    row.file_id,
                    row.file_title,
                    row.filename,
                    row.url,
                ),
                " ",
            ),
        )
        occursin(needle, haystack)
    end
    return df[keep, :]
end

"""
    download_rba(table_id; file=nothing, dest=default_cache_dir(), force=false)

Download an RBA statistical table/resource and return the local path.
"""
function download_rba(
    table_id::AbstractString;
    file=nothing,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    row = _select_rba_file(table_id; file)
    target_dir = joinpath(dest, "rba")
    if row.resource_kind == :html
        return _download_text_file(row.url; dest=target_dir, filename=row.filename, force)
    end
    return _download_file(row.url; dest=target_dir, filename=row.filename, force)
end

"""
    read_rba(source; file=nothing, cache=true, cache_parsed=true, refresh=false)

Read RBA data from a table id, direct URL, or local CSV/HTML file.
"""
function read_rba(
    source::AbstractString;
    file=nothing,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    if _is_url(source)
        dest = cache ? _cache_subdir(:rba) : mktempdir()
        filename = _url_filename(source)
        path = if occursin(r"\.html?$"i, split(source, '?'; limit=2)[1])
            _download_text_file(source; dest, filename, force=!cache)
        else
            _download_file(source; dest, filename, force=!cache)
        end
        return _read_rba_file(path; source_url=source, cache_parsed, refresh)
    elseif isfile(source)
        return _read_rba_file(source; cache_parsed, refresh)
    end

    refresh && rba_files(source; refresh=true)
    row = _select_rba_file(source; file)
    path = if cache
        download_rba(source; file)
    elseif row.resource_kind == :html
        _download_text_file(row.url; dest=mktempdir(), filename=row.filename, force=true)
    else
        _download_file(row.url; dest=mktempdir(), filename=row.filename, force=true)
    end
    return _read_rba_file(
        path; metadata=_rba_metadata(row), source_url=row.url, cache_parsed, refresh
    )
end

"""
    read_rba_cash_rate(; refresh=false, cache_parsed=true)

Read the RBA cash rate target page.
"""
function read_rba_cash_rate(; refresh::Bool=false, cache_parsed::Bool=true)
    return read_rba("cash-rate-target"; refresh, cache_parsed)
end

"""
    read_rba_balance_sheet(; refresh=false, cache_parsed=true)

Read the latest RBA balance sheet page.
"""
function read_rba_balance_sheet(; refresh::Bool=false, cache_parsed::Bool=true)
    return read_rba("balance-sheet"; refresh, cache_parsed)
end

_datasets(::RBAProvider; refresh::Bool=false) = rba_tables(; refresh)
function _datafiles(::RBAProvider, dataset_id=nothing; refresh::Bool=false, release=nothing)
    return rba_files(dataset_id; refresh)
end
function _search_data(::RBAProvider, query::AbstractString; refresh::Bool=false)
    return search_rba(query; refresh)
end
function _download_data(
    ::RBAProvider,
    dataset_id::AbstractString;
    file=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    return download_rba(dataset_id; file, dest, force)
end
function _read_data(
    ::RBAProvider,
    source::AbstractString;
    file=nothing,
    release=:latest,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    return read_rba(source; file, cache, cache_parsed, refresh)
end

function _rba_index(; refresh::Bool=false)
    refresh && return refresh_rba!()
    cached = _read_rba_index()
    cached === nothing || return cached
    return _provider_file_rows(_rba_seed_rows())
end

function refresh_rba!()
    rows = NamedTuple[]
    try
        html = _http_text(RBA_TABLES_URL)
        append!(rows, _discover_rba_tables(_parse_html(html)))
    catch
        rows = NamedTuple[]
    end
    append!(rows, _rba_special_rows())
    df = _provider_file_rows(unique(rows))
    _write_rba_index(df)
    return df
end

function _discover_rba_tables(doc)
    rows = NamedTuple[]
    current = nothing
    for link in _html_links(doc)
        href = _html_attr(link, "href")
        label = _clean_discovery_text(_html_text(link))
        url = _absolute_url(href; base=RBA_BASE_URL)
        table_id = _rba_table_id(label, url)

        if _looks_like_rba_table_page(url, label) && table_id !== nothing
            current = (
                dataset_id=table_id,
                title=_rba_table_title(label, table_id),
                page_url=_normalise_page_url(url),
            )
            continue
        end

        _looks_like_rba_data_url(url) || continue
        data_id = something(table_id, current === nothing ? nothing : current.dataset_id)
        data_id === nothing && continue
        title = current === nothing ? data_id : current.title
        page_url = current === nothing ? RBA_TABLES_URL : current.page_url
        file_title =
            _generic_download_label(label) || lowercase(label) == "data" ? title : label
        push!(
            rows,
            _provider_file_row(;
                provider=:rba,
                dataset_id=data_id,
                title,
                description="RBA statistical table $data_id.",
                page_url,
                release_date="",
                file_id=data_id,
                file_title,
                url=_normalise_file_url(url),
                filename=_url_filename(url),
                file_type=lowercase(splitext(_url_filename(url))[2][2:end]),
                resource_kind=:timeseries,
            ),
        )
    end
    return rows
end

function _rba_seed_rows()
    rows = NamedTuple[
        _provider_file_row(;
            provider=:rba,
            dataset_id="A1",
            title="RBA Balance Sheet - A1",
            description="RBA statistical table A1.",
            page_url=RBA_TABLES_URL,
            release_date="",
            file_id="A1",
            file_title="RBA Balance Sheet - A1",
            url=RBA_BASE_URL * "/statistics/tables/csv/a1-data.csv",
            filename="a1-data.csv",
            file_type="csv",
            resource_kind=:timeseries,
        ),
        _provider_file_row(;
            provider=:rba,
            dataset_id="F1",
            title="Interest Rates and Yields - Money Market - Daily - F1",
            description="RBA statistical table F1.",
            page_url=RBA_TABLES_URL,
            release_date="",
            file_id="F1",
            file_title="Interest Rates and Yields - Money Market - Daily - F1",
            url=RBA_BASE_URL * "/statistics/tables/csv/f1-data.csv",
            filename="f1-data.csv",
            file_type="csv",
            resource_kind=:timeseries,
        ),
    ]
    append!(rows, _rba_special_rows())
    return rows
end

function _rba_special_rows()
    return [
        _provider_file_row(;
            provider=:rba,
            dataset_id=row.dataset_id,
            title=row.title,
            description=row.description,
            page_url=row.page_url,
            release_date="",
            file_id=row.dataset_id,
            file_title=row.file_title,
            url=row.page_url,
            filename=row.filename,
            file_type="html",
            resource_kind=row.resource_kind,
        ) for row in RBA_SPECIAL_DATASETS
    ]
end

function _write_rba_index(df::DataFrame)
    path = _rba_index_path()
    mkpath(dirname(path))
    rows = [Dict(String(name) => row[name] for name in names(df)) for row in eachrow(df)]
    open(path, "w") do io
        JSON3.write(io, rows)
    end
    return path
end

function _read_rba_index()
    path = _rba_index_path()
    isfile(path) || return nothing
    parsed = JSON3.read(read(path, String))
    rows = NamedTuple[]
    for item in parsed
        push!(
            rows,
            _provider_file_row(;
                provider=Symbol(String(item.provider)),
                dataset_id=String(item.dataset_id),
                title=String(item.title),
                description=String(item.description),
                page_url=String(item.page_url),
                release_date=String(item.release_date),
                file_id=String(item.file_id),
                file_title=String(item.file_title),
                url=String(item.url),
                filename=String(item.filename),
                file_type=String(item.file_type),
                resource_kind=Symbol(String(item.resource_kind)),
            ),
        )
    end
    return _provider_file_rows(rows)
end

_rba_index_path() = joinpath(_cache_subdir(:indexes), "rba_files.json")

function _select_rba_file(table_id::AbstractString; file=nothing)
    candidates = rba_files(table_id)
    isempty(candidates) && (candidates = rba_files(table_id; refresh=true))
    isempty(candidates) && throw(ArgumentError("no RBA files found for `$table_id`"))

    if file !== nothing
        request = lowercase(strip(string(file)))
        keep = map(eachrow(candidates)) do row
            lowercase(row.file_id) == request ||
                occursin(request, lowercase(row.file_title)) ||
                occursin(request, lowercase(row.filename))
        end
        candidates = candidates[keep, :]
        isempty(candidates) &&
            throw(ArgumentError("no RBA file matched `$file` for `$table_id`"))
    end

    return first(eachrow(sort(candidates, [:resource_kind, :filename])))
end

function _download_text_file(
    url::AbstractString; dest::AbstractString=tempdir(), filename=nothing, force::Bool=false
)
    mkpath(dest)
    target = joinpath(dest, something(filename, _url_filename(url)))
    if isfile(target) && !force
        return target
    end
    write(target, _http_text(url))
    return target
end

function _read_rba_file(
    path::AbstractString;
    metadata=_rba_metadata(),
    source_url=missing,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    options = (metadata=metadata, source_url=source_url)
    return _with_parsed_cache(path; kind=:read_rba, options, cache_parsed, refresh) do
        lower = lowercase(path)
        if metadata.dataset_id == "cash-rate-target"
            return _read_rba_cash_rate_html(path; metadata, source_url)
        elseif metadata.dataset_id == "balance-sheet"
            return _read_rba_balance_sheet_html(path; metadata, source_url)
        elseif endswith(lower, ".csv")
            return _read_rba_csv(path; metadata, source_url)
        elseif endswith(lower, ".html") || endswith(lower, ".htm")
            return _read_rba_html_tables(path; metadata, source_url)
        end
        throw(ArgumentError("unsupported RBA file type for `$path`; expected CSV or HTML"))
    end
end

function _read_rba_csv(path::AbstractString; metadata=_rba_metadata(), source_url=missing)
    lines = readlines(path)
    isempty(lines) && return _empty_rba_tidy()
    header_index = _rba_csv_header_index(lines)
    text = join(lines[header_index:end], "\n")
    raw = DataFrame(CSV.File(IOBuffer(text); normalizenames=true, silencewarnings=true))
    isempty(raw) && return _empty_rba_tidy()

    date_name = _rba_date_column(raw)
    out = _empty_rba_tidy()
    for name in names(raw)
        name == date_name && continue
        series = string(name)
        for row in eachrow(raw)
            date = _parse_rba_date(row[date_name])
            date === nothing && continue
            value = _parse_abs_float(row[name])
            push!(
                out,
                (
                    :rba,
                    metadata.dataset_id,
                    metadata.title,
                    series,
                    _rba_series_label(series),
                    date,
                    value,
                    _infer_frequency_from_dates(date),
                    missing,
                    ismissing(source_url) ? metadata.source_url : source_url,
                    abspath(path),
                ),
            )
        end
    end
    return out
end

function _read_rba_cash_rate_html(
    path::AbstractString; metadata=_rba_metadata(), source_url=missing
)
    text = read(path, String)
    rows = _rba_cash_rate_rows(text)
    out = DataFrame(;
        provider=Symbol[],
        dataset_id=String[],
        effective_date=Date[],
        change=Union{Missing, Float64}[],
        cash_rate_target=Union{Missing, Float64}[],
        source_url=Union{Missing, String}[],
        source_file=String[],
    )
    for row in rows
        push!(
            out,
            (
                :rba,
                metadata.dataset_id,
                row.effective_date,
                row.change,
                row.cash_rate_target,
                ismissing(source_url) ? metadata.source_url : source_url,
                abspath(path),
            ),
        )
    end
    return out
end

function _read_rba_balance_sheet_html(
    path::AbstractString; metadata=_rba_metadata(), source_url=missing
)
    text = read(path, String)
    doc = _parse_html(text)
    page_text = _clean_discovery_text(_html_text(EzXML.root(doc)))
    as_at = _rba_balance_sheet_date(page_text)
    rows = _rba_balance_sheet_rows(page_text)
    out = DataFrame(;
        provider=Symbol[],
        dataset_id=String[],
        as_at=Union{Missing, Date}[],
        side=String[],
        item=String[],
        value=Union{Missing, Float64}[],
        movement=Union{Missing, Float64}[],
        unit=String[],
        source_url=Union{Missing, String}[],
        source_file=String[],
    )
    for row in rows
        push!(
            out,
            (
                :rba,
                metadata.dataset_id,
                something(as_at, missing),
                row.side,
                row.item,
                row.value,
                row.movement,
                "\$ million",
                ismissing(source_url) ? metadata.source_url : source_url,
                abspath(path),
            ),
        )
    end
    return out
end

function _read_rba_html_tables(
    path::AbstractString; metadata=_rba_metadata(), source_url=missing
)
    doc = _parse_html(read(path, String))
    rows = _html_table_rows(doc)
    df = DataFrame(rows)
    isempty(df) && return df
    df[!, :provider] = fill(:rba, nrow(df))
    df[!, :dataset_id] = fill(metadata.dataset_id, nrow(df))
    df[!, :source_url] = fill(
        ismissing(source_url) ? metadata.source_url : source_url, nrow(df)
    )
    df[!, :source_file] = fill(abspath(path), nrow(df))
    return df
end

function _empty_rba_tidy()
    return DataFrame(;
        provider=Symbol[],
        table_id=String[],
        table_title=String[],
        series_id=String[],
        series=String[],
        date=Date[],
        value=Union{Missing, Float64}[],
        frequency=String[],
        unit=Union{Missing, String}[],
        source_url=Union{Missing, String}[],
        source_file=String[],
    )
end

function _rba_metadata(row=nothing)
    row === nothing && return (dataset_id="", title="", source_url=missing)
    return (
        dataset_id=String(row.dataset_id),
        title=String(row.title),
        source_url=String(row.url),
    )
end

function _rba_csv_header_index(lines)
    for (index, line) in enumerate(lines)
        fields = split(line, ',')
        length(fields) > 1 || continue
        first_field = lowercase(strip(first(fields), [' ', '"']))
        if first_field in ("date", "month", "quarter", "year") ||
            occursin("date", first_field)
            return index
        end
    end
    return 1
end

function _rba_date_column(df::DataFrame)
    for name in names(df)
        lower = lowercase(string(name))
        if lower in ("date", "month", "quarter", "year") || occursin("date", lower)
            return name
        end
    end
    return first(names(df))
end

function _parse_rba_date(value)
    ismissing(value) && return nothing
    value isa Date && return value
    value isa DateTime && return Date(value)
    text = strip(string(value))
    isempty(text) && return nothing
    parsed = _parse_abs_period(text)
    parsed === nothing || return parsed.date
    for fmt in (
        dateformat"d u yyyy",
        dateformat"d U yyyy",
        dateformat"u yyyy",
        dateformat"U yyyy",
        dateformat"yyyy-mm-dd",
        dateformat"dd/mm/yyyy",
    )
        try
            return Date(text, fmt)
        catch
        end
    end
    if occursin(r"^\d{4}$", text)
        year = tryparse(Int, text)
        year === nothing || return Date(year, 1, 1)
    end
    return nothing
end

function _infer_frequency_from_dates(date::Date)
    day(date) == 1 && month(date) in (1, 4, 7, 10) && return "quarterly"
    day(date) == 1 && return "monthly"
    return "daily"
end

function _rba_series_label(series::AbstractString)
    text = replace(series, '_' => ' ')
    return strip(text)
end

function _rba_table_id(label::AbstractString, url::AbstractString)
    for text in (label, basename(split(url, '?'; limit=2)[1]))
        match_value = match(r"(?i)\b([a-z]\d+(?:\.\d+)*)\b", text)
        match_value === nothing || return uppercase(match_value.captures[1])
    end
    return nothing
end

function _rba_table_title(label::AbstractString, table_id::AbstractString)
    escaped = replace(table_id, "." => "\\.")
    suffix = Regex("\\s*[–-]\\s*" * escaped * "\\b", "i")
    cleaned = replace(label, suffix => "")
    cleaned = strip(cleaned)
    return isempty(cleaned) ? table_id : cleaned
end

function _looks_like_rba_table_page(url::AbstractString, label::AbstractString)
    occursin("/statistics/tables/", lowercase(url)) || return false
    _looks_like_rba_data_url(url) && return false
    return _rba_table_id(label, url) !== nothing
end

function _looks_like_rba_data_url(url::AbstractString)
    lower = lowercase(url)
    return occursin("/statistics/tables/", lower) &&
           occursin(r"\.(csv|xls|xlsx)(\?|$)", lower)
end

function _rba_cash_rate_rows(text::AbstractString)
    rows = NamedTuple[]
    for match_value in eachmatch(
        r"(\d{1,2}\s+[A-Z][a-z]+\s+\d{4})\s+([+-]?\d+(?:\.\d+)?)\s+([+-]?\d+(?:\.\d+)?)",
        text,
    )
        effective_date = _parse_rba_date(match_value.captures[1])
        effective_date === nothing && continue
        push!(
            rows,
            (
                effective_date=effective_date,
                change=_parse_abs_float(match_value.captures[2]),
                cash_rate_target=_parse_abs_float(match_value.captures[3]),
            ),
        )
    end
    return rows
end

function _rba_balance_sheet_date(text::AbstractString)
    match_value = match(
        r"At close of business on [A-Za-z]+,\s+(\d{1,2}\s+[A-Z][a-z]+\s+\d{4})", text
    )
    match_value === nothing && return nothing
    return _parse_rba_date(match_value.captures[1])
end

function _rba_balance_sheet_rows(text::AbstractString)
    segment_match = match(r"\$ million\s+(.*?)\s+The Bank's liabilities", text)
    segment_match === nothing && return NamedTuple[]
    segment = segment_match.captures[1]
    pattern = r"([A-Za-z][A-Za-z '\(\),&-]+?)\s+(-?[\d,]+)\s+(-?[\d,]+)"
    matches = collect(eachmatch(pattern, segment))
    rows = NamedTuple[]
    for (index, match_value) in enumerate(matches)
        item = strip(match_value.captures[1])
        item = replace(item, r"^Liabilities and Equity Movement Assets Movement\s+"i => "")
        value = _parse_abs_float(match_value.captures[2])
        movement = _parse_abs_float(match_value.captures[3])
        side = index <= cld(length(matches), 2) ? "liabilities_and_equity" : "assets"
        push!(rows, (side=side, item=item, value=value, movement=movement))
    end
    return rows
end

function _html_table_rows(doc)
    rows = NamedTuple[]
    for table in _html_findall(doc, "//table")
        raw_rows = [
            [
                _clean_discovery_text(_html_text(cell)) for
                cell in _html_findall(row, "./th|./td")
            ] for row in _html_findall(table, ".//tr")
        ]
        isempty(raw_rows) && continue
        header = _column_names(first(raw_rows))
        for raw in raw_rows[2:end]
            isempty(raw) && continue
            values = Any[get(raw, index, missing) for index in eachindex(header)]
            push!(rows, NamedTuple{Tuple(header)}(Tuple(values)))
        end
    end
    return rows
end
