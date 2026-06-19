using Documenter

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using AustralianStatistics

makedocs(;
    sitename="AustralianStatistics.jl",
    modules=[AustralianStatistics],
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=[
            asset("assets/favicon.svg", class=:ico, islocal=true),
        ],
    ),
    pages=[
        "Home" => "index.md",
        "Tutorials" => [
            "Getting Started" => "tutorials/getting-started.md",
            "Reading Tables" => "tutorials/reading-tables.md",
            "Working With Series" => "tutorials/series.md",
            "Cache Management" => "tutorials/cache.md",
        ],
        "API Reference" => "api.md",
    ],
    checkdocs=:exports,
)
