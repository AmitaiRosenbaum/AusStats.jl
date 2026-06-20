@testset "Cube parsing fixtures" begin
    generic = read_cube(cube_workbook(); family=:generic)
    @test nrow(generic) == 2
    @test generic.sheet == ["Cube 1", "Cube 1"]
    @test "source_file" in names(generic)

    matrix = read_cube(labelled_cube_workbook())
    @test nrow(matrix) == 4
    @test names(matrix) == [
        "source_file", "cat_no", "release_date", "cube", "cube_title", "sheet",
        "date", "frequency", "value", "State", "Sex", "Age",
    ]
    @test matrix.date == [Date(2024, 3, 1), Date(2024, 6, 1), Date(2024, 3, 1), Date(2024, 6, 1)]
    @test ismissing(matrix.value[3])
    @test matrix.Sex == ["Male", "Male", "Female", "Female"]

    forced_matrix = read_cube(labelled_cube_workbook(); family=:labelled_matrix)
    @test nrow(forced_matrix) == 4
    @test_throws ArgumentError AusStats._read_cube_workbook(cube_workbook(); family=:unsupported)

    multisheet = read_cube(multi_sheet_cube_workbook(); family=:generic)
    @test nrow(multisheet) == 2
    @test Set(multisheet.sheet) == Set(["Cube 1", "Cube 2"])
end

@testset "Cube discovery helpers" begin
    convenience_fixture_index()
    @test nrow(search_cubes("")) == nrow(cube_files())
    @test nrow(cube_files("6202.0"; release="apr-2026")) >= 1
    @test nrow(cube_files("6202.0"; release="missing-release")) == 0
    @test_throws ArgumentError read_lfs_cube(; cube="definitely missing")

    cube_release = Date(2026, 11, 1)
    cube_rows = AusStats._file_rows_dataframe([
        AusStats._file_row(;
            cat_no="6202.0",
            title="Labour Force, Australia",
            description="Cube release",
            page_url="https://example.test/nov-2026",
            release_date="nov-2026",
            file_title="November data cube",
            url="https://example.test/nov-2026/cube.xlsx",
            filename="nov_cube.xlsx",
            file_type="xlsx",
            table_no="",
            table_title="November data cube",
            is_timeseries=false,
            is_cube=true,
        ),
    ])
    AusStats._write_release_file_index("6202.0", cube_release, cube_rows)
    @test nrow(cube_files("6202.0"; release=cube_release)) == 1
end
