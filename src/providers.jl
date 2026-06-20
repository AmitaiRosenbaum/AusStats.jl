abstract type AbstractProvider end

struct ABSProvider <: AbstractProvider end

struct RBAProvider <: AbstractProvider end

struct APRAProvider <: AbstractProvider end

const _PROVIDERS = Dict{Symbol, AbstractProvider}(
    :abs => ABSProvider(),
    :apra => APRAProvider(),
    :rba => RBAProvider(),
)

provider_id(::ABSProvider) = :abs
provider_id(::APRAProvider) = :apra
provider_id(::RBAProvider) = :rba
provider_name(::ABSProvider) = "Australian Bureau of Statistics"
provider_name(::APRAProvider) = "Australian Prudential Regulation Authority"
provider_name(::RBAProvider) = "Reserve Bank of Australia"

function _provider(provider)
    provider isa AbstractProvider && return provider
    key = provider isa Symbol ? provider : Symbol(lowercase(strip(string(provider))))
    haskey(_PROVIDERS, key) ||
        throw(ArgumentError("unsupported provider `$provider`; expected one of $(sort(collect(keys(_PROVIDERS))))"))
    return _PROVIDERS[key]
end

"""
    providers()

Return the data providers supported by AusStats.
"""
function providers()
    rows = DataFrame(; provider=Symbol[], name=String[])
    for key in sort(collect(keys(_PROVIDERS)))
        provider = _PROVIDERS[key]
        push!(rows, (provider_id(provider), provider_name(provider)))
    end
    return rows
end

"""
    datasets(provider=:abs; refresh=false)

Return datasets known for `provider`.
"""
function datasets(provider=:abs; refresh::Bool=false)
    return _datasets(_provider(provider); refresh)
end

"""
    datafiles(provider, dataset_id=nothing; refresh=false, release=nothing)

Return downloadable files known for `provider`.
"""
function datafiles(provider, dataset_id=nothing; refresh::Bool=false, release=nothing)
    return _datafiles(_provider(provider), dataset_id; refresh, release)
end

"""
    search_data(query; provider=nothing, refresh=false)

Search known datasets and downloadable files across providers.
"""
function search_data(query::AbstractString; provider=nothing, refresh::Bool=false)
    if provider === nothing
        out = DataFrame()
        for key in sort(collect(keys(_PROVIDERS)))
            rows = _search_data(_PROVIDERS[key], query; refresh)
            isempty(rows) && continue
            if isempty(out)
                out = rows
            else
                append!(out, rows; cols=:union)
            end
        end
        return out
    end
    return _search_data(_provider(provider), query; refresh)
end

"""
    download_data(provider, dataset_id; file=nothing, release=:latest, dest=default_cache_dir(), force=false)

Download a provider dataset file and return its local path.
"""
function download_data(
    provider,
    dataset_id::AbstractString;
    file=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    return _download_data(_provider(provider), dataset_id; file, release, dest, force)
end

"""
    read_data(provider, source; file=nothing, release=:latest, cache=true, cache_parsed=true, refresh=false)

Read data from `provider` using a provider-specific parser.
"""
function read_data(
    provider,
    source::AbstractString;
    file=nothing,
    release=:latest,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    return _read_data(
        _provider(provider),
        source;
        file,
        release,
        cache,
        cache_parsed,
        refresh,
    )
end

function _provider_file_rows(rows)
    isempty(rows) && return _empty_provider_file_rows()
    return DataFrame(;
        provider=[row.provider for row in rows],
        dataset_id=[row.dataset_id for row in rows],
        title=[row.title for row in rows],
        description=[row.description for row in rows],
        page_url=[row.page_url for row in rows],
        release_date=[row.release_date for row in rows],
        file_id=[row.file_id for row in rows],
        file_title=[row.file_title for row in rows],
        url=[row.url for row in rows],
        filename=[row.filename for row in rows],
        file_type=[row.file_type for row in rows],
        resource_kind=[row.resource_kind for row in rows],
    )
end

function _empty_provider_file_rows()
    return DataFrame(;
        provider=Symbol[],
        dataset_id=String[],
        title=String[],
        description=String[],
        page_url=String[],
        release_date=String[],
        file_id=String[],
        file_title=String[],
        url=String[],
        filename=String[],
        file_type=String[],
        resource_kind=Symbol[],
    )
end

function _provider_file_row(;
    provider,
    dataset_id,
    title,
    description="",
    page_url="",
    release_date="",
    file_id="",
    file_title,
    url,
    filename=_url_filename(url),
    file_type="",
    resource_kind=:data,
)
    return (
        provider=Symbol(provider),
        dataset_id=String(dataset_id),
        title=String(title),
        description=String(description),
        page_url=String(page_url),
        release_date=String(release_date),
        file_id=String(file_id),
        file_title=String(file_title),
        url=String(url),
        filename=String(filename),
        file_type=String(file_type),
        resource_kind=Symbol(resource_kind),
    )
end

function _provider_datasets_from_files(files::DataFrame)
    out = DataFrame(;
        provider=Symbol[],
        dataset_id=String[],
        title=String[],
        description=String[],
        page_url=String[],
    )
    isempty(files) && return out
    for group in groupby(files, [:provider, :dataset_id]; sort=true)
        row = first(group)
        push!(out, (row.provider, row.dataset_id, row.title, row.description, row.page_url))
    end
    return out
end

function _abs_provider_files(cat_no=nothing; refresh::Bool=false)
    df = cat_no === nothing ? files(; refresh) : files(cat_no; refresh)
    rows = NamedTuple[]
    for row in eachrow(df)
        push!(
            rows,
            _provider_file_row(;
                provider=:abs,
                dataset_id=row.cat_no,
                title=row.title,
                description=row.description,
                page_url=row.page_url,
                release_date=row.release_date,
                file_id=row.table_no,
                file_title=row.file_title,
                url=row.url,
                filename=row.filename,
                file_type=row.file_type,
                resource_kind=row.is_cube ? :cube : :timeseries,
            ),
        )
    end
    return _provider_file_rows(rows)
end

_datasets(::ABSProvider; refresh::Bool=false) = _provider_datasets_from_files(_abs_provider_files(; refresh))

function _datafiles(::ABSProvider, dataset_id=nothing; refresh::Bool=false, release=nothing)
    if release === nothing
        return _abs_provider_files(dataset_id; refresh)
    end
    dataset_id === nothing && throw(ArgumentError("dataset_id is required when release is supplied for ABS"))
    df = if release isa Date
        _files_for_release(string(dataset_id), release; refresh, strict=refresh)
    else
        files(string(dataset_id); refresh)
    end
    if !(release isa Date)
        release_key = lowercase(strip(string(release)))
        df = df[lowercase.(df.release_date) .== release_key, :]
    end
    return _abs_provider_files_from_dataframe(df)
end

function _abs_provider_files_from_dataframe(df::DataFrame)
    rows = NamedTuple[]
    for row in eachrow(df)
        push!(
            rows,
            _provider_file_row(;
                provider=:abs,
                dataset_id=row.cat_no,
                title=row.title,
                description=row.description,
                page_url=row.page_url,
                release_date=row.release_date,
                file_id=row.table_no,
                file_title=row.file_title,
                url=row.url,
                filename=row.filename,
                file_type=row.file_type,
                resource_kind=row.is_cube ? :cube : :timeseries,
            ),
        )
    end
    return _provider_file_rows(rows)
end

function _search_data(::ABSProvider, query::AbstractString; refresh::Bool=false)
    return _abs_provider_files_from_dataframe(search_abs(query; refresh))
end

function _download_data(
    ::ABSProvider,
    dataset_id::AbstractString;
    file=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
)
    return download_abs(dataset_id; file, release, dest, force)
end

function _read_data(
    ::ABSProvider,
    source::AbstractString;
    file=nothing,
    release=:latest,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
)
    return read_abs(
        source;
        tables=file,
        release,
        cache,
        cache_parsed,
        refresh,
    )
end
