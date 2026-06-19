module AustralianStatistics

using Dates
using DataFrames
using Downloads
using Cascadia
using Gumbo
using HTTP
using JSON3
using Pkg
using Preferences
using Scratch
using XLSX

export read_abs, read_abs_url, read_abs_local, read_metadata, tidy_abs
export read_cpi, read_awe, read_erp, read_job_mobility, read_payrolls
export read_lfs_grossflows, read_lfs_cube
export read_series, separate_series, latest_date
export download_abs, download_cube, read_cube, search_cubes, cube_files
export search_abs, catalogues, files, releases, refresh_abs!
export dataflows, datastructure, api_key, read_api, read_api_url
export default_cache_dir, cache_info, clear_cache!

include("cache.jl")
include("http.jl")
include("download.jl")
include("parse.jl")
include("read_abs.jl")
include("cube.jl")
include("convenience.jl")
include("api.jl")

end
