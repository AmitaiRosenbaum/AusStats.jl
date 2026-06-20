using AusStats
using DataFrames
using Dates
using HTTP
using JSON3
using Test
using XLSX

include("support/fixtures.jl")
include("core_tests.jl")
include("html_tests.jl")
include("workbook_tests.jl")
include("cube_tests.jl")
include("api_tests.jl")
include("download_tests.jl")
include("http_tests.jl")
include("workflow_tests.jl")
include("online_tests.jl")
