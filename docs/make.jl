using Documenter

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using AusStats

makedocs(;
    sitename="AusStats.jl",
    modules=[AusStats],
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        assets=[asset("assets/favicon.svg"; class=:ico, islocal=true)],
    ),
    pages=[
        "Home" => "index.md",
        "Tutorials" => [
            "Getting Started" => "tutorials/getting-started.md",
            "Discovery" => "tutorials/discovery.md",
            "Reading Tables" => "tutorials/reading-tables.md",
            "Metadata" => "tutorials/metadata.md",
            "Working With Series" => "tutorials/series.md",
            "Data Cubes" => "tutorials/cubes.md",
            "Convenience Readers" => "tutorials/convenience.md",
            "ABS API" => "tutorials/api.md",
            "Cache Management" => "tutorials/cache.md",
            "Testing And Reproducibility" => "tutorials/reproducibility.md",
            "Workflow Migration" => "tutorials/migration.md",
        ],
        "API Reference" => "api.md",
    ],
    checkdocs=:exports,
)

deploydocs(; repo="github.com/AmitaiRosenbaum/AusStats.jl.git", devbranch="main")
