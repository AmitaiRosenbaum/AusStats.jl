@testset "Core workflow regressions" begin
    index = convenience_fixture_index()
    @test nrow(index[index.cat_no .== "6202.0", :]) >= 2

    selected = AusStats._select_file("6202.0"; cube=false)
    sample_workbook(joinpath(default_cache_dir(), "workbooks", selected.filename))

    table_one = read_abs("6202.0"; tables=1)
    @test nrow(table_one) == 4
    @test Set(table_one.series_id) == Set(["A84423043A", "B84423043B"])

    known = read_series("A84423043A"; cat_no="6202.0")
    @test nrow(known) == 2
    @test unique(known.series_id) == ["A84423043A"]

    @test nrow(search_cubes("labelled"; cat_no="6202.0")) == 1
    labelled = read_cube("6202.0"; cube="labelled")
    @test nrow(labelled) == 4
    @test unique(labelled.cube) == ["6202.0_lfs_labelled_matrix_cube.xlsx"]
end

