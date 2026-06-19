using AustralianStatistics
using DataFrames
using Dates
using Gumbo
using JSON3
using Test
using XLSX

function sample_workbook(path=tempname() * ".xlsx")
    mkpath(dirname(path))
    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Data1")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "A84423043A"
        sheet["C1"] = "B84423043B"
        sheet["A2"] = "Data item"
        sheet["B2"] = "Employed total ; Persons ; Australia"
        sheet["C2"] = "Unemployed total"
        sheet["A3"] = "Unit"
        sheet["B3"] = "Persons"
        sheet["C3"] = "Persons"
        sheet["A4"] = "Frequency"
        sheet["B4"] = "Monthly"
        sheet["C4"] = "Monthly"
        sheet["A5"] = "Series Type"
        sheet["B5"] = "Seasonally adjusted"
        sheet["C5"] = "Original"
        sheet["A6"] = "Data Type"
        sheet["B6"] = "Stock"
        sheet["C6"] = "Stock"
        sheet["A7"] = "Collection Month"
        sheet["B7"] = "May"
        sheet["C7"] = "May"
        sheet["A8"] = "Series Start"
        sheet["B8"] = "Apr-2026"
        sheet["C8"] = "Apr-2026"
        sheet["A9"] = "Apr-26"
        sheet["B9"] = 12.5
        sheet["C9"] = 8.0
        sheet["A10"] = "May-26"
        sheet["B10"] = "not numeric"
        sheet["C10"] = 9.0

        sheet = XLSX.addsheet!(xf, "Table 2")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "C1234567"
        sheet["A2"] = "2024-Q1"
        sheet["B2"] = 99.0

        sheet = XLSX.addsheet!(xf, "Data10")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "D1234567"
        sheet["A2"] = "2024"
        sheet["B2"] = 101.0

        XLSX.addsheet!(xf, "Notes")
    end

    return path
end

function cube_workbook(path=tempname() * ".xlsx")
    mkpath(dirname(path))
    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Cube 1")
        sheet["A1"] = "State"
        sheet["B1"] = "Value"
        sheet["A2"] = "NSW"
        sheet["B2"] = 1.0
        sheet["A3"] = "VIC"
        sheet["B3"] = 2.0
    end
    return path
end

function labelled_cube_workbook(path=tempname() * ".xlsx")
    mkpath(dirname(path))
    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Matrix")
        sheet["A1"] = "Labour Force detailed data cube"
        sheet["A2"] = "State"
        sheet["B2"] = "Sex"
        sheet["C2"] = "Age"
        sheet["D2"] = "Mar-2024"
        sheet["E2"] = "Jun-2024"
        sheet["A3"] = "NSW"
        sheet["B3"] = "Male"
        sheet["C3"] = "15-24"
        sheet["D3"] = 10
        sheet["E3"] = 11
        sheet["A4"] = "NSW"
        sheet["B4"] = "Female"
        sheet["C4"] = "15-24"
        sheet["D4"] = ".."
        sheet["E4"] = 12
        sheet["A5"] = "Source: Australian Bureau of Statistics"
        sheet["D5"] = 999

        sheet = XLSX.addsheet!(xf, "Notes")
        sheet["A1"] = "Notes"
        sheet["A2"] = "This sheet should remain generic if requested directly."
    end
    return path
end

function api_datastructure_fixture(flow_id="MOCK")
    json = """
    {
      "data": {
        "dataStructures": [
          {
            "dataStructureComponents": {
              "dimensionList": {
                "dimensions": [
                  {
                    "id": "SEX_ABS",
                    "name": {"en": "Sex"},
                    "position": 0,
                    "localRepresentation": {"enumeration": {"id": "CL_SEX_ABS"}}
                  },
                  {
                    "id": "ASGS_2016",
                    "name": {"en": "Region"},
                    "position": 1,
                    "localRepresentation": {"enumeration": {"id": "CL_ASGS_2016"}}
                  },
                  {
                    "id": "MEASURE",
                    "name": {"en": "Measure"},
                    "position": 2,
                    "localRepresentation": {"enumeration": {"id": "CL_MEASURE"}}
                  }
                ]
              }
            }
          }
        ],
        "codelists": [
          {
            "id": "CL_SEX_ABS",
            "items": [
              {"id": "1", "name": {"en": "Male"}},
              {"id": "2", "name": {"en": "Female"}},
              {"id": "3", "name": {"en": "Persons"}}
            ]
          },
          {
            "id": "CL_ASGS_2016",
            "items": [
              {"id": "0", "name": {"en": "Australia"}},
              {"id": "1", "name": {"en": "New South Wales"}}
            ]
          },
          {
            "id": "CL_MEASURE",
            "items": [
              {"id": "EMP", "name": {"en": "Employed"}}
            ]
          }
        ]
      }
    }
    """
    path = joinpath(default_cache_dir(), "api", "datastructure_$(lowercase(flow_id)).json")
    mkpath(dirname(path))
    write(path, json)
    return path
end

function api_data_fixture()
    return JSON3.read("""
    {
      "structure": {
        "dimensions": {
          "series": [
            {"id": "SEX_ABS", "values": [{"id": "3"}]},
            {"id": "ASGS_2016", "values": [{"id": "0"}]}
          ],
          "observation": [
            {"id": "TIME_PERIOD", "values": [{"id": "2024-Q1"}, {"id": "2024-Q2"}]}
          ]
        }
      },
      "dataSets": [
        {
          "series": {
            "0:0": {
              "observations": {
                "0": [10.0],
                "1": ["11.5"]
              }
            }
          }
        }
      ]
    }
    """)
end

function convenience_fixture_index()
    workbook_rows = [
        ("6302.0", "Average Weekly Earnings, Australia", "Average weekly earnings time series.", "Table 1. Average Weekly Earnings", "6302.0_awe_table_001.xlsx"),
        ("3101.0", "National, state and territory population", "Estimated resident population time series.", "Table 1. Estimated Resident Population", "3101.0_erp_table_001.xlsx"),
        ("6226.0", "Job Mobility, Australia", "Job mobility time series.", "Table 1. Job Mobility", "6226.0_job_mobility_table_001.xlsx"),
        ("6160.0.55.001", "Weekly Payroll Jobs and Wages in Australia", "Weekly payroll jobs and wages time series.", "Table 1. Payroll Jobs", "6160.0.55.001_payrolls_table_001.xlsx"),
    ]

    rows = AustralianStatistics._seed_file_rows()
    for (cat_no, title, description, file_title, filename) in workbook_rows
        push!(rows, AustralianStatistics._file_row(;
            cat_no,
            title,
            description,
            page_url = "https://example.test/$cat_no",
            release_date = "apr-2026",
            file_title,
            url = "https://example.test/$filename",
            filename,
            file_type = "xlsx",
            table_no = "1",
            table_title = file_title,
            is_timeseries = true,
            is_cube = false,
        ))
    end

    cube_rows = [
        ("Detailed Labour Force data cube", "6202.0_lfs_detailed_cube.xlsx"),
        ("Gross flows data cube", "6202.0_lfs_gross_flows_cube.xlsx"),
        ("Labelled matrix Labour Force data cube", "6202.0_lfs_labelled_matrix_cube.xlsx"),
    ]
    for (file_title, filename) in cube_rows
        push!(rows, AustralianStatistics._file_row(;
            cat_no = "6202.0",
            title = "Labour Force, Australia",
            description = "Labour force data cubes.",
            page_url = "https://example.test/6202.0",
            release_date = "apr-2026",
            file_title,
            url = "https://example.test/$filename",
            filename,
            file_type = "xlsx",
            table_no = "",
            table_title = file_title,
            is_timeseries = false,
            is_cube = true,
        ))
    end

    index = AustralianStatistics._file_rows_dataframe(rows)
    AustralianStatistics._write_index(index)

    for row in eachrow(index[index.is_timeseries, :])
        sample_workbook(joinpath(default_cache_dir(), "workbooks", row.filename))
    end
    for row in eachrow(index[index.is_cube, :])
        path = joinpath(default_cache_dir(), "cubes", row.filename)
        occursin("labelled", row.filename) ? labelled_cube_workbook(path) : cube_workbook(path)
    end

    return index
end

function period_workbook()
    path = tempname() * ".xlsx"

    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Monthly")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "M1234567"
        sheet["A2"] = "Jan-2024"
        sheet["B2"] = 1
        sheet["A3"] = "2024-02"
        sheet["B3"] = 2

        sheet = XLSX.addsheet!(xf, "Quarterly")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "Q1234567"
        sheet["A2"] = "Mar-2024"
        sheet["B2"] = 3
        sheet["A3"] = "2024-Q2"
        sheet["B3"] = 4
        sheet["A4"] = "Q3 2024"
        sheet["B4"] = 5

        sheet = XLSX.addsheet!(xf, "Annual")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "Y1234567"
        sheet["A2"] = "2024"
        sheet["B2"] = 6
    end

    return path
end

function metadata_layout_workbook(path=tempname() * ".xlsx")
    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "CPI Metadata")
        sheet["A1"] = "Consumer Price Index, Australia"
        sheet["A2"] = "Catalogue Number"
        sheet["B2"] = "6401.0"
        sheet["A3"] = "Release Date"
        sheet["B3"] = "April 2024"
        sheet["A4"] = "Table 1. CPI: All groups, index numbers"
        sheet["A5"] = "Series ID"
        sheet["B5"] = "A2325846C"
        sheet["A6"] = "Data item"
        sheet["B6"] = "All groups CPI"
        sheet["A7"] = "Unit"
        sheet["B7"] = "Index Numbers"
        sheet["A8"] = "Frequency"
        sheet["B8"] = "Quarterly"

        sheet = XLSX.addsheet!(xf, "National Accounts")
        sheet["A1"] = "Catalogue Number"
        sheet["B1"] = "5206.0"
        sheet["A2"] = "Release Date"
        sheet["B2"] = "June 2024"
        sheet["A3"] = "Table 1. Key National Accounts Aggregates"
        sheet["A4"] = "Series ID"
        sheet["B4"] = "Series"
        sheet["C4"] = "Unit"
        sheet["D4"] = "Frequency"
        sheet["E4"] = "Mar-2024"
        sheet["F4"] = "Jun-2024"
        sheet["A5"] = "A2304402X"
        sheet["B5"] = "Gross domestic product"
        sheet["C5"] = "\$ Millions"
        sheet["D5"] = "Quarterly"
        sheet["E5"] = 100.0
        sheet["F5"] = 101.0

        sheet = XLSX.addsheet!(xf, "Archived AWE")
        sheet["A1"] = "Australian Bureau of Statistics"
        sheet["A2"] = "Catalogue No: 6302.0"
        sheet["A3"] = "Released: November 2018"
        sheet["A4"] = "Table 3. Average Weekly Earnings, Australia"
        sheet["A5"] = "Series Number"
        sheet["B5"] = "A2733331A"
        sheet["A6"] = "Description"
        sheet["B6"] = "Average weekly ordinary time earnings"
        sheet["A7"] = "Units"
        sheet["B7"] = "Dollars"
        sheet["A8"] = "Frequency"
        sheet["B8"] = "Biannual"
        sheet["A9"] = "May-2018"
        sheet["B9"] = 1600.0

        sheet = XLSX.addsheet!(xf, "Payrolls Metadata")
        sheet["A1"] = "Weekly Payroll Jobs and Wages in Australia"
        sheet["A2"] = "Catalogue Number"
        sheet["B2"] = "6160.0.55.001"
        sheet["A3"] = "Table 4. Payroll jobs index"
        sheet["A4"] = "Series ID"
        sheet["B4"] = "A9999999P"
        sheet["A5"] = "Series"
        sheet["B5"] = "Payroll jobs index"
        sheet["A6"] = "Unit of measure"
        sheet["B6"] = "Index"
        sheet["A7"] = "Frequency"
        sheet["B7"] = "Weekly"

        XLSX.addsheet!(xf, "Explanatory Notes")
    end
    return path
end

function discovery_fixture_rows()
    html = read(joinpath(@__DIR__, "fixtures", "abs_publication_downloads.html"), String)
    doc = Gumbo.parsehtml(html)
    seed = first(AustralianStatistics.ABS_SEED_CATALOGUES)
    return AustralianStatistics._file_rows_dataframe(AustralianStatistics._discover_files_from_doc(
        doc,
        seed;
        title=seed.title,
        description=seed.description,
        page_url="https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/apr-2026",
    ))
end

function archive_fixture_releases()
    html = read(joinpath(@__DIR__, "fixtures", "abs_archive_releases.html"), String)
    doc = Gumbo.parsehtml(html)
    seed = AustralianStatistics._seed_for_catalogue("6345.0")
    return AustralianStatistics._release_rows_dataframe(AustralianStatistics._discover_releases_from_doc(doc, seed))
end

function historical_release_fixture_rows()
    html = read(joinpath(@__DIR__, "fixtures", "abs_wpi_sep_2019_downloads.html"), String)
    doc = Gumbo.parsehtml(html)
    seed = AustralianStatistics._seed_for_catalogue("6345.0")
    return AustralianStatistics._file_rows_dataframe(AustralianStatistics._discover_files_from_doc(
        doc,
        seed;
        title=seed.title,
        description=seed.description,
        page_url="https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/wage-price-index-australia/sep-2019",
    ))
end

@testset "AustralianStatistics v0.2" begin
    @test "6202.0" in search_abs("labour").cat_no
    @test "6401.0" in search_abs("cpi").cat_no
    @test "6202.0" in catalogues().cat_no
    @test nrow(files("6202.0")) >= 1

    discovered = discovery_fixture_rows()
    @test nrow(discovered) == 3
    @test all(startswith.(discovered.url, "https://www.abs.gov.au/"))
    @test all(discovered.file_type .== "xlsx")
    @test discovered.release_date == fill("apr-2026", 3)
    @test "Download xlsx [750.18 KB]" ∉ discovered.file_title
    @test "Table 1. Labour force status by Sex, Australia - Trend, Seasonally adjusted and Original" in discovered.file_title
    @test "Table 1. Labour force status by Sex, Australia - Trend, Seasonally adjusted and Original" in discovered.table_title
    @test discovered[discovered.table_no .== "2", :file_title] == ["Table 2. Labour force status by State, Territory and Sex - Trend"]
    @test nrow(discovered[discovered.table_no .== "2", :]) == 1
    @test any(discovered.is_cube)
    @test only(discovered[discovered.is_cube, :table_title]) == "Labour Force, Australia, detailed, quarterly, data cube"

    archive_releases = archive_fixture_releases()
    @test archive_releases.release_date == [Date(2019, 9, 1), Date(2019, 12, 1), Date(2020, 3, 1)]
    @test all(startswith.(archive_releases.release_url, "https://www.abs.gov.au/"))

    historical_files = historical_release_fixture_rows()
    @test nrow(historical_files) == 2
    @test historical_files.release_date == fill("sep-2019", 2)
    @test "Table 1. Total hourly rates of pay excluding bonuses: Sector by State, Original" in historical_files.table_title
    @test "2b" in historical_files.table_no
    AustralianStatistics._write_release_index("6345.0", archive_releases)
    AustralianStatistics._write_release_file_index("6345.0", Date(2019, 9, 1), historical_files)

    cache_dir = mktempdir()
    selected = AustralianStatistics._select_file("6202.0"; cube=false)
    cached_path = joinpath(cache_dir, "workbooks", selected.filename)
    mkpath(dirname(cached_path))
    touch(cached_path)
    @test download_abs("6202.0"; dest=cache_dir) == cached_path

    historical_selected = AustralianStatistics._select_file("6345.0"; release=Date(2019, 9, 1), cube=false)
    historical_path = joinpath(cache_dir, "workbooks", historical_selected.filename)
    mkpath(dirname(historical_path))
    touch(historical_path)
    @test download_abs("6345.0"; release=Date(2019, 9, 1), dest=cache_dir) == historical_path
    message = try
        AustralianStatistics._files_for_release("6345.0", Date(2019, 10, 1); strict=true)
        ""
    catch error
        sprint(showerror, error)
    end
    @test occursin("nearest known release dates", message)
    @test occursin("2019-09-01", message)

    workbook = sample_workbook()
    tidy = tidy_abs(workbook; cat_no="6202.0", release_date="apr-2026")
    @test tidy isa DataFrame
    @test names(tidy) == [
        "cat_no", "release_date", "table", "table_no", "table_title", "sheet", "sheet_no",
        "date", "series_id", "value", "unit", "series_type", "data_type", "frequency",
        "collection_month", "series_start", "series",
    ]
    @test tidy.date[1] == Date(2026, 4, 1)
    @test ismissing(tidy.value[2])
    @test tidy.frequency[1] == "monthly"
    @test tidy.series[1] == "Employed total ; Persons ; Australia"
    @test tidy.collection_month[1] == "May"
    @test tidy.series_start[1] == "Apr-2026"
    @test tidy.cat_no[1] == "6202.0"
    @test "Notes" ∉ tidy.table

    periods = tidy_abs(period_workbook())
    @test periods[periods.series_id .== "M1234567", :date] == [Date(2024, 1, 1), Date(2024, 2, 1)]
    @test unique(periods[periods.series_id .== "M1234567", :frequency]) == ["monthly"]
    @test periods[periods.series_id .== "Q1234567", :date] == [Date(2024, 1, 1), Date(2024, 4, 1), Date(2024, 7, 1)]
    @test unique(periods[periods.series_id .== "Q1234567", :frequency]) == ["quarterly"]
    @test periods[periods.series_id .== "Y1234567", :date] == [Date(2024, 1, 1)]
    @test periods[periods.series_id .== "Y1234567", :frequency] == ["annual"]

    @test read_abs_local(workbook) isa DataFrame
    @test "source_file" ∉ names(read_abs_local(workbook))
    @test read_abs(workbook) isa DataFrame
    @test read_abs(workbook; tidy=false) isa DataFrame
    @test unique(read_abs(workbook; tables=["1"]).table) == ["Data1"]
    @test unique(read_abs(workbook; tables=["Table 1"]).table) == ["Data1"]
    @test unique(read_abs(workbook; tables=["Data1"]).table) == ["Data1"]
    @test unique(read_abs(workbook; tables=1).table) == ["Data1"]

    local_dir = mktempdir()
    first_local = sample_workbook(joinpath(local_dir, "first.xlsx"))
    nested_dir = joinpath(local_dir, "nested")
    second_local = sample_workbook(joinpath(nested_dir, "second.xlsx"))

    multiple_local = read_abs_local([first_local, second_local]; tables=1)
    @test nrow(multiple_local) == 8
    @test Set(multiple_local.source_file) == Set(abspath.([first_local, second_local]))
    @test unique(multiple_local.table) == ["Data1"]

    direct_directory = read_abs_local(local_dir; tables=1)
    @test nrow(direct_directory) == 4
    @test unique(direct_directory.source_file) == [abspath(first_local)]

    recursive_directory = read_abs_local(local_dir; tables=1, recursive=true)
    @test nrow(recursive_directory) == 8
    @test Set(recursive_directory.source_file) == Set(abspath.([first_local, second_local]))

    cache_folder = mktempdir()
    cached_local = sample_workbook(joinpath(cache_folder, "workbooks", "cached.xlsx"))
    cached_directory = read_abs_local(cache_folder; tables=1)
    @test unique(cached_directory.source_file) == [abspath(cached_local)]

    empty_directory = mktempdir()
    @test_throws ArgumentError read_abs_local(empty_directory)
    @test_throws ArgumentError read_abs_local(joinpath(empty_directory, "missing.xlsx"))
    invalid_file = joinpath(empty_directory, "notes.txt")
    touch(invalid_file)
    @test_throws ArgumentError read_abs_local(invalid_file)
    @test_throws ArgumentError read_abs_local([first_local, joinpath(empty_directory, "missing.xlsx")])
    @test_throws ArgumentError read_abs_local(Any[first_local, 42])

    metadata = read_metadata(workbook; tables=1)
    @test nrow(metadata) == 2
    @test "date" ∉ names(metadata)
    @test "value" ∉ names(metadata)
    @test unique(metadata.source_workbook) == [abspath(workbook)]

    metadata_path = metadata_layout_workbook()
    layouts = read_metadata(metadata_path)
    @test nrow(layouts) == 4
    @test unique(layouts.source_workbook) == [abspath(metadata_path)]
    @test "Explanatory Notes" ∉ layouts.sheet

    cpi_metadata = only(eachrow(layouts[layouts.sheet .== "CPI Metadata", :]))
    @test cpi_metadata.cat_no == "6401.0"
    @test cpi_metadata.release_date == "apr-2024"
    @test cpi_metadata.table_no == "1"
    @test cpi_metadata.table_title == "Table 1. CPI: All groups, index numbers"
    @test cpi_metadata.unit == "Index Numbers"
    @test cpi_metadata.frequency == "quarterly"

    national_accounts = only(eachrow(layouts[layouts.sheet .== "National Accounts", :]))
    @test national_accounts.cat_no == "5206.0"
    @test national_accounts.release_date == "jun-2024"
    @test national_accounts.series == "Gross domestic product"
    @test national_accounts.unit == "\$ Millions"

    archived_awe = only(eachrow(layouts[layouts.sheet .== "Archived AWE", :]))
    @test archived_awe.cat_no == "6302.0"
    @test archived_awe.release_date == "nov-2018"
    @test archived_awe.table_title == "Table 3. Average Weekly Earnings, Australia"
    @test archived_awe.frequency == "semiannual"

    payrolls = only(eachrow(layouts[layouts.sheet .== "Payrolls Metadata", :]))
    @test payrolls.cat_no == "6160.0.55.001"
    @test payrolls.table_no == "4"
    @test payrolls.frequency == "weekly"

    separated = separate_series(metadata)
    @test "series_part_1" in names(separated)
    @test separated.series_part_1[1] == "Employed total"
    split_sample = DataFrame(series=[
        "All groups, Male, Total",
        "Employed total, Female",
        "Labour force",
        missing,
    ])
    named_parts = separate_series(split_sample; names=[:measure, :sex, :aggregate])
    @test names(named_parts)[end-2:end] == ["measure", "sex", "aggregate"]
    @test named_parts.measure[1] == "All groups"
    @test named_parts.aggregate[1] == "Total"

    without_totals = separate_series(split_sample; remove_totals=true)
    @test without_totals.series_part_1[1] == "Male"
    @test ismissing(without_totals.series_part_2[1])
    @test without_totals.series_part_1[2] == "Employed total"
    @test without_totals.series_part_2[2] == "Female"

    complete_parts = separate_series(split_sample; names=[:measure, :sex], remove_totals=true, drop_missing=true)
    @test nrow(complete_parts) == 1
    @test complete_parts.measure == ["Employed total"]
    @test complete_parts.sex == ["Female"]
    @test_throws ArgumentError separate_series(split_sample; names=[:only_one])
    @test latest_date(tidy) == Date(2026, 5, 1)

    sample_workbook(joinpath(default_cache_dir(), "workbooks", selected.filename))
    series = read_series(["a84423043a"]; cat_no="6202.0")
    @test nrow(series) == 2
    @test unique(series.series_id) == ["A84423043A"]

    cube = read_cube(cube_workbook())
    @test cube isa DataFrame
    @test cube.sheet == ["Cube 1", "Cube 1"]
    @test "source_file" in names(cube)

    matrix_cube = read_cube(labelled_cube_workbook())
    @test names(matrix_cube) == [
        "source_file", "cat_no", "release_date", "cube", "cube_title", "sheet",
        "date", "frequency", "value", "State", "Sex", "Age",
    ]
    @test nrow(matrix_cube) == 4
    @test matrix_cube.date == [Date(2024, 3, 1), Date(2024, 6, 1), Date(2024, 3, 1), Date(2024, 6, 1)]
    @test matrix_cube.frequency == fill("unknown", 4)
    @test ismissing(matrix_cube.value[3])
    @test matrix_cube.State == ["NSW", "NSW", "NSW", "NSW"]
    @test matrix_cube.Sex == ["Male", "Male", "Female", "Female"]

    generic_matrix = read_cube(labelled_cube_workbook(); family=:generic)
    @test "State" in names(generic_matrix)
    @test "Mar2024" in names(generic_matrix)
    @test nrow(generic_matrix) == 2
    @test_throws ArgumentError read_cube(labelled_cube_workbook(); family=:unknown)

    convenience_fixture_index()
    cube_index = cube_files("6202.0")
    @test all(cube_index.is_cube)
    @test any(occursin.("Labelled matrix", cube_index.file_title))
    @test nrow(search_cubes("labelled"; cat_no="6202.0")) == 1
    downloaded_cube = download_cube("6202.0"; cube="labelled")
    @test isfile(downloaded_cube)
    @test downloaded_cube == joinpath(default_cache_dir(), "cubes", "6202.0_lfs_labelled_matrix_cube.xlsx")
    cached_url_cube = labelled_cube_workbook(joinpath(default_cache_dir(), "cubes", "cached-url-cube.xlsx"))
    @test download_cube("https://example.test/cached-url-cube.xlsx") == cached_url_cube
    @test_throws ArgumentError cube_files(; release=Date(2024, 3, 1))
    @test unique(read_cpi(; table=1).cat_no) == ["6401.0"]
    @test unique(read_awe(; table=1).cat_no) == ["6302.0"]
    @test unique(read_erp(; table=1).cat_no) == ["3101.0"]
    @test unique(read_job_mobility(; table=1).cat_no) == ["6226.0"]
    @test unique(read_payrolls(; table=1).cat_no) == ["6160.0.55.001"]
    @test read_cpi(; table=1, tidy=false) isa DataFrame

    grossflows = read_lfs_grossflows()
    @test grossflows isa DataFrame
    @test unique(grossflows.sheet) == ["Cube 1"]
    lfs_cube = read_lfs_cube(; cube="detailed")
    @test lfs_cube isa DataFrame
    @test unique(lfs_cube.sheet) == ["Cube 1"]
    indexed_matrix = read_cube("6202.0"; cube="labelled")
    @test unique(indexed_matrix.cat_no) == ["6202.0"]
    @test unique(indexed_matrix.cube) == ["6202.0_lfs_labelled_matrix_cube.xlsx"]
    @test unique(indexed_matrix.cube_title) == ["Labelled matrix Labour Force data cube"]
    error_message = try
        read_cpi(; table=999)
        ""
    catch error
        sprint(showerror, error)
    end
    @test occursin("could not read Consumer Price Index catalogue `6401.0`", error_message)
    @test occursin("files(\"6401.0\"; refresh=true)", error_message)

    api_datastructure_fixture()
    structure = datastructure("MOCK")
    @test names(structure) == ["dimension_id", "dimension_name", "position", "code", "label", "code_position"]
    @test nrow(structure) == 6
    @test structure[structure.dimension_id .== "SEX_ABS", :code] == ["1", "2", "3"]
    @test structure[structure.dimension_id .== "SEX_ABS", :label] == ["Male", "Female", "Persons"]
    @test api_key("MOCK"; filters=(sex_abs="3", asgs_2016="0")) == "3.0."
    @test api_key("MOCK"; filters=(sex_abs="Persons", measure="EMP")) == "3..EMP"
    @test api_key("MOCK"; filters=Dict(:sex_abs => ["1", "2"])) == "1+2.."
    @test_throws ArgumentError api_key("MOCK"; filters=(unknown="1",))
    @test_throws ArgumentError api_key("MOCK"; filters=(sex_abs="9",))

    filtered_url = AustralianStatistics._api_request_url("MOCK"; filters=(sex_abs="3", asgs_2016="0"), start_period="2024-Q1", params=(detail="dataonly",))
    @test occursin("/data/ABS/MOCK/3.0./all?", filtered_url)
    @test occursin("detail=dataonly", filtered_url)
    @test occursin("startPeriod=2024-Q1", filtered_url)
    explicit_url = AustralianStatistics._api_request_url("MOCK"; key="1.0.EMP", end_period="2024-Q2")
    @test occursin("/data/ABS/MOCK/1.0.EMP/all?endPeriod=2024-Q2", explicit_url)
    @test_throws ArgumentError AustralianStatistics._api_request_url("MOCK"; key="1", filters=(sex_abs="3",))

    api_rows = AustralianStatistics._sdmx_data_to_dataframe(api_data_fixture())
    @test nrow(api_rows) == 2
    @test api_rows.period == ["2024-Q1", "2024-Q2"]
    @test api_rows.date == [Date(2024, 1, 1), Date(2024, 4, 1)]
    @test api_rows.value == [10.0, 11.5]
    @test api_rows.SEX_ABS == ["3", "3"]
    @test api_rows.ASGS_2016 == ["0", "0"]

    info = cache_info()
    @test all(name -> name in names(info), ["kind", "file", "path", "size", "modified"])
end

if get(ENV, "AUSTRALIANSTATISTICS_ONLINE_TESTS", "false") == "true"
    @testset "AustralianStatistics online integration" begin
        refreshed = refresh_abs!()
        @test nrow(refreshed) >= 1
        downloaded = download_abs("6202.0"; force=true)
        @test isfile(downloaded)
        @test read_abs("6202.0"; tables=1) isa DataFrame
        wpi = download_abs("6345.0"; release=Date(2019, 9, 1), force=true)
        @test isfile(wpi)
    end
end
