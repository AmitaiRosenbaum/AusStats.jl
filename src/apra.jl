const APRA_BASE_URL = "https://www.apra.gov.au"
const APRA_STATISTICS_URL =
    APRA_BASE_URL *
    "/news-and-publications?document_type%5B0%5D=bundle%3Astatistical_publication&created=All&sort_bef_combine=created_DESC"

const APRA_SEED_PUBLICATIONS = [
    (
        dataset_id="monthly-authorised-deposit-taking-institution-statistics",
        title="Monthly Authorised Deposit-taking Institution Statistics",
        description="Selected monthly information on the banking business of individual banks within the domestic market.",
        industry="Banking",
        page_url=APRA_BASE_URL *
                 "/news-and-publications/monthly-authorised-deposit-taking-institution-statistics",
        published="29 May 2026",
        files=[
            (
                file_id="monthly-authorised-deposit-taking-institution-statistics-april-2026",
                file_title="Monthly authorised deposit-taking institution statistics April 2026",
                url=APRA_BASE_URL *
                    "/sites/default/files/2026-05/monthly_authorised_deposit-taking_institution_statistics_april_2026.xlsx",
                filename="monthly_authorised_deposit-taking_institution_statistics_april_2026.xlsx",
                file_type="xlsx",
                resource_kind=:dataset,
            ),
            (
                file_id="monthly-authorised-deposit-taking-institution-statistics-back-series",
                file_title="Monthly authorised deposit-taking institution statistics back-series March 2019 - April 2026",
                url=APRA_BASE_URL *
                    "/sites/default/files/2026-05/monthly_authorised_deposit-taking_institution_statistics_back-series_march_2019_to_april_2026.xlsx",
                filename="monthly_authorised_deposit-taking_institution_statistics_back-series_march_2019_to_april_2026.xlsx",
                file_type="xlsx",
                resource_kind=:dataset,
            ),
        ],
    ),
    (
        dataset_id="quarterly-authorised-deposit-taking-institution-statistics",
        title="Quarterly authorised deposit-taking institution statistics",
        description="Quarterly authorised deposit-taking institution performance, centralised publication, and property exposure statistics.",
        industry="Banking",
        page_url=APRA_BASE_URL *
                 "/news-and-publications/quarterly-authorised-deposit-taking-institution-statistics",
        published="12 March 2026",
        files=[
            (
                file_id="quarterly-authorised-deposit-taking-institution-performance",
                file_title="Quarterly authorised deposit-taking institution performance-September 2004 to December 2025",
                url=APRA_BASE_URL *
                    "/sites/default/files/2026-03/quarterly_authorised_deposit-taking_institution_performance_statistics_september_2004_to_december_2025.xlsx",
                filename="quarterly_authorised_deposit-taking_institution_performance_statistics_september_2004_to_december_2025.xlsx",
                file_type="xlsx",
                resource_kind=:dataset,
            ),
            (
                file_id="authorised-deposit-taking-institution-centralised-publication",
                file_title="Authorised deposit-taking institution centralised publication - March 2013 to December 2025",
                url=APRA_BASE_URL *
                    "/sites/default/files/2026-03/authorised_deposit-taking_institution_centralised_publication_march_2013_to_december_2025.xlsx",
                filename="authorised_deposit-taking_institution_centralised_publication_march_2013_to_december_2025.xlsx",
                file_type="xlsx",
                resource_kind=:dataset,
            ),
        ],
    ),
]

"""
    apra_publications(; refresh=false)

Return known APRA statistical publications as a `DataFrame`.
"""
function apra_publications(; refresh::Bool=false)
    return _provider_datasets_from_files(apra_files(; refresh))
end

"""
    apra_files(publication_id=nothing; refresh=false)

Return known APRA statistical publication files. When `publication_id` is
supplied, only matching publication resources are returned.
"""
function apra_files(publication_id=nothing; refresh::Bool=false)
    df = _apra_index(; refresh)
    publication_id === nothing && return df
    needle = lowercase(strip(string(publication_id)))
    keep = map(eachrow(df)) do row
        lowercase(row.dataset_id) == needle ||
            lowercase(row.file_id) == needle ||
            occursin(needle, lowercase(row.title)) ||
            occursin(needle, lowercase(row.file_title)) ||
            occursin(needle, lowercase(row.filename))
    end
    return df[keep, :]
end

"""
    search_apra(query; refresh=false)

Search known APRA statistical publications and downloadable files.
"""
function search_apra(query::AbstractString; refresh::Bool=false)
    needle = lowercase(strip(query))
    df = apra_files(; refresh)
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
    download_apra(publication_id; file=nothing, dest=default_cache_dir(), force=false)

Download an APRA statistical publication file and return the local path.
"""
function download_apra(
    publication_id::AbstractString;
    file=nothing,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    row = _select_apra_file(publication_id; file)
    target_dir = joinpath(dest, "apra")
    if row.file_type in ("html", "htm")
        return _download_text_file(row.url; dest=target_dir, filename=row.filename, force)
    end
    return _download_file(row.url; dest=target_dir, filename=row.filename, force)
end

"""
    read_apra(source; file=nothing, cache=true, cache_parsed=true, refresh=false)

Read APRA data from a publication id, direct URL, or local XLSX/CSV/HTML file.
XLSX workbooks are returned as sheet-shaped `DataFrame`s with APRA provenance.
"""
function read_apra(
    source::AbstractString;
    file=nothing,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    if _is_url(source)
        dest = cache ? _cache_subdir(:apra) : mktempdir()
        path = _download_apra_url(source; dest, force=!cache)
        return _read_apra_file(path; source_url=source, cache_parsed, refresh)
    elseif isfile(source)
        return _read_apra_file(source; cache_parsed, refresh)
    end

    refresh && apra_files(source; refresh=true)
    row = _select_apra_file(source; file)
    row.resource_kind == :document &&
        throw(ArgumentError("APRA file `$(row.file_title)` is a document, not a readable data file"))
    path = if cache
        download_apra(source; file)
    else
        _download_apra_url(row.url; dest=mktempdir(), filename=row.filename, force=true)
    end
    return _read_apra_file(
        path;
        metadata=_apra_metadata(row),
        source_url=row.url,
        cache_parsed,
        refresh,
    )
end

_datasets(::APRAProvider; refresh::Bool=false) = apra_publications(; refresh)
_datafiles(::APRAProvider, dataset_id=nothing; refresh::Bool=false, release=nothing) =
    apra_files(dataset_id; refresh)
_search_data(::APRAProvider, query::AbstractString; refresh::Bool=false) =
    search_apra(query; refresh)
_download_data(
    ::APRAProvider,
    dataset_id::AbstractString;
    file=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
) = download_apra(dataset_id; file, dest, force)
_read_data(
    ::APRAProvider,
    source::AbstractString;
    file=nothing,
    release=:latest,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
) = read_apra(source; file, cache, cache_parsed, refresh)

function _apra_index(; refresh::Bool=false)
    refresh && return refresh_apra!()
    cached = _read_apra_index()
    cached === nothing || return cached
    return _provider_file_rows(_apra_seed_rows())
end

function refresh_apra!()
    rows = NamedTuple[]
    try
        html = _http_text(APRA_STATISTICS_URL)
        doc = _parse_html(html)
        for publication in _discover_apra_publications(doc)
            append!(rows, _discover_apra_publication_files(publication))
        end
    catch
        rows = NamedTuple[]
    end
    isempty(rows) && append!(rows, _apra_seed_rows())
    df = _provider_file_rows(unique(rows))
    _write_apra_index(df)
    return df
end

function _discover_apra_publications(doc)
    publications = Dict{String, NamedTuple}()
    for link in _html_links(doc)
        href = _html_attr(link, "href")
        url = _normalise_page_url(_absolute_url(href; base=APRA_BASE_URL))
        _looks_like_apra_publication_url(url) || continue
        title = _clean_discovery_text(_html_text(link))
        isempty(title) && continue
        dataset_id = _apra_publication_id(url)
        publications[dataset_id] = (
            dataset_id=dataset_id,
            title=title,
            description="APRA statistical publication.",
            industry="",
            page_url=url,
            published="",
        )
    end
    return collect(values(publications))
end

function _discover_apra_publication_files(publication)
    rows = NamedTuple[]
    html = try
        _http_text(publication.page_url)
    catch
        ""
    end
    isempty(html) && return rows
    doc = _parse_html(html)
    page_title = something(_first_text(doc, "h1"), publication.title)
    page_text = _clean_discovery_text(_html_text(EzXML.root(doc)))
    description = _apra_description(page_text, publication.description)
    published = something(_apra_published_date(page_text), publication.published)

    for row in _discover_apra_files_from_doc(
        doc;
        dataset_id=publication.dataset_id,
        title=page_title,
        description,
        page_url=publication.page_url,
        release_date=published,
    )
        push!(rows, row)
    end
    return rows
end

function _discover_apra_files_from_doc(
    doc; dataset_id, title, description, page_url, release_date
)
    rows = NamedTuple[]
    for link in _html_links(doc)
        href = _html_attr(link, "href")
        url = _normalise_file_url(_absolute_url(href; base=APRA_BASE_URL))
        _looks_like_apra_file_url(url) || continue
        label = _clean_discovery_text(_html_text(link))
        file_type = _apra_file_type(url)
        file_title = _apra_file_title(label, url)
        push!(
            rows,
            _provider_file_row(;
                provider=:apra,
                dataset_id,
                title,
                description,
                page_url,
                release_date=something(_apra_date_from_text(label), release_date),
                file_id=_safe_filename(lowercase(file_title)),
                file_title,
                url,
                filename=_url_filename(url),
                file_type,
                resource_kind=file_type == "pdf" ? :document : :dataset,
            ),
        )
    end
    return rows
end

function _apra_seed_rows()
    rows = NamedTuple[]
    for publication in APRA_SEED_PUBLICATIONS
        for file in publication.files
            push!(
                rows,
                _provider_file_row(;
                    provider=:apra,
                    dataset_id=publication.dataset_id,
                    title=publication.title,
                    description=publication.description,
                    page_url=publication.page_url,
                    release_date=publication.published,
                    file_id=file.file_id,
                    file_title=file.file_title,
                    url=file.url,
                    filename=file.filename,
                    file_type=file.file_type,
                    resource_kind=file.resource_kind,
                ),
            )
        end
    end
    return rows
end

function _write_apra_index(df::DataFrame)
    path = _apra_index_path()
    mkpath(dirname(path))
    rows = [Dict(String(name) => row[name] for name in names(df)) for row in eachrow(df)]
    open(path, "w") do io
        JSON3.write(io, rows)
    end
    return path
end

function _read_apra_index()
    path = _apra_index_path()
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

_apra_index_path() = joinpath(_cache_subdir(:indexes), "apra_files.json")

function _select_apra_file(publication_id::AbstractString; file=nothing)
    candidates = apra_files(publication_id)
    isempty(candidates) && (candidates = apra_files(publication_id; refresh=true))
    isempty(candidates) && throw(ArgumentError("no APRA files found for `$publication_id`"))

    if file !== nothing
        request = lowercase(strip(string(file)))
        keep = map(eachrow(candidates)) do row
            lowercase(row.file_id) == request ||
                occursin(request, lowercase(row.file_title)) ||
                occursin(request, lowercase(row.filename))
        end
        candidates = candidates[keep, :]
        isempty(candidates) &&
            throw(ArgumentError("no APRA file matched `$file` for `$publication_id`"))
    end

    data_files = candidates[candidates.resource_kind .== :dataset, :]
    isempty(data_files) || (candidates = data_files)
    return first(eachrow(sort(candidates, [:file_type, :filename])))
end

function _download_apra_url(
    url::AbstractString; dest::AbstractString=tempdir(), filename=nothing, force::Bool=false
)
    lower = lowercase(split(url, '?'; limit=2)[1])
    if endswith(lower, ".html") || endswith(lower, ".htm")
        return _download_text_file(url; dest, filename, force)
    end
    return _download_file(url; dest, filename=something(filename, _url_filename(url)), force)
end

function _read_apra_file(
    path::AbstractString;
    metadata=_apra_metadata(),
    source_url=missing,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    options = (metadata=metadata, source_url=source_url)
    return _with_parsed_cache(
        path; kind=:read_apra, options, cache_parsed, refresh
    ) do
        lower = lowercase(path)
        if endswith(lower, ".xlsx") || endswith(lower, ".xls")
            return _read_apra_workbook(path; metadata, source_url)
        elseif endswith(lower, ".csv")
            return _read_apra_csv(path; metadata, source_url)
        elseif endswith(lower, ".html") || endswith(lower, ".htm")
            return _read_apra_html(path; metadata, source_url)
        elseif endswith(lower, ".pdf")
            throw(ArgumentError("APRA PDF files can be downloaded but not read as data"))
        end
        throw(ArgumentError("unsupported APRA file type for `$path`; expected XLSX, CSV, or HTML"))
    end
end

function _read_apra_workbook(path::AbstractString; metadata=_apra_metadata(), source_url=missing)
    out = DataFrame()
    XLSX.openxlsx(path) do xf
        for sheetname in XLSX.sheetnames(xf)
            table = _read_rows_as_sheet(_sheet_rows(xf[sheetname]))
            isempty(table) && continue
            _add_apra_provenance!(table, sheetname, path, metadata, source_url)
            if isempty(out)
                out = table
            else
                append!(out, table; cols=:union)
            end
        end
    end
    return out
end

function _read_apra_csv(path::AbstractString; metadata=_apra_metadata(), source_url=missing)
    table = DataFrame(CSV.File(path; normalizenames=true, silencewarnings=true))
    isempty(table) && return table
    _add_apra_provenance!(table, missing, path, metadata, source_url)
    return table
end

function _read_apra_html(path::AbstractString; metadata=_apra_metadata(), source_url=missing)
    df = DataFrame(_html_table_rows(_parse_html(read(path, String))))
    isempty(df) && return df
    _add_apra_provenance!(df, missing, path, metadata, source_url)
    return df
end

function _add_apra_provenance!(table::DataFrame, sheet, path, metadata, source_url)
    table[!, :provider] = fill(:apra, nrow(table))
    table[!, :publication_id] = fill(metadata.dataset_id, nrow(table))
    table[!, :publication_title] = fill(metadata.title, nrow(table))
    table[!, :file_title] = fill(metadata.file_title, nrow(table))
    table[!, :sheet] = fill(sheet, nrow(table))
    table[!, :source_url] = fill(ismissing(source_url) ? metadata.source_url : source_url, nrow(table))
    table[!, :source_file] = fill(abspath(path), nrow(table))
    return table
end

function _apra_metadata(row=nothing)
    row === nothing && return (
        dataset_id="",
        title="",
        file_title="",
        source_url=missing,
    )
    return (
        dataset_id=String(row.dataset_id),
        title=String(row.title),
        file_title=String(row.file_title),
        source_url=String(row.url),
    )
end

function _looks_like_apra_publication_url(url::AbstractString)
    lower = lowercase(url)
    return startswith(lower, lowercase(APRA_BASE_URL) * "/news-and-publications/") &&
           !occursin("?", lower) &&
           basename(lower) != "news-and-publications"
end

function _looks_like_apra_file_url(url::AbstractString)
    lower = lowercase(url)
    return startswith(lower, lowercase(APRA_BASE_URL)) &&
           occursin(r"\.(xlsx|xls|csv|pdf|html?)(\?|$)", lower)
end

function _apra_publication_id(url::AbstractString)
    slug = basename(split(url, '?'; limit=2)[1])
    return _safe_filename(lowercase(slug))
end

function _apra_file_type(url::AbstractString)
    extension = lowercase(splitext(split(url, '?'; limit=2)[1])[2])
    return startswith(extension, ".") ? extension[2:end] : extension
end

function _apra_file_title(label::AbstractString, url::AbstractString)
    cleaned = _clean_discovery_text(label)
    cleaned = replace(cleaned, r"\s+(XLSX|XLS|CSV|PDF|HTML?)\s+[\d.]+\s+(KB|MB).*$"i => "")
    cleaned = replace(cleaned, r"\s+(XLSX|XLS|CSV|PDF|HTML?)\s*$"i => "")
    cleaned = strip(cleaned)
    return isempty(cleaned) ? _title_from_filename(url) : cleaned
end

function _apra_description(page_text::AbstractString, fallback::AbstractString)
    match_value = match(r"Print\s+(.*?)\s+([A-Z][A-Za-z ]+ XLSX|[A-Z][A-Za-z ]+ PDF|##|###)", page_text)
    match_value === nothing && return fallback
    description = strip(match_value.captures[1])
    return isempty(description) ? fallback : description
end

function _apra_published_date(page_text::AbstractString)
    match_value = match(r"Published\s+(\d{1,2}\s+[A-Z][a-z]+\s+\d{4})", page_text)
    match_value === nothing && return nothing
    return match_value.captures[1]
end

function _apra_date_from_text(text::AbstractString)
    match_value = match(r"(\d{1,2}\s+[A-Z][a-z]+\s+\d{4})", text)
    match_value === nothing && return nothing
    return match_value.captures[1]
end
