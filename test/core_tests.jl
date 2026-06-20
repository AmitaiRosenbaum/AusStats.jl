@testset "AusStats" begin
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
    AusStats._write_release_index("6345.0", archive_releases)
    AusStats._write_release_file_index("6345.0", Date(2019, 9, 1), historical_files)

    cache_dir = mktempdir()
    selected = AusStats._select_file("6202.0"; cube=false)
    cached_path = joinpath(cache_dir, "workbooks", selected.filename)
    mkpath(dirname(cached_path))
    touch(cached_path)
    @test download_abs("6202.0"; dest=cache_dir) == cached_path

    historical_selected = AusStats._select_file("6345.0"; release=Date(2019, 9, 1), cube=false)
    historical_path = joinpath(cache_dir, "workbooks", historical_selected.filename)
    mkpath(dirname(historical_path))
    touch(historical_path)
    @test download_abs("6345.0"; release=Date(2019, 9, 1), dest=cache_dir) == historical_path
    message = try
        AusStats._files_for_release("6345.0", Date(2019, 10, 1); strict=true)
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

    clear_cache!(:parsed)
    cached_parse = read_abs_local(workbook; tables=1, cache_parsed=true)
    parsed_info = cache_info()
    parsed_files = parsed_info[parsed_info.kind .== "parsed", :]
    @test nrow(parsed_files) == 1
    @test isequal(cached_parse, read_abs_local(workbook; tables=1, cache_parsed=true))
    parsed_info = cache_info()
    @test nrow(parsed_info[parsed_info.kind .== "parsed", :]) == 1
    @test isequal(read_abs_local(workbook; tables=1, cache_parsed=false), cached_parse)
    @test isequal(read_abs_local(workbook; tables=1, cache_parsed=true, refresh=true), cached_parse)
    parsed_info = cache_info()
    @test nrow(parsed_info[parsed_info.kind .== "parsed", :]) == 1
    sleep(1.1)
    touch(workbook)
    @test isequal(read_abs_local(workbook; tables=1, cache_parsed=true), cached_parse)
    parsed_info = cache_info()
    @test nrow(parsed_info[parsed_info.kind .== "parsed", :]) == 2

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

    vector_directory = read_abs_local([local_dir]; tables=1, recursive=true)
    @test nrow(vector_directory) == 8
    @test Set(vector_directory.source_file) == Set(abspath.([first_local, second_local]))

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
    @test_throws ArgumentError read_abs_local(String[])
    @test_throws ArgumentError read_metadata(empty_directory)
    @test AusStats._table_matches("Table 12. Detailed data", "12")
    @test !AusStats._table_matches("Table 12. Detailed data", "")
    @test AusStats._table_matches("Detailed Monthly Data", "monthly")
    @test nrow(read_series("missing-series"; cat_no=["0000.0"])) == 0
    broken_workbook = joinpath(empty_directory, "broken.xlsx")
    write(broken_workbook, "not an excel workbook")
    @test_throws ArgumentError AusStats._read_local_workbooks([broken_workbook])
    corrupt_cache = joinpath(mktempdir(), "bad-parsed-cache.bin")
    write(corrupt_cache, "not serialized data")
    @test AusStats._read_parsed_cache(corrupt_cache, (; parser_version=1)) === nothing

    metadata = read_metadata(workbook; tables=1)
    @test nrow(metadata) == 2
    @test "date" ∉ names(metadata)
    @test "value" ∉ names(metadata)
    @test unique(metadata.source_workbook) == [abspath(workbook)]

    sample_workbook(joinpath(default_cache_dir(), "workbooks", selected.filename))
    catalogue_metadata = read_metadata("6202.0"; tables=1)
    @test nrow(catalogue_metadata) == 2
    @test unique(catalogue_metadata.cat_no) == ["6202.0"]

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
    @test names(named_parts)[(end-2):end] == ["measure", "sex", "aggregate"]
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

    filtered_url = AusStats._api_request_url("MOCK"; filters=(sex_abs="3", asgs_2016="0"), start_period="2024-Q1", params=(detail="dataonly",))
    @test occursin("/data/ABS/MOCK/3.0./all?", filtered_url)
    @test occursin("detail=dataonly", filtered_url)
    @test occursin("startPeriod=2024-Q1", filtered_url)
    explicit_url = AusStats._api_request_url("MOCK"; key="1.0.EMP", end_period="2024-Q2")
    @test occursin("/data/ABS/MOCK/1.0.EMP/all?endPeriod=2024-Q2", explicit_url)
    @test_throws ArgumentError AusStats._api_request_url("MOCK"; key="1", filters=(sex_abs="3",))

    api_rows = AusStats._sdmx_data_to_dataframe(api_data_fixture())
    @test nrow(api_rows) == 2
    @test api_rows.period == ["2024-Q1", "2024-Q2"]
    @test api_rows.date == [Date(2024, 1, 1), Date(2024, 4, 1)]
    @test api_rows.value == [10.0, 11.5]
    @test api_rows.SEX_ABS == ["3", "3"]
    @test api_rows.ASGS_2016 == ["0", "0"]

    info = cache_info()
    @test all(name -> name in names(info), ["kind", "file", "path", "size", "modified"])
end
