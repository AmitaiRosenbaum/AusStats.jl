@testset "API response fixtures" begin
    api_datastructure_fixture()
    structure = datastructure("MOCK")
    @test nrow(structure) == 6
    @test names(structure) == ["dimension_id", "dimension_name", "position", "code", "label", "code_position"]
    @test api_key("MOCK"; filters=(sex_abs="3", asgs_2016="0")) == "3.0."
    @test api_key("MOCK"; filters=(sex_abs="Persons", measure="EMP")) == "3..EMP"
    @test_throws ArgumentError api_key("MOCK"; filters=(sex_abs="9",))

    rows = AusStats._sdmx_data_to_dataframe(api_data_fixture())
    @test nrow(rows) == 2
    @test rows.period == ["2024-Q1", "2024-Q2"]
    @test rows.date == [Date(2024, 1, 1), Date(2024, 4, 1)]
    @test rows.value == [10.0, 11.5]
end

@testset "API helper edge cases" begin
    api_dir = joinpath(default_cache_dir(), "api")
    mkpath(api_dir)
    write(joinpath(api_dir, "dataflows.json"), """
    {
      "Dataflows": {
        "first": {
          "id": "FLOW_A",
          "name": {"en": "Flow A"},
          "description": {"en": "First flow"}
        },
        "missing_id": {
          "name": {"en": "Skipped"}
        }
      }
    }
    """)
    flow_rows = dataflows()
    @test flow_rows.id == ["FLOW_A"]
    @test flow_rows.name == ["Flow A"]
    @test flow_rows.description == ["First flow"]

    alternate_structure = JSON3.read("""
    {
      "dimensions": {
        "one": {
          "id": "DIM_A",
          "name": "Dimension A",
          "position": "2",
          "localRepresentation": {"enumeration": {"ref": "CL_A"}}
        }
      },
      "Codelists": {
        "CL_A": {
          "id": "CL_A",
          "codes": [
            {"id": "X", "name": "Code X"}
          ]
        }
      }
    }
    """)
    alternate = AusStats._datastructure_dataframe(alternate_structure)
    @test alternate.dimension_id == ["DIM_A"]
    @test alternate.position == [3]
    @test alternate.code == ["X"]
    @test alternate.label == ["Code X"]

    direct_dimensions = AusStats._datastructure_dataframe(JSON3.read("""
    {
      "structure": {
        "dimensions": {
          "series": [
            {"id": "SERIES_DIM", "name": {"en": "Series dimension"}, "values": [{"id": "S1", "name": {"en": "Series one"}}]}
          ],
          "observation": [
            {"id": "OBS_DIM", "name": {"en": "Observation dimension"}, "values": [{"id": "O1"}]}
          ]
        }
      }
    }
    """))
    @test direct_dimensions.dimension_id == ["SERIES_DIM", "OBS_DIM"]
    @test direct_dimensions.code == ["S1", "O1"]

    collected_dimensions = AusStats._datastructure_dimensions(JSON3.read("""
    {
      "outer": {
        "dimensions": [
          {"id": "COLLECTED_A", "name": "Collected A"},
          {"id": "COLLECTED_B", "name": "Collected B"}
        ]
      }
    }
    """))
    @test length(collected_dimensions) == 2
    @test AusStats._json_string(first(collected_dimensions), "id") == "COLLECTED_A"

    nested_codelists = AusStats._datastructure_codelists(JSON3.read("""
    {
      "outer": {
        "codelists": {
          "CL_DIRECT": {"id": "CL_DIRECT", "items": [{"id": "A"}]},
          "ignored": {"items": [{"id": "B"}]}
        }
      }
    }
    """))
    @test haskey(nested_codelists, "CL_DIRECT")
    @test !haskey(nested_codelists, "ignored")

    vector_codelists = AusStats._datastructure_codelists(JSON3.read("""
    {"codelists": [{"id": "CL_VECTOR", "items": [{"id": "V"}]}]}
    """))
    @test haskey(vector_codelists, "CL_VECTOR")

    no_codes = AusStats._datastructure_dataframe(JSON3.read("""
    {"structure": {"dimensions": {"series": [{"id": "FREE_TEXT", "name": "Free text"}]}}}
    """))
    @test nrow(no_codes) == 1
    @test ismissing(no_codes.code[1])
    @test api_key("MOCK") == "all"
    @test_throws ArgumentError api_key("MOCK"; filters=["not" => "valid"])
    @test AusStats._api_code_for_dimension(no_codes, "FREE_TEXT", "anything") == "anything"
    @test_throws ArgumentError AusStats._api_dimensions(DataFrame(id=["x"]))

    empty_sdmx = AusStats._sdmx_data_to_dataframe(JSON3.read("""{"dataSets": []}"""))
    @test nrow(empty_sdmx) == 0
    @test names(empty_sdmx) == ["period", "date", "value"]
    odd_keys = AusStats._sdmx_data_to_dataframe(JSON3.read("""
    {
      "structure": {"dimensions": {
        "series": [{"id": "DIM", "values": [{"id": "A"}]}],
        "observation": [{"id": "TIME_PERIOD", "values": [{"id": "2024"}]}]
      }},
      "dataSets": [{"series": {"bad": {"observations": {"bad": [null]}}}}]
    }
    """))
    @test nrow(odd_keys) == 1
    @test odd_keys.period == ["bad"]
    @test ismissing(odd_keys.date[1])
    @test ismissing(odd_keys.value[1])

    collected = Any[]
    AusStats._collect_named_objects!(collected, Dict("target" => "scalar"), ("target",))
    @test collected == ["scalar"]
    @test AusStats._json_get(42, "missing", "fallback") == "fallback"
    json_object = JSON3.read("""{"present": 1}""")
    @test AusStats._json_get(json_object, "present", 0) == 1
    @test AusStats._json_get(json_object, "missing", 0) == 0
    @test AusStats._json_path(Dict("x" => 1), 1) === nothing
    @test AusStats._json_path(Dict("x" => []), "x", 1) === nothing
end
