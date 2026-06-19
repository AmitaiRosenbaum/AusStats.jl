const TEST_FIXTURE_DIR = joinpath(dirname(@__DIR__), "fixtures")

fixture_path(parts...) = joinpath(TEST_FIXTURE_DIR, parts...)

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

    rows = AusStats._seed_file_rows()
    for (cat_no, title, description, file_title, filename) in workbook_rows
        push!(rows, AusStats._file_row(;
            cat_no,
            title,
            description,
            page_url="https://example.test/$cat_no",
            release_date="apr-2026",
            file_title,
            url="https://example.test/$filename",
            filename,
            file_type="xlsx",
            table_no="1",
            table_title=file_title,
            is_timeseries=true,
            is_cube=false,
        ))
    end

    cube_rows = [
        ("Detailed Labour Force data cube", "6202.0_lfs_detailed_cube.xlsx"),
        ("Gross flows data cube", "6202.0_lfs_gross_flows_cube.xlsx"),
        ("Labelled matrix Labour Force data cube", "6202.0_lfs_labelled_matrix_cube.xlsx"),
    ]
    for (file_title, filename) in cube_rows
        push!(rows, AusStats._file_row(;
            cat_no="6202.0",
            title="Labour Force, Australia",
            description="Labour force data cubes.",
            page_url="https://example.test/6202.0",
            release_date="apr-2026",
            file_title,
            url="https://example.test/$filename",
            filename,
            file_type="xlsx",
            table_no="",
            table_title=file_title,
            is_timeseries=false,
            is_cube=true,
        ))
    end

    index = AusStats._file_rows_dataframe(rows)
    AusStats._write_index(index)

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
    html = read(fixture_path("abs_publication_downloads.html"), String)
    doc = AusStats._parse_html(html)
    seed = first(AusStats.ABS_SEED_CATALOGUES)
    return AusStats._file_rows_dataframe(AusStats._discover_files_from_doc(
        doc,
        seed;
        title=seed.title,
        description=seed.description,
        page_url="https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/apr-2026",
    ))
end

function archive_fixture_releases()
    html = read(fixture_path("abs_archive_releases.html"), String)
    doc = AusStats._parse_html(html)
    seed = AusStats._seed_for_catalogue("6345.0")
    return AusStats._release_rows_dataframe(AusStats._discover_releases_from_doc(doc, seed))
end

function historical_release_fixture_rows()
    html = read(fixture_path("abs_wpi_sep_2019_downloads.html"), String)
    doc = AusStats._parse_html(html)
    seed = AusStats._seed_for_catalogue("6345.0")
    return AusStats._file_rows_dataframe(AusStats._discover_files_from_doc(
        doc,
        seed;
        title=seed.title,
        description=seed.description,
        page_url="https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/wage-price-index-australia/sep-2019",
    ))
end
