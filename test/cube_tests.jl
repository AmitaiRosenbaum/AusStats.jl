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
end

@testset "Cube discovery helpers" begin
    convenience_fixture_index()
    @test nrow(search_cubes("")) == nrow(cube_files())
    @test nrow(cube_files("6202.0"; release="apr-2026")) >= 1
    @test nrow(cube_files("6202.0"; release="missing-release")) == 0
    @test_throws ArgumentError read_lfs_cube(; cube="definitely missing")
end
