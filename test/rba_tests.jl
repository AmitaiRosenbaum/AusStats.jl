@testset "Provider API" begin
    rba_index_path = AusStats._rba_index_path()
    isfile(rba_index_path) && rm(rba_index_path)

    provider_rows = providers()
    @test Set(provider_rows.provider) == Set([:abs, :apra, :rba])
    @test AusStats.provider_id(AusStats._provider(" RBA ")) == :rba
    @test AusStats.provider_name(AusStats._provider(:apra)) ==
        "Australian Prudential Regulation Authority"
    @test nrow(datasets(:abs)) >= 1
    @test nrow(datafiles(:abs, "6202.0")) >= 1
    @test nrow(search_data("labour"; provider=:abs)) >= 1
    @test issubset(Set([:abs, :apra, :rba]), Set(search_data("").provider))
    @test nrow(datasets(:rba)) >= 1
    @test nrow(search_data("cash"; provider=:rba)) >= 1
    @test_throws ArgumentError datasets(:missing)
end

@testset "RBA discovery and readers" begin
    rba_index = rba_files()
    @test "A1" in rba_index.dataset_id
    @test "cash-rate-target" in rba_index.dataset_id
    @test "balance-sheet" in rba_index.dataset_id
    @test nrow(search_rba("cash")) >= 1
    @test only(rba_files("cash-rate-target")).resource_kind == :html

    html = """
    <html><body>
      <a href="/statistics/tables/b11-1.html">Assets & Liabilities of Australian-located Operations - B11.1</a>
      <a href="/statistics/tables/xls/b11-1-hist.xlsx">Assets & Liabilities of Australian-located Operations - B11.1</a>
      <a href="/statistics/tables/csv/b11-1-data.csv">Data</a>
      <a href="/statistics/tables/csv/f1-data.csv">F1 - Data</a>
    </body></html>
    """
    discovered = AusStats._provider_file_rows(
        AusStats._discover_rba_tables(AusStats._parse_html(html))
    )
    @test "B11.1" in discovered.dataset_id
    @test "F1" in discovered.dataset_id
    @test all(discovered.provider .== :rba)
    @test all(discovered.resource_kind .== :timeseries)

    csv_path = tempname() * ".csv"
    write(
        csv_path,
        """
        Metadata line ignored by parser
        Date,Target cash rate,Exchange rate
        2026-01-01,4.35,0.66
        2026-02-01,,0.65
        """,
    )
    tidy = read_rba(csv_path)
    @test names(tidy) == [
        "provider",
        "table_id",
        "table_title",
        "series_id",
        "series",
        "date",
        "value",
        "frequency",
        "unit",
        "source_url",
        "source_file",
    ]
    @test nrow(tidy) == 4
    @test unique(tidy.provider) == [:rba]
    @test tidy.date[1] == Date(2026, 1, 1)
    @test ismissing(tidy.value[2])

    cash_html = tempname() * ".html"
    write(
        cash_html,
        """
        <html><body>
          <h1>Cash Rate Target</h1>
          Effective Date Change% points Cash rate target %
          17 Jun 2026 0.00 4.35
          6 May 2026 +0.25 4.35
        </body></html>
        """,
    )
    cash = AusStats._read_rba_file(
        cash_html;
        metadata=(
            dataset_id="cash-rate-target", title="Cash Rate Target", source_url="fixture"
        ),
    )
    @test nrow(cash) == 2
    @test cash.effective_date == [Date(2026, 6, 17), Date(2026, 5, 6)]
    @test cash.cash_rate_target == [4.35, 4.35]

    balance_html = tempname() * ".html"
    write(
        balance_html,
        """
        <html><body>
          <h1>Reserve Bank of Australia Balance Sheet</h1>
          At close of business on Wednesday, 17 June 2026
          \$ million
          Liabilities and Equity Movement Assets Movement
          Australian notes on issue 107,212 -75
          Exchange Settlement balances 172,889 6,420
          Other liabilities 16,773 1,944
          Gold and foreign exchange 113,526 2,248
          Australian dollar investments 245,457 3,087
          Other assets 2,690 -416
          The Bank's liabilities and assets data are provided on a more disaggregated basis in statistical table A1.
        </body></html>
        """,
    )
    balance = AusStats._read_rba_file(
        balance_html;
        metadata=(dataset_id="balance-sheet", title="Balance Sheet", source_url="fixture"),
    )
    @test nrow(balance) == 6
    @test unique(balance.as_at) == [Date(2026, 6, 17)]
    @test "Australian notes on issue" in balance.item
    @test "Gold and foreign exchange" in balance.item
    @test balance.value[balance.item .== "Gold and foreign exchange"] == [113526.0]
end

@testset "RBA provider edge paths" begin
    @test nrow(search_data("cash")) >= 1
    @test nrow(datafiles(:rba, "cash-rate-target")) == 1
    @test AusStats._rba_table_title("Assets and Liabilities - B11.1", "B11.1") ==
        "Assets and Liabilities"
    @test AusStats._rba_table_title("B11.1", "B11.1") == "B11.1"
    @test AusStats._rba_table_id(
        "No table id", "https://www.rba.gov.au/statistics/tables/"
    ) === nothing
    @test AusStats._looks_like_rba_table_page(
        "https://www.rba.gov.au/statistics/tables/b11-1.html", "B11.1"
    )
    @test !AusStats._looks_like_rba_table_page("https://www.rba.gov.au/about/", "B11.1")
    @test AusStats._parse_rba_date(missing) === nothing
    @test AusStats._parse_rba_date(DateTime(2026, 1, 2, 3)) == Date(2026, 1, 2)
    @test AusStats._parse_rba_date("") === nothing
    @test AusStats._parse_rba_date("2026") == Date(2026, 1, 1)
    @test AusStats._parse_rba_date("not a date") === nothing
    @test AusStats._infer_frequency_from_dates(Date(2026, 1, 2)) == "daily"
    @test AusStats._rba_balance_sheet_date("No balance sheet date") === nothing
    @test isempty(AusStats._rba_balance_sheet_rows("No balance sheet segment"))

    empty_csv_path = tempname() * ".csv"
    write(empty_csv_path, "")
    @test isempty(AusStats._read_rba_csv(empty_csv_path))

    fallback_csv_path = tempname() * ".csv"
    write(fallback_csv_path, "Observation,Value\nnot a date,1\n")
    @test AusStats._rba_csv_header_index(["metadata", "Observation,Value"]) == 1
    @test AusStats._rba_date_column(DataFrame(; Observation=["not a date"], Value=[1])) ==
        "Observation"
    @test isempty(AusStats._read_rba_csv(fallback_csv_path))

    html_path = tempname() * ".html"
    write(
        html_path,
        """
        <html><body><table>
          <tr><th>Date</th><th>Value</th></tr>
          <tr><td>2026-01-01</td><td>1.0</td></tr>
        </table></body></html>
        """,
    )
    html = AusStats._read_rba_file(
        html_path;
        metadata=(dataset_id="html-fixture", title="HTML fixture", source_url="fixture"),
    )
    @test nrow(html) == 1
    @test html.provider == fill(:rba, 1)
    @test html.dataset_id == ["html-fixture"]

    empty_html_path = tempname() * ".html"
    write(empty_html_path, "<html><body>No tables</body></html>")
    @test isempty(AusStats._read_rba_file(empty_html_path))

    unsupported_path = tempname() * ".txt"
    write(unsupported_path, "unsupported")
    @test_throws ArgumentError AusStats._read_rba_file(unsupported_path)

    rows = AusStats._provider_file_rows([
        AusStats._provider_file_row(;
            provider=:rba,
            dataset_id="local-rba",
            title="Local RBA",
            description="Local RBA fixture",
            page_url="http://127.0.0.1/local-rba",
            release_date="",
            file_id="csv",
            file_title="Local CSV",
            url="http://127.0.0.1:1/local-rba.csv",
            filename="local-rba.csv",
            file_type="csv",
            resource_kind=:timeseries,
        ),
        AusStats._provider_file_row(;
            provider=:rba,
            dataset_id="local-rba",
            title="Local RBA",
            description="Local RBA fixture",
            page_url="http://127.0.0.1/local-rba",
            release_date="",
            file_id="html",
            file_title="Local HTML",
            url="http://127.0.0.1:1/local-rba.html",
            filename="local-rba.html",
            file_type="html",
            resource_kind=:html,
        ),
    ])
    AusStats._write_rba_index(rows)
    @test isequal(AusStats._read_rba_index(), rows)
    @test_throws ArgumentError AusStats._select_rba_file("local-rba"; file="missing")
    @test_throws ArgumentError AusStats._select_rba_file("missing-rba")

    server = HTTP.serve!(; listenany=true) do request
        target = string(request.target)
        if target == "/local-rba.csv"
            return HTTP.Response(200; body="Date,Target cash rate\n2026-01-01,4.35\n")
        elseif target == "/local-rba.html"
            return HTTP.Response(
                200;
                body="<html><body><table><tr><th>Date</th><th>Value</th></tr><tr><td>2026-01-01</td><td>1</td></tr></table></body></html>",
            )
        end
        return HTTP.Response(404, "missing")
    end

    try
        base = "http://127.0.0.1:$(HTTP.port(server))"
        live_rows = copy(rows)
        live_rows.url = replace.(live_rows.url, "http://127.0.0.1:1" => base)
        AusStats._write_rba_index(live_rows)

        cached_dir = mktempdir()
        cached_html = joinpath(cached_dir, "rba", "local-rba.html")
        mkpath(dirname(cached_html))
        touch(cached_html)
        @test download_rba("local-rba"; file="html", dest=cached_dir) == cached_html
        @test download_data(:rba, "local-rba"; file="html", dest=cached_dir) == cached_html
        cached_csv = joinpath(cached_dir, "rba", "local-rba.csv")
        mkpath(dirname(cached_csv))
        touch(cached_csv)
        @test download_rba("local-rba"; file="csv", dest=cached_dir) == cached_csv

        csv = read_rba(base * "/local-rba.csv"; cache=false)
        @test nrow(csv) == 1
        @test csv.value == [4.35]

        cached_from_id = read_rba("local-rba"; file="csv")
        @test nrow(cached_from_id) == 1
        @test unique(cached_from_id.table_id) == ["local-rba"]

        from_id = read_rba("local-rba"; file="csv", cache=false)
        @test nrow(from_id) == 1
        @test unique(from_id.table_id) == ["local-rba"]

        via_provider = read_data(:rba, "local-rba"; file="csv", cache=false)
        @test nrow(via_provider) == 1
        @test unique(via_provider.table_id) == ["local-rba"]

        html_from_url = read_rba(base * "/local-rba.html"; cache=false)
        @test nrow(html_from_url) == 1

        html_from_id = read_rba("local-rba"; file="html", cache=false)
        @test nrow(html_from_id) == 1
    finally
        close(server)
    end
end
