function _apra_not_implemented()
    throw(ArgumentError("APRA support is not implemented yet"))
end

_datasets(::APRAProvider; refresh::Bool=false) = _apra_not_implemented()
_datafiles(::APRAProvider, dataset_id=nothing; refresh::Bool=false, release=nothing) =
    _apra_not_implemented()
_search_data(::APRAProvider, query::AbstractString; refresh::Bool=false) =
    _apra_not_implemented()
_download_data(
    ::APRAProvider,
    dataset_id::AbstractString;
    file=nothing,
    release=:latest,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
) = _apra_not_implemented()
_read_data(
    ::APRAProvider,
    source::AbstractString;
    file=nothing,
    release=:latest,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
) = _apra_not_implemented()

search_apra(query::AbstractString; refresh::Bool=false) = _apra_not_implemented()
apra_publications(; refresh::Bool=false) = _apra_not_implemented()
apra_files(publication_id=nothing; refresh::Bool=false) = _apra_not_implemented()
download_apra(
    publication_id::AbstractString;
    file=nothing,
    dest::AbstractString=default_cache_dir(),
    force::Bool=false,
) = _apra_not_implemented()
read_apra(
    source::AbstractString;
    file=nothing,
    cache::Bool=true,
    cache_parsed::Bool=true,
    refresh::Bool=false,
) = _apra_not_implemented()
