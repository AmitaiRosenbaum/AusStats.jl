module AusStats

using Dates
using CSV
using DataFrames
using Downloads
using EzXML
using HTTP
using JSON3
using Logging
using Preferences
using Serialization
using SHA
using Scratch
using XLSX

const VERSION = pkgversion(@__MODULE__)

export read_abs, read_abs_url, read_abs_local, read_metadata, tidy_abs
export read_cpi, read_awe, read_erp, read_job_mobility, read_payrolls
export read_lfs_grossflows, read_lfs_cube
export read_series, separate_series, latest_date
export download_abs, download_cube, read_cube, search_cubes, cube_files
export search_abs, catalogues, files, releases, refresh_abs!
export dataflows, datastructure, api_key, read_api, read_api_url
export providers, datasets, datafiles, search_data, download_data, read_data
export search_rba, rba_tables, rba_files, download_rba, read_rba
export read_rba_cash_rate, read_rba_balance_sheet
export search_apra, apra_publications, apra_files, download_apra, read_apra
export default_cache_dir, cache_info, clear_cache!

include("cache.jl")
include("http.jl")
include("parsed_cache.jl")
include("providers.jl")
include("download.jl")
include("parse.jl")
include("read_abs.jl")
include("cube.jl")
include("convenience.jl")
include("api.jl")
include("rba.jl")
include("apra.jl")

end
