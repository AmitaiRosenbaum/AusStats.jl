const _CPI_CAT_NO = "6401.0"
const _AWE_CAT_NO = "6302.0"
const _ERP_CAT_NO = "3101.0"
const _JOB_MOBILITY_CAT_NO = "6226.0"
const _PAYROLLS_CAT_NO = "6160.0.55.001"
const _LFS_CAT_NO = "6202.0"

"""
    read_cpi(; release=:latest, table=nothing, cache=true, cache_parsed=true, refresh=false, tidy=true)

Read Consumer Price Index, Australia (`6401.0`) using [`read_abs`](@ref).
`table` is passed to the generic `tables` selector.
"""
function read_cpi(; release::Union{Symbol,Date,AbstractString}=:latest, table=nothing, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, tidy::Bool=true)
    return _read_catalogue_convenience("Consumer Price Index", _CPI_CAT_NO; release=release, table=table, cache=cache, cache_parsed=cache_parsed, refresh=refresh, tidy=tidy)
end

"""
    read_awe(; release=:latest, table=nothing, cache=true, cache_parsed=true, refresh=false, tidy=true)

Read Average Weekly Earnings, Australia (`6302.0`) using [`read_abs`](@ref).
`table` is passed to the generic `tables` selector.
"""
function read_awe(; release::Union{Symbol,Date,AbstractString}=:latest, table=nothing, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, tidy::Bool=true)
    return _read_catalogue_convenience("Average Weekly Earnings", _AWE_CAT_NO; release=release, table=table, cache=cache, cache_parsed=cache_parsed, refresh=refresh, tidy=tidy)
end

"""
    read_erp(; release=:latest, table=nothing, cache=true, cache_parsed=true, refresh=false, tidy=true)

Read National, state and territory population / Estimated Resident Population
workbooks (`3101.0`) using [`read_abs`](@ref). `table` is passed to the generic
`tables` selector.
"""
function read_erp(; release::Union{Symbol,Date,AbstractString}=:latest, table=nothing, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, tidy::Bool=true)
    return _read_catalogue_convenience("Estimated Resident Population", _ERP_CAT_NO; release=release, table=table, cache=cache, cache_parsed=cache_parsed, refresh=refresh, tidy=tidy)
end

"""
    read_job_mobility(; release=:latest, table=nothing, cache=true, cache_parsed=true, refresh=false, tidy=true)

Read Job Mobility, Australia (`6226.0`) using [`read_abs`](@ref). `table` is
passed to the generic `tables` selector.
"""
function read_job_mobility(; release::Union{Symbol,Date,AbstractString}=:latest, table=nothing, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, tidy::Bool=true)
    return _read_catalogue_convenience("Job Mobility", _JOB_MOBILITY_CAT_NO; release=release, table=table, cache=cache, cache_parsed=cache_parsed, refresh=refresh, tidy=tidy)
end

"""
    read_payrolls(; release=:latest, table=nothing, cache=true, cache_parsed=true, refresh=false, tidy=true)

Read Weekly Payroll Jobs and Wages in Australia (`6160.0.55.001`) using
[`read_abs`](@ref). `table` is passed to the generic `tables` selector.
"""
function read_payrolls(; release::Union{Symbol,Date,AbstractString}=:latest, table=nothing, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, tidy::Bool=true)
    return _read_catalogue_convenience("Weekly Payroll Jobs and Wages", _PAYROLLS_CAT_NO; release=release, table=table, cache=cache, cache_parsed=cache_parsed, refresh=refresh, tidy=tidy)
end

"""
    read_lfs_grossflows(; release=:latest, cube="gross flows", cache=true, cache_parsed=true, refresh=false, family=:auto)

Read the Labour Force, Australia (`6202.0`) gross flows data cube using
[`read_cube`](@ref). Override `cube` if ABS changes the downloadable file title
but keeps the data in the Labour Force catalogue.
"""
function read_lfs_grossflows(; release::Union{Symbol,Date,AbstractString}=:latest, cube::Union{Nothing,AbstractString}="gross flows", cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, family::Symbol=:auto)
    return _read_cube_convenience("Labour Force gross flows", _LFS_CAT_NO; cube=cube, release=release, cache=cache, cache_parsed=cache_parsed, refresh=refresh, family=family)
end

"""
    read_lfs_cube(; cube=nothing, release=:latest, cache=true, cache_parsed=true, refresh=false, family=:auto)

Read a Labour Force, Australia (`6202.0`) data cube using [`read_cube`](@ref).
Pass `cube` to select a cube by file title, filename, or table number.
"""
function read_lfs_cube(; cube::Union{Nothing,AbstractString}=nothing, release::Union{Symbol,Date,AbstractString}=:latest, cache::Bool=true, cache_parsed::Bool=true, refresh::Bool=false, family::Symbol=:auto)
    return _read_cube_convenience("Labour Force data cube", _LFS_CAT_NO; cube=cube, release=release, cache=cache, cache_parsed=cache_parsed, refresh=refresh, family=family)
end

function _read_catalogue_convenience(label::AbstractString, cat_no::AbstractString; release, table, cache::Bool, cache_parsed::Bool, refresh::Bool, tidy::Bool)
    refresh && files(cat_no; refresh=true)

    try
        return read_abs(cat_no; tables=table, release=release, tidy=tidy, cache=cache, cache_parsed=cache_parsed, refresh=refresh)
    catch error
        _throw_convenience_error(label, cat_no, error)
    end
end

function _read_cube_convenience(label::AbstractString, cat_no::AbstractString; cube, release, cache::Bool, cache_parsed::Bool, refresh::Bool, family::Symbol)
    refresh && files(cat_no; refresh=true)

    try
        return read_cube(cat_no; cube=cube, release=release, cache=cache, cache_parsed=cache_parsed, refresh=refresh, family=family)
    catch error
        _throw_convenience_error(label, cat_no, error)
    end
end

function _throw_convenience_error(label::AbstractString, cat_no::AbstractString, error)
    error isa InterruptException && throw(error)
    message = sprint(showerror, error)
    throw(ArgumentError("could not read $label catalogue `$cat_no`: $message. Try `files(\"$cat_no\"; refresh=true)` to inspect current ABS downloads, or use the generic `read_abs`/`read_cube` APIs with an explicit file selector."))
end
