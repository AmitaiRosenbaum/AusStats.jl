const ABS_SEED_CATALOGUES = [
    (
        cat_no="6202.0",
        title="Labour Force, Australia",
        description="Monthly labour force estimates including employment, unemployment, participation, hours worked, and related time series.",
        page_url="https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia",
        file_title="Table 1. Labour force status by Sex, Australia - Trend, Seasonally adjusted and Original",
        url="https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/apr-2026/62020001.xlsx",
        filename="6202.0_labour_force_table_001.xlsx",
        table_no="1",
        is_timeseries=true,
        is_cube=false,
    ),
    (
        cat_no="6401.0",
        title="Consumer Price Index, Australia",
        description="Quarterly consumer price inflation measures including CPI groups, capital cities, and analytical series.",
        page_url="https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia",
        file_title="Table 1. CPI: All groups, index numbers and percentage changes",
        url="https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia/apr-2026/640101.xlsx",
        filename="6401.0_cpi_table_001.xlsx",
        table_no="1",
        is_timeseries=true,
        is_cube=false,
    ),
    (
        cat_no="5206.0",
        title="Australian National Accounts",
        description="Quarterly national income, expenditure, product, GDP, and related national accounts time series.",
        page_url="https://www.abs.gov.au/statistics/economy/national-accounts/australian-national-accounts-national-income-expenditure-and-product",
        file_title="Key Aggregates",
        url="https://www.abs.gov.au/statistics/economy/national-accounts/australian-national-accounts-national-income-expenditure-and-product/mar-2026/5206001_Key_Aggregates.xlsx",
        filename="5206.0_national_accounts_key_aggregates.xlsx",
        table_no="1",
        is_timeseries=true,
        is_cube=false,
    ),
    (
        cat_no="6345.0",
        title="Wage Price Index, Australia",
        description="Quarterly wage price indexes by sector, state, industry, and original/seasonally adjusted trend series.",
        page_url="https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/wage-price-index-australia",
        file_title="Tables 2b to 9b. All quarterly series",
        url="https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/wage-price-index-australia/mar-2026/63450Table2bto9b.xlsx",
        filename="6345.0_wage_price_index_all_quarterly_series.xlsx",
        table_no="2",
        is_timeseries=true,
        is_cube=false,
    ),
]

"""
    refresh_abs!()

Refresh the local ABS catalogue/file index and return the discovered files as a
`DataFrame`. Seed catalogue entries are retained as an offline fallback.
"""
function refresh_abs!()
    rows = Vector{NamedTuple}()

    for seed in ABS_SEED_CATALOGUES
        append!(rows, _discover_seed_files(seed))
    end

    isempty(rows) && append!(rows, _seed_file_rows())
    df = _file_rows_dataframe(rows)
    _write_index(df)
    return df
end

"""
    catalogues(; refresh=false)

Return known ABS catalogues as a `DataFrame`.
"""
function catalogues(; refresh::Bool=false)
    indexed = _abs_index(; refresh)
    out = DataFrame(;
        cat_no=String[],
        title=String[],
        description=String[],
        page_url=String[],
        supported=Bool[],
    )

    for group in groupby(indexed, :cat_no; sort=true)
        first_row = first(group)
        push!(
            out,
            (
                first_row.cat_no,
                first_row.title,
                first_row.description,
                first_row.page_url,
                true,
            ),
        )
    end

    return out
end

"""
    files(cat_no=nothing; refresh=false)

Return known downloadable ABS files. When `cat_no` is supplied, only files for
that catalogue are returned.
"""
function files(cat_no=nothing; refresh::Bool=false)
    df = _abs_index(; refresh)
    cat_no === nothing && return df
    needle = lowercase(strip(string(cat_no)))
    return df[lowercase.(df.cat_no) .== needle, :]
end

"""
    releases(cat_no; refresh=false)

Return known ABS releases for `cat_no` as a `DataFrame`. `release_date` values
are `Date`s representing the release month.
"""
function releases(cat_no::AbstractString; refresh::Bool=false)
    return _release_index(cat_no; refresh)
end

"""
    search_abs(query; refresh=false)

Search known ABS catalogues and downloadable files.
"""
function search_abs(query::AbstractString; refresh::Bool=false)
    needle = lowercase(strip(query))
    df = _abs_index(; refresh)
    isempty(needle) && return df

    keep = map(eachrow(df)) do row
        haystack = lowercase(
            join(
                (
                    row.cat_no,
                    row.title,
                    row.description,
                    row.file_title,
                    row.table_title,
                    row.filename,
                ),
                " ",
            ),
        )
        occursin(needle, haystack)
    end

    return df[keep, :]
end

"""
    download_abs(cat_no; file=nothing, release=:latest, dest=default_cache_dir(), force=false)

Download an ABS time-series workbook for `cat_no` and return the local path.
"""
function download_abs(
    cat_no::AbstractString;
    file=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    row = _select_file(cat_no; file, release, cube=false)
    return _download_file(
        row.url; dest=joinpath(dest, "workbooks"), filename=row.filename, force
    )
end

"""
    download_cube(source; cube=nothing, release=:latest, dest=default_cache_dir(), force=false)

Download an ABS data cube from a catalogue number or direct URL and return the
local path.
"""
function download_cube(
    source::AbstractString;
    cube=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    if _is_url(source)
        return _download_file(source; dest=joinpath(dest, "cubes"), force)
    end

    row = _select_file(source; file=cube, release, cube=true)
    return _download_file(
        row.url; dest=joinpath(dest, "cubes"), filename=row.filename, force
    )
end

function _select_file(
    cat_no::AbstractString; file=nothing, release=:latest, cube::Bool=false
)
    df =
        release isa Date ? _files_for_release(cat_no, release; strict=false) : files(cat_no)
    if isempty(df)
        df = if release isa Date
            _files_for_release(cat_no, release; refresh=true, strict=true)
        else
            files(cat_no; refresh=true)
        end
    end
    if isempty(df)
        if release isa Date
            throw(
                ArgumentError(
                    "no downloadable files found for catalogue `$cat_no` and release `$release`",
                ),
            )
        end
        throw(ArgumentError("no ABS files found for catalogue `$cat_no`"))
    end

    kind_keep = cube ? df.is_cube : df.is_timeseries
    candidates = df[kind_keep, :]
    isempty(candidates) && throw(
        ArgumentError(
            "no $(cube ? "data cube" : "time-series workbook") files found for catalogue `$cat_no`",
        ),
    )

    if release isa Date
        # Date-based release selection is handled by `_files_for_release`.
    elseif release !== :latest
        release_text = lowercase(strip(string(release)))
        candidates = candidates[lowercase.(candidates.release_date) .== release_text, :]
        isempty(candidates) && throw(
            ArgumentError("no files found for catalogue `$cat_no` and release `$release`"),
        )
    end

    if file !== nothing
        request = lowercase(strip(string(file)))
        keep = map(eachrow(candidates)) do row
            occursin(request, lowercase(row.file_title)) ||
                occursin(request, lowercase(row.filename)) ||
                (!ismissing(row.table_no) && request == lowercase(string(row.table_no)))
        end
        candidates = candidates[keep, :]
        isempty(candidates) &&
            throw(ArgumentError("no file matched `$file` for catalogue `$cat_no`"))
    end

    if !cube && file === nothing
        table_one = candidates[candidates.table_no .== "1", :]
        isempty(table_one) || (candidates = table_one)
    end

    sorted = sort(candidates, [:release_date, :filename]; rev=[true, false])
    return first(eachrow(sorted))
end

function _files_for_release(
    cat_no::AbstractString, release::Date; refresh::Bool=false, strict::Bool=false
)
    if !refresh
        cached_files = _read_release_file_index(cat_no, release)
        cached_files === nothing || return cached_files
    end

    release_rows = releases(cat_no; refresh)
    if isempty(release_rows)
        return _empty_file_rows_dataframe()
    end

    matches = release_rows[release_rows.release_date .== release, :]
    if isempty(matches)
        strict && throw(
            ArgumentError(
                _missing_release_message(cat_no, release, release_rows.release_date)
            ),
        )
        return _empty_file_rows_dataframe()
    end

    rows = NamedTuple[]
    seed = _seed_for_catalogue(cat_no)
    for row in eachrow(matches)
        html = try
            _http_text(row.release_url)
        catch
            ""
        end
        isempty(html) && continue
        doc = _parse_html(html)
        title = isempty(row.title) ? seed.title : row.title
        append!(
            rows,
            _discover_files_from_doc(
                doc, seed; title, description=seed.description, page_url=row.release_url
            ),
        )
    end

    df = _file_rows_dataframe(rows)
    filtered = isempty(df) ? df : df[df.release_date .== _release_key(release), :]
    isempty(filtered) || _write_release_file_index(cat_no, release, filtered)
    return filtered
end

function _download_file(
    url::AbstractString; dest::AbstractString=tempdir(), filename=nothing, force::Bool=false
)
    mkpath(dest)
    target = joinpath(dest, something(filename, _url_filename(url)))

    if isfile(target) && !force
        return target
    end

    return Downloads.download(url, target)
end

function _abs_index(; refresh::Bool=false)
    refresh && return refresh_abs!()
    cached = _read_index()
    cached === nothing || return cached
    return _file_rows_dataframe(_seed_file_rows())
end

function _write_index(df::DataFrame)
    path = _index_path()
    mkpath(dirname(path))
    rows = [Dict(String(name) => row[name] for name in names(df)) for row in eachrow(df)]
    open(path, "w") do io
        JSON3.write(io, rows)
    end
    return path
end

function _read_index()
    path = _index_path()
    isfile(path) || return nothing
    parsed = JSON3.read(read(path, String))
    rows = NamedTuple[]
    for item in parsed
        table_title = if hasproperty(item, :table_title)
            String(item.table_title)
        else
            String(item.file_title)
        end
        push!(
            rows,
            _file_row(;
                cat_no=String(item.cat_no),
                title=String(item.title),
                description=String(item.description),
                page_url=String(item.page_url),
                release_date=String(item.release_date),
                file_title=String(item.file_title),
                url=String(item.url),
                filename=String(item.filename),
                file_type=String(item.file_type),
                table_no=String(item.table_no),
                table_title,
                is_timeseries=Bool(item.is_timeseries),
                is_cube=Bool(item.is_cube),
            ),
        )
    end
    return _file_rows_dataframe(rows)
end

function _index_path()
    return joinpath(_cache_subdir(:indexes), "abs_files.json")
end

function _release_index(cat_no::AbstractString; refresh::Bool=false)
    refresh && return _refresh_release_index(cat_no)
    cached = _read_release_index(cat_no)
    cached === nothing || return cached
    seed = _seed_for_catalogue(cat_no)
    return _release_rows_dataframe([_seed_release_row(seed)])
end

function _refresh_release_index(cat_no::AbstractString)
    seed = _seed_for_catalogue(cat_no)
    rows = NamedTuple[]

    try
        html = _http_text(seed.page_url)
        doc = _parse_html(html)
        append!(rows, _discover_releases_from_doc(doc, seed))
        for archive_url in _archive_links(doc, seed)
            archive_html = _http_text(archive_url)
            archive_doc = _parse_html(archive_html)
            append!(rows, _discover_releases_from_doc(archive_doc, seed))
        end
    catch
        rows = NamedTuple[]
    end

    if isempty(rows)
        push!(rows, _seed_release_row(seed))
    end

    df = _release_rows_dataframe(rows)
    _write_release_index(cat_no, df)
    return df
end

function _write_release_index(cat_no::AbstractString, df::DataFrame)
    path = _release_index_path(cat_no)
    mkpath(dirname(path))
    rows = [
        Dict(
            "cat_no" => row.cat_no,
            "title" => row.title,
            "release_date" => string(row.release_date),
            "release_url" => row.release_url,
        ) for row in eachrow(df)
    ]
    open(path, "w") do io
        JSON3.write(io, rows)
    end
    return path
end

function _read_release_index(cat_no::AbstractString)
    path = _release_index_path(cat_no)
    isfile(path) || return nothing
    parsed = JSON3.read(read(path, String))
    rows = NamedTuple[]
    for item in parsed
        date = tryparse(Date, String(item.release_date), dateformat"yyyy-mm-dd")
        date === nothing && continue
        push!(
            rows,
            _release_row(;
                cat_no=String(item.cat_no),
                title=String(item.title),
                release_date=date,
                release_url=String(item.release_url),
            ),
        )
    end
    return _release_rows_dataframe(rows)
end

function _release_index_path(cat_no::AbstractString)
    return joinpath(_cache_subdir(:indexes), "releases_" * _safe_filename(cat_no) * ".json")
end

function _write_release_file_index(cat_no::AbstractString, release::Date, df::DataFrame)
    path = _release_file_index_path(cat_no, release)
    mkpath(dirname(path))
    rows = [Dict(String(name) => row[name] for name in names(df)) for row in eachrow(df)]
    open(path, "w") do io
        JSON3.write(io, rows)
    end
    return path
end

function _read_release_file_index(cat_no::AbstractString, release::Date)
    path = _release_file_index_path(cat_no, release)
    isfile(path) || return nothing
    parsed = JSON3.read(read(path, String))
    rows = NamedTuple[]
    for item in parsed
        push!(
            rows,
            _file_row(;
                cat_no=String(item.cat_no),
                title=String(item.title),
                description=String(item.description),
                page_url=String(item.page_url),
                release_date=String(item.release_date),
                file_title=String(item.file_title),
                url=String(item.url),
                filename=String(item.filename),
                file_type=String(item.file_type),
                table_no=String(item.table_no),
                table_title=if hasproperty(item, :table_title)
                    String(item.table_title)
                else
                    String(item.file_title)
                end,
                is_timeseries=Bool(item.is_timeseries),
                is_cube=Bool(item.is_cube),
            ),
        )
    end
    return _file_rows_dataframe(rows)
end

function _release_file_index_path(cat_no::AbstractString, release::Date)
    filename =
        "release_files_" * _safe_filename(cat_no) * "_" * _release_key(release) * ".json"
    return joinpath(_cache_subdir(:indexes), filename)
end

function _discover_releases_from_doc(doc, seed)
    by_url = Dict{String, NamedTuple}()

    for link in _html_links(doc)
        href = _html_attr(link, "href")
        url = _absolute_url(href)
        _looks_like_release_url(url, seed) || continue

        label = _clean_discovery_text(_html_text(link))
        release_date = something(
            _release_date_from_text(label), _release_date_from_url(url), nothing
        )
        release_date === nothing && continue

        row = _release_row(;
            cat_no=seed.cat_no,
            title=isempty(label) ? seed.title : label,
            release_date,
            release_url=_normalise_page_url(url),
        )
        by_url[row.release_url] = row
    end

    values_rows = collect(values(by_url))
    isempty(values_rows) && push!(values_rows, _seed_release_row(seed))
    return values_rows
end

function _archive_links(doc, seed)
    urls = String[]

    for link in _html_links(doc)
        href = _html_attr(link, "href")
        label = lowercase(_clean_discovery_text(_html_text(link)))
        url = _normalise_page_url(_absolute_url(href))
        startswith(url, seed.page_url) || continue
        haystack = lowercase(url * " " * label)
        if occursin("archive", haystack) ||
            occursin("previous", haystack) ||
            occursin("past releases", haystack)
            push!(urls, url)
        end
    end

    return unique(urls)
end

function _release_row(; cat_no, title, release_date::Date, release_url)
    return (
        cat_no=String(cat_no),
        title=String(title),
        release_date=release_date,
        release_url=String(release_url),
    )
end

function _seed_release_row(seed)
    release_date = something(_release_date_from_url(seed.url), Date(1, 1, 1))
    return _release_row(;
        cat_no=seed.cat_no,
        title=seed.title,
        release_date,
        release_url=_release_page_from_file_url(seed.url),
    )
end

function _release_rows_dataframe(rows)
    df = DataFrame(;
        cat_no=[row.cat_no for row in rows],
        title=[row.title for row in rows],
        release_date=[row.release_date for row in rows],
        release_url=[row.release_url for row in rows],
    )
    return sort(unique(df, [:release_date, :release_url]), :release_date)
end

function _discover_seed_files(seed)
    rows = NamedTuple[]
    try
        html = _http_text(seed.page_url)
        doc = _parse_html(html)
        title = something(_first_text(doc, "h1"), seed.title)
        description = something(_meta_content(doc, "description"), seed.description)
        append!(
            rows,
            _discover_files_from_doc(doc, seed; title, description, page_url=seed.page_url),
        )

        if isempty(rows)
            for release_url in _release_links(doc, seed)
                release_html = _http_text(release_url)
                release_doc = _parse_html(release_html)
                append!(
                    rows,
                    _discover_files_from_doc(
                        release_doc, seed; title, description, page_url=release_url
                    ),
                )
                isempty(rows) || break
            end
        end
    catch
        return [_seed_to_row(seed)]
    end

    isempty(rows) && push!(rows, _seed_to_row(seed))
    return rows
end

function _discover_files_from_doc(doc, seed; title, description, page_url)
    rows = NamedTuple[]
    release_date = something(_release_from_url(page_url), _release_from_url(seed.url), "")
    contexts = _download_link_contexts(doc)
    by_url = Dict{String, NamedTuple}()

    for link in _html_links(doc)
        href = _html_attr(link, "href")
        occursin(r"\.(xlsx|xls|csv)(\?|$)"i, href) || continue
        url = _normalise_file_url(_absolute_url(href))
        label = _clean_discovery_text(_html_text(link))
        context = get(contexts, url, "")
        file_title = _best_file_title(label, context, url)
        table_title = _best_table_title(file_title, context, url)
        row = _file_row(;
            cat_no=seed.cat_no,
            title,
            description,
            page_url,
            release_date=something(_release_from_url(url), release_date),
            file_title,
            url,
            filename=_indexed_filename(seed.cat_no, url, file_title),
            file_type=_file_type(url, file_title),
            table_no=something(
                _table_no(file_title),
                _table_no(context),
                _table_no(url),
                _table_no_from_filename(seed.cat_no, url),
                "",
            ),
            table_title,
            is_timeseries=!_looks_like_cube(file_title, url),
            is_cube=_looks_like_cube(file_title, url),
        )
        by_url[url] = _better_file_row(get(by_url, url, nothing), row)
    end

    append!(rows, values(by_url))
    return rows
end

function _release_links(doc, seed)
    urls = String[]
    seed_path = replace(seed.page_url, ABS_BASE_URL => "")
    title_key = lowercase(first(split(seed.title, ",")))

    for link in _html_links(doc)
        href = _html_attr(link, "href")
        label = lowercase(strip(_html_text(link)))
        url = _absolute_url(href)
        path_match =
            startswith(url, seed.page_url * "/") || startswith(href, seed_path * "/")
        title_match = occursin(title_key, label)
        if path_match && title_match
            push!(urls, url)
        end
    end

    return unique(urls)
end

function _seed_file_rows()
    return [_seed_to_row(seed) for seed in ABS_SEED_CATALOGUES]
end

function _seed_to_row(seed)
    return _file_row(;
        cat_no=seed.cat_no,
        title=seed.title,
        description=seed.description,
        page_url=seed.page_url,
        release_date=something(_release_from_url(seed.url), ""),
        file_title=seed.file_title,
        url=seed.url,
        filename=seed.filename,
        file_type="xlsx",
        table_no=seed.table_no,
        table_title=seed.file_title,
        is_timeseries=seed.is_timeseries,
        is_cube=seed.is_cube,
    )
end

function _file_row(;
    cat_no,
    title,
    description,
    page_url,
    release_date,
    file_title,
    url,
    filename,
    file_type,
    table_no,
    table_title=file_title,
    is_timeseries,
    is_cube,
)
    return (
        cat_no=String(cat_no),
        title=String(title),
        description=String(description),
        page_url=String(page_url),
        release_date=String(release_date),
        file_title=String(file_title),
        url=String(url),
        filename=String(filename),
        file_type=String(file_type),
        table_no=String(table_no),
        table_title=String(table_title),
        is_timeseries=Bool(is_timeseries),
        is_cube=Bool(is_cube),
    )
end

function _file_rows_dataframe(rows)
    isempty(rows) && return _empty_file_rows_dataframe()
    return DataFrame(;
        cat_no=[row.cat_no for row in rows],
        title=[row.title for row in rows],
        description=[row.description for row in rows],
        page_url=[row.page_url for row in rows],
        release_date=[row.release_date for row in rows],
        file_title=[row.file_title for row in rows],
        url=[row.url for row in rows],
        filename=[row.filename for row in rows],
        file_type=[row.file_type for row in rows],
        table_no=[row.table_no for row in rows],
        table_title=[row.table_title for row in rows],
        is_timeseries=[row.is_timeseries for row in rows],
        is_cube=[row.is_cube for row in rows],
    )
end

function _empty_file_rows_dataframe()
    return DataFrame(;
        cat_no=String[],
        title=String[],
        description=String[],
        page_url=String[],
        release_date=String[],
        file_title=String[],
        url=String[],
        filename=String[],
        file_type=String[],
        table_no=String[],
        table_title=String[],
        is_timeseries=Bool[],
        is_cube=Bool[],
    )
end

function _download_link_contexts(doc)
    contexts = Dict{String, String}()

    for selector in (
        "tr",
        "li",
        "p",
        ".download",
        ".downloads",
        ".field--name-field-downloads",
        "article",
        "section",
    )
        for node in _html_context_nodes(doc, selector)
            text = _clean_discovery_text(_html_text(node))
            isempty(text) && continue
            download_links = [
                link for link in _html_links(node) if
                occursin(r"\.(xlsx|xls|csv)(\?|$)"i, _html_attr(link, "href"))
            ]
            download_urls = unique([
                _normalise_file_url(_absolute_url(_html_attr(link, "href"))) for
                link in download_links
            ])
            for link in download_links
                href = _html_attr(link, "href")
                url = _normalise_file_url(_absolute_url(href))
                previous = get(contexts, url, "")
                length(download_urls) > 1 && !isempty(previous) && continue
                if _context_score(text) > _context_score(previous)
                    contexts[url] = text
                end
            end
        end
    end

    return contexts
end

function _parse_html(html::AbstractString)
    return Logging.with_logger(Logging.NullLogger()) do
        EzXML.parsehtml(html; nowarning=true)
    end
end

function _html_findall(node, xpath::AbstractString)
    return EzXML.findall(xpath, node)
end

function _html_links(node)
    return _html_findall(node, ".//a[@href]")
end

function _html_context_nodes(doc, selector::AbstractString)
    return _html_findall(doc, _selector_xpath(selector))
end

function _html_text(node)
    return EzXML.nodecontent(node)
end

function _html_attr(node, name::AbstractString)
    return haskey(node, name) ? string(node[name]) : ""
end

function _selector_xpath(selector::AbstractString)
    selector == "h1" && return "//h1"
    selector == "tr" && return "//tr"
    selector == "li" && return "//li"
    selector == "p" && return "//p"
    selector == "article" && return "//article"
    selector == "section" && return "//section"
    selector == ".download" && return _class_xpath("download")
    selector == ".downloads" && return _class_xpath("downloads")
    selector == ".field--name-field-downloads" &&
        return _class_xpath("field--name-field-downloads")
    throw(ArgumentError(string("unsupported HTML selector `", selector, "`")))
end

function _class_xpath(class::AbstractString)
    return string(
        "//*[contains(concat(' ', normalize-space(@class), ' '), ' ", class, " ')]"
    )
end

function _best_file_title(
    label::AbstractString, context::AbstractString, url::AbstractString
)
    label = _clean_discovery_text(label)
    context = _clean_discovery_text(context)

    if !_generic_download_label(label)
        return label
    end

    cleaned_context = _clean_context_title(context, label)
    if !_generic_download_label(cleaned_context)
        return cleaned_context
    end

    filename_title = _title_from_filename(url)
    return isempty(filename_title) ? _url_filename(url) : filename_title
end

function _best_table_title(
    file_title::AbstractString, context::AbstractString, url::AbstractString
)
    context_title = _clean_context_title(context, "")
    if !_generic_download_label(context_title) && _table_no(context_title) !== nothing
        return context_title
    end
    return file_title
end

function _better_file_row(existing, candidate)
    existing === nothing && return candidate
    existing_score = _title_score(existing.file_title) + _title_score(existing.table_title)
    candidate_score =
        _title_score(candidate.file_title) + _title_score(candidate.table_title)
    return candidate_score >= existing_score ? candidate : existing
end

function _clean_context_title(context::AbstractString, label::AbstractString)
    text = _clean_discovery_text(context)
    isempty(text) && return ""

    if !isempty(label)
        text = replace(text, label => " ")
    end
    text = replace(text, r"(?i)(download)\s*(xlsx|xls|csv)?\s*(\[[^\]]+\])?" => s" \1 ")
    text = replace(text, r"(?i)\bdownload\b\s*(xlsx|xls|csv)?\s*(\[[^\]]+\])?" => " ")
    text = replace(text, r"(?i)\b(xlsx|xls|csv)\b\s*(\[[^\]]+\])?" => " ")
    text = replace(text, r"\s+" => " ")
    text = strip(text, [' ', '-', '|', ':'])
    return text
end

function _clean_discovery_text(value)
    text = replace(strip(string(value)), '\u00a0' => ' ')
    text = replace(text, r"\s+" => " ")
    return strip(text)
end

function _generic_download_label(value::AbstractString)
    text = lowercase(_clean_discovery_text(value))
    isempty(text) && return true
    text = replace(text, r"\[[^\]]+\]" => "")
    text = replace(text, r"\s+" => " ")
    text = strip(text)
    return text in (
        "download", "download xlsx", "download xls", "download csv", "xlsx", "xls", "csv"
    ) || occursin(r"^download\s+(xlsx|xls|csv)$", text)
end

function _context_score(value::AbstractString)
    text = _clean_discovery_text(value)
    isempty(text) && return 0
    score = max(0, 300 - length(text))
    _table_no(text) !== nothing && (score += 500)
    _generic_download_label(text) && (score -= 500)
    return score
end

function _title_score(value::AbstractString)
    text = _clean_discovery_text(value)
    isempty(text) && return 0
    score = min(length(text), 200)
    _generic_download_label(text) && (score -= 1000)
    _table_no(text) !== nothing && (score += 500)
    return score
end

function _normalise_file_url(url::AbstractString)
    clean = split(strip(url), '#'; limit=2)[1]
    return split(clean, '?'; limit=2)[1]
end

function _normalise_page_url(url::AbstractString)
    clean = split(strip(url), '#'; limit=2)[1]
    return split(clean, '?'; limit=2)[1]
end

function _title_from_filename(url::AbstractString)
    stem = splitext(_url_filename(url))[1]
    stem = replace(stem, r"^[0-9]+[A-Za-z]*_?" => "")
    stem = replace(stem, r"[_-]+" => " ")
    stem = replace(stem, r"\s+" => " ")
    return strip(stem)
end

function _first_text(doc, selector::AbstractString)
    nodes = _html_findall(doc, _selector_xpath(selector))
    isempty(nodes) && return nothing
    text = strip(_html_text(first(nodes)))
    return isempty(text) ? nothing : text
end

function _meta_content(doc, name::AbstractString)
    nodes = _html_findall(doc, "//meta[@name]")
    nodes = [
        node for node in nodes if lowercase(_html_attr(node, "name")) == lowercase(name)
    ]
    isempty(nodes) && return nothing
    content = _html_attr(first(nodes), "content")
    text = strip(content)
    return isempty(text) ? nothing : text
end

function _indexed_filename(
    cat_no::AbstractString, url::AbstractString, label::AbstractString
)
    ext = splitext(_url_filename(url))[2]
    base = isempty(strip(label)) ? splitext(_url_filename(url))[1] : _safe_filename(label)
    return _safe_filename(cat_no * "_" * base) * ext
end

function _file_type(url::AbstractString, label::AbstractString)
    ext = lowercase(strip(splitext(_url_filename(url))[2], '.'))
    isempty(ext) || return ext
    _looks_like_cube(label, url) && return "cube"
    return "unknown"
end

function _looks_like_cube(label::AbstractString, url::AbstractString)
    text = lowercase(label * " " * url)
    return occursin("data cube", text) ||
           occursin("datacube", text) ||
           occursin("cube", text)
end

function _table_no(value::AbstractString)
    m = match(r"(?i)\btables?\s*([0-9]+[a-z]?)\b", value)
    m === nothing && return nothing
    return m.captures[1]
end

function _table_no_from_filename(cat_no::AbstractString, url::AbstractString)
    stem = splitext(_url_filename(url))[1]
    digits = replace(cat_no, r"\D" => "")
    m = match(Regex("^" * digits * "0*([0-9]{1,3}[a-z]?)", "i"), lowercase(stem))
    m === nothing && return nothing
    table = m.captures[1]
    table === nothing && return nothing
    parsed = tryparse(Int, replace(table, r"[A-Za-z]" => ""))
    parsed === nothing && return lowercase(table)
    suffix = replace(lowercase(table), r"[0-9]" => "")
    return string(parsed) * suffix
end

function _release_from_url(url::AbstractString)
    m = match(r"/([a-z]{3}-[0-9]{4})/", lowercase(url))
    m === nothing && return nothing
    return m.captures[1]
end

function _release_date_from_url(url::AbstractString)
    key = _release_from_url(url)
    key === nothing && return nothing
    return _release_date_from_text(key)
end

function _release_date_from_text(value::AbstractString)
    text = lowercase(_clean_discovery_text(value))
    m = match(
        r"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[- ]+([0-9]{4})\b", text
    )
    if m !== nothing
        month_text, year_text = m.captures
        (month_text === nothing || year_text === nothing) && return nothing
        return Date(parse(Int, year_text), _release_month_number(month_text), 1)
    end

    m = match(
        r"\b([0-9]{4})[- ]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b", text
    )
    if m !== nothing
        year_text, month_text = m.captures
        (month_text === nothing || year_text === nothing) && return nothing
        return Date(parse(Int, year_text), _release_month_number(month_text), 1)
    end

    return nothing
end

function _release_key(date::Date)
    months = (
        "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"
    )
    return months[month(date)] * "-" * string(year(date))
end

function _release_month_number(month_text::AbstractString)
    months = Dict(
        "jan" => 1,
        "feb" => 2,
        "mar" => 3,
        "apr" => 4,
        "may" => 5,
        "jun" => 6,
        "jul" => 7,
        "aug" => 8,
        "sep" => 9,
        "oct" => 10,
        "nov" => 11,
        "dec" => 12,
    )
    key = lowercase(month_text[1:3])
    return months[key]
end

function _looks_like_release_url(url::AbstractString, seed)
    clean = _normalise_page_url(url)
    startswith(clean, seed.page_url * "/") || return false
    occursin(r"/[a-z]{3}-[0-9]{4}/?$"i, clean) && return true
    return _release_date_from_url(clean) !== nothing
end

function _release_page_from_file_url(url::AbstractString)
    clean = _normalise_file_url(url)
    key = _release_from_url(clean)
    key === nothing && return dirname(clean)
    marker = "/" * key * "/"
    idx = findfirst(marker, clean)
    idx === nothing && return dirname(clean)
    stop = last(idx) - 1
    return clean[1:stop]
end

function _seed_for_catalogue(cat_no::AbstractString)
    key = strip(cat_no)
    for seed in ABS_SEED_CATALOGUES
        seed.cat_no == key && return seed
    end

    known = join(sort([seed.cat_no for seed in ABS_SEED_CATALOGUES]), ", ")
    throw(
        ArgumentError(
            "unsupported ABS catalogue number `$cat_no`; known seed catalogues are: $known"
        ),
    )
end

function _missing_release_message(cat_no::AbstractString, requested::Date, known_dates)
    known = sort(collect(skipmissing(known_dates)))
    isempty(known) &&
        return "no releases are known for catalogue `$cat_no`; refresh the release index and try again"

    nearest = sort(known; by=date -> abs(Dates.value(date - requested)))
    shown = join(string.(first(nearest, min(3, length(nearest)))), ", ")
    return "release $(requested) is not available for catalogue `$cat_no`; nearest known release dates are: $shown"
end
