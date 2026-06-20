function _rba_not_implemented()
    throw(ArgumentError("RBA support is not implemented yet"))
end

_datasets(::RBAProvider; refresh::Bool=false) = _rba_not_implemented()
_datafiles(::RBAProvider, dataset_id=nothing; refresh::Bool=false, release=nothing) =
    _rba_not_implemented()
_search_data(::RBAProvider, query::AbstractString; refresh::Bool=false) =
    _rba_not_implemented()
_download_data(::RBAProvider, dataset_id::AbstractString; file=nothing, release=:latest, dest::AbstractString=default_cache_dir(), force::Bool=false) =
    _rba_not_implemented()
_read_data(::RBAProvider, source::AbstractString; file=nothing, release=:latest, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false) =
    _rba_not_implemented()

search_rba(query::AbstractString; refresh::Bool=false) = _rba_not_implemented()
rba_tables(; refresh::Bool=false) = _rba_not_implemented()
rba_files(table_id=nothing; refresh::Bool=false) = _rba_not_implemented()
download_rba(table_id::AbstractString; file=nothing, dest::AbstractString=default_cache_dir(), force::Bool=false) =
    _rba_not_implemented()
read_rba(source::AbstractString; file=nothing, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false) =
    _rba_not_implemented()
read_rba_cash_rate(; refresh::Bool=false, cache_parsed::Bool=true) = _rba_not_implemented()
read_rba_balance_sheet(; refresh::Bool=false, cache_parsed::Bool=true) =
    _rba_not_implemented()
