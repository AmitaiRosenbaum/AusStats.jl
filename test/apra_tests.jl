@testset "APRA provider API" begin
    apra_index_path = AusStats._apra_index_path()
    isfile(apra_index_path) && rm(apra_index_path)

    provider_rows = providers()
    @test :apra in provider_rows.provider
    @test nrow(apra_publications()) >= 2
    @test nrow(apra_files("monthly-authorised-deposit-taking-institution-statistics")) >= 2
    @test nrow(search_apra("deposit-taking")) >= 1
    @test nrow(datasets(:apra)) >= 2
    @test nrow(
        datafiles(:apra, "quarterly-authorised-deposit-taking-institution-statistics")
    ) >= 2
    @test nrow(search_data("centralised"; provider=:apra)) >= 1
end

@testset "APRA discovery helpers" begin
    listing_html = """
    <html><body>
      <h2><a href="/news-and-publications/monthly-authorised-deposit-taking-institution-statistics">Monthly Authorised Deposit-taking Institution Statistics</a></h2>
      <h2><a href="/news-and-publications/quarterly-superannuation-statistics">Quarterly superannuation statistics</a></h2>
      <a href="/news-and-publications?created=All">News listing</a>
      <a href="/about-apra">About APRA</a>
    </body></html>
    """
    publications = AusStats._discover_apra_publications(AusStats._parse_html(listing_html))
    ids = sort([row.dataset_id for row in publications])
    @test ids == [
        "monthly-authorised-deposit-taking-institution-statistics",
        "quarterly-superannuation-statistics",
    ]
    @test all(startswith(row.page_url, "https://www.apra.gov.au/") for row in publications)

    publication_html = """
    <html><body>
      <h1>Monthly Authorised Deposit-taking Institution Statistics</h1>
      <p>Published</p><p>29 May 2026</p>
      <p>The Monthly Authorised Deposit-taking Institution Statistics publication provides selected information.</p>
      <a href="/sites/default/files/2026-05/monthly_authorised_deposit-taking_institution_statistics_april_2026.xlsx">Monthly authorised deposit-taking institution statistics April 2026 XLSX 332.30 KB ‧ 29 May 2026</a>
      <a href="/sites/default/files/2026-05/monthly_authorised_deposit-taking_institution_statistics_glossary.pdf">Monthly authorised deposit-taking institution statistics glossary PDF 72.36 KB ‧ 29 January 2021</a>
      <a href="https://example.com/offsite.xlsx">Offsite file</a>
    </body></html>
    """
    files = AusStats._provider_file_rows(
        AusStats._discover_apra_files_from_doc(
            AusStats._parse_html(publication_html);
            dataset_id="madis",
            title="Monthly ADI",
            description="Fixture description",
            page_url="https://www.apra.gov.au/news-and-publications/monthly-authorised-deposit-taking-institution-statistics",
            release_date="",
        ),
    )
    @test nrow(files) == 2
    @test Set(files.file_type) == Set(["xlsx", "pdf"])
    @test Set(files.resource_kind) == Set([:dataset, :document])
    @test "Monthly authorised deposit-taking institution statistics April 2026" in
        files.file_title
    @test files.release_date[files.file_type .== "xlsx"] == ["29 May 2026"]
    @test AusStats._apra_file_type("https://www.apra.gov.au/file.csv?download=1") == "csv"
    @test AusStats._apra_publication_id(
        "https://www.apra.gov.au/news-and-publications/Quarterly-ADI-Statistics"
    ) == "quarterly-adi-statistics"
    @test AusStats._apra_date_from_text("XLSX 1.2 MB ‧ 12 March 2026") == "12 March 2026"
    @test AusStats._apra_date_from_text("No date") === nothing
end

@testset "APRA reading and cache flows" begin
    local_dir = mktempdir()
    workbook = joinpath(local_dir, "apra.xlsx")
    XLSX.openxlsx(workbook; mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Capital")
        sheet["A1"] = "Period"
        sheet["B1"] = "Entity"
        sheet["C1"] = "Value"
        sheet["A2"] = "Mar-2026"
        sheet["B2"] = "Bank A"
        sheet["C2"] = 10.5

        sheet = XLSX.addsheet!(xf, "Liquidity")
        sheet["A1"] = "Period"
        sheet["B1"] = "Ratio"
        sheet["A2"] = "Jun-2026"
        sheet["B2"] = 12.0
    end

    read = read_apra(workbook)
    @test nrow(read) == 2
    @test Set(read.sheet) == Set(["Capital", "Liquidity"])
    @test unique(read.provider) == [:apra]
    @test "publication_id" in names(read)
    @test read.source_file == fill(abspath(workbook), 2)

    metadata = (
        dataset_id="fixture-publication",
        title="Fixture APRA publication",
        file_title="Fixture workbook",
        source_url="https://www.apra.gov.au/fixture.xlsx",
    )
    direct = AusStats._read_apra_file(workbook; metadata, source_url=metadata.source_url)
    @test unique(direct.publication_id) == ["fixture-publication"]
    @test unique(direct.publication_title) == ["Fixture APRA publication"]
    @test unique(direct.file_title) == ["Fixture workbook"]

    csv_path = joinpath(local_dir, "apra.csv")
    write(csv_path, "Period,Entity,Value\nMar-2026,Bank A,1.5\nJun-2026,Bank B,2.5\n")
    csv = read_apra(csv_path)
    @test nrow(csv) == 2
    @test csv.Value == [1.5, 2.5]
    @test all(ismissing, csv.sheet)

    html_path = joinpath(local_dir, "apra.html")
    write(
        html_path,
        """
        <html><body><table>
          <tr><th>Period</th><th>Value</th></tr>
          <tr><td>Mar-2026</td><td>3.5</td></tr>
        </table></body></html>
        """,
    )
    html = read_apra(html_path)
    @test nrow(html) == 1
    @test html.Period == ["Mar-2026"]

    cached_dest = mktempdir()
    selected = AusStats._select_apra_file(
        "monthly-authorised-deposit-taking-institution-statistics"; file="april"
    )
    cached_path = joinpath(cached_dest, "apra", selected.filename)
    mkpath(dirname(cached_path))
    touch(cached_path)
    @test download_apra(
        "monthly-authorised-deposit-taking-institution-statistics";
        file="april",
        dest=cached_dest,
    ) == cached_path

    @test_throws ArgumentError AusStats._select_apra_file("missing-publication")
    @test_throws ArgumentError AusStats._select_apra_file(
        "monthly-authorised-deposit-taking-institution-statistics"; file="missing"
    )

    pdf = joinpath(local_dir, "apra.pdf")
    write(pdf, "not really a pdf")
    @test_throws ArgumentError read_apra(pdf)

    rows = AusStats._provider_file_rows([
        AusStats._provider_file_row(;
            provider=:apra,
            dataset_id="fixture",
            title="Fixture",
            description="Fixture description",
            page_url="https://www.apra.gov.au/fixture",
            release_date="1 January 2026",
            file_id="fixture-file",
            file_title="Fixture file",
            url="https://www.apra.gov.au/fixture.xlsx",
            filename="fixture.xlsx",
            file_type="xlsx",
            resource_kind=:dataset,
        ),
    ])
    AusStats._write_apra_index(rows)
    cached = AusStats._read_apra_index()
    @test isequal(cached, rows)
    @test only(apra_files("fixture")).file_title == "Fixture file"
end

@testset "APRA URL and provider edge paths" begin
    apra_index_path = AusStats._apra_index_path()
    isfile(apra_index_path) && rm(apra_index_path)

    @test nrow(search_data("deposit-taking")) >= 1
    @test nrow(search_data("deposit-taking"; provider=nothing)) >= 1
    @test nrow(AusStats._empty_provider_file_rows()) == 0
    @test nrow(datafiles(:abs, "6202.0"; release="apr-2026")) >= 1
    AusStats._write_release_index("6345.0", archive_fixture_releases())
    AusStats._write_release_file_index(
        "6345.0", Date(2019, 9, 1), historical_release_fixture_rows()
    )
    @test nrow(datafiles(:abs, "6345.0"; release=Date(2019, 9, 1))) >= 1
    @test_throws ArgumentError datafiles(:abs; release=Date(2026, 4, 1))

    unsupported = tempname() * ".txt"
    write(unsupported, "unsupported")
    @test_throws ArgumentError read_apra(unsupported)

    rows = AusStats._provider_file_rows([
        AusStats._provider_file_row(;
            provider=:apra,
            dataset_id="local-apra",
            title="Local APRA",
            description="Local APRA fixture",
            page_url="http://127.0.0.1/local-apra",
            release_date="1 January 2026",
            file_id="xlsx",
            file_title="Local APRA workbook",
            url="http://127.0.0.1:1/local-apra.xlsx",
            filename="local-apra.xlsx",
            file_type="xlsx",
            resource_kind=:dataset,
        ),
        AusStats._provider_file_row(;
            provider=:apra,
            dataset_id="local-apra",
            title="Local APRA",
            description="Local APRA fixture",
            page_url="http://127.0.0.1/local-apra",
            release_date="1 January 2026",
            file_id="html",
            file_title="Local APRA HTML",
            url="http://127.0.0.1:1/local-apra.html",
            filename="local-apra.html",
            file_type="html",
            resource_kind=:dataset,
        ),
        AusStats._provider_file_row(;
            provider=:apra,
            dataset_id="local-apra-doc",
            title="Local APRA document",
            description="Local APRA document fixture",
            page_url="http://127.0.0.1/local-apra-doc",
            release_date="1 January 2026",
            file_id="pdf",
            file_title="Local APRA PDF",
            url="http://127.0.0.1:1/local-apra.pdf",
            filename="local-apra.pdf",
            file_type="pdf",
            resource_kind=:document,
        ),
    ])

    workbook = tempname() * ".xlsx"
    XLSX.openxlsx(workbook; mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Data")
        sheet["A1"] = "Period"
        sheet["B1"] = "Value"
        sheet["A2"] = "Mar-2026"
        sheet["B2"] = 9.0
    end
    workbook_bytes = read(workbook)

    server = HTTP.serve!(; listenany=true) do request
        target = string(request.target)
        if target == "/local-apra.xlsx"
            return HTTP.Response(200; body=workbook_bytes)
        elseif target == "/local-apra.csv"
            return HTTP.Response(200; body="Period,Value\nMar-2026,8\n")
        elseif target == "/local-apra.html"
            return HTTP.Response(
                200;
                body="<html><body><table><tr><th>Period</th><th>Value</th></tr><tr><td>Mar-2026</td><td>7</td></tr></table></body></html>",
            )
        end
        return HTTP.Response(404, "missing")
    end

    try
        base = "http://127.0.0.1:$(HTTP.port(server))"
        live_rows = copy(rows)
        live_rows.url = replace.(live_rows.url, "http://127.0.0.1:1" => base)
        AusStats._write_apra_index(live_rows)

        cached_dir = mktempdir()
        cached_html = joinpath(cached_dir, "apra", "local-apra.html")
        mkpath(dirname(cached_html))
        touch(cached_html)
        @test download_apra("local-apra"; file="html", dest=cached_dir) == cached_html
        @test download_data(:apra, "local-apra"; file="html", dest=cached_dir) ==
            cached_html

        from_url = read_apra(base * "/local-apra.xlsx"; cache=false)
        @test nrow(from_url) == 1
        @test from_url.Value == [9.0]

        from_csv_url = read_apra(base * "/local-apra.csv"; cache=false)
        @test nrow(from_csv_url) == 1
        @test from_csv_url.Value == [8]

        cached_from_id = read_apra("local-apra"; file="xlsx")
        @test nrow(cached_from_id) == 1
        @test unique(cached_from_id.publication_id) == ["local-apra"]

        from_id = read_apra("local-apra"; file="xlsx", cache=false)
        @test nrow(from_id) == 1
        @test unique(from_id.publication_id) == ["local-apra"]

        via_provider = read_data(:apra, "local-apra"; file="xlsx", cache=false)
        @test nrow(via_provider) == 1
        @test unique(via_provider.publication_id) == ["local-apra"]

        from_html_id = read_apra("local-apra"; file="html", cache=false)
        @test nrow(from_html_id) == 1
        @test from_html_id.Value == ["7"]

        @test_throws ArgumentError read_apra("local-apra-doc"; file="pdf")
    finally
        close(server)
    end
end
