defmodule CheckSignatureWeb.CheckControllerTest do
  use CheckSignatureWeb.ConnCase, async: false

  import Mox

  alias CheckSignature.Verification.{MockSource, Ruling}

  setup :set_mox_global

  setup do
    stub(MockSource, :name, fn -> "Sąd Najwyższy" end)
    :ok
  end

  defp post_document(conn, document) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/api/check", Jason.encode!(%{document: document}))
  end

  test "GET / serves the landing page", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)
    assert html =~ "Sprawdź Sygnaturę"
    assert html =~ "/api/check"
  end

  test "found signature returns a matched source with url", %{conn: conn} do
    stub(MockSource, :lookup, fn _ ->
      {:matched, %Ruling{signature: "II CSK 234/19", url: "https://example.test/ruling"}}
    end)

    resp =
      conn |> post_document("Powołano wyrok II CSK 234/19 w tej sprawie.") |> json_response(200)

    assert [verdict] = resp["verdicts"]
    assert verdict["signature"] == "II CSK 234/19"
    assert verdict["verdict"] == "found"

    assert [%{"name" => "Sąd Najwyższy", "outcome" => "matched", "url" => url}] =
             verdict["sources"]

    assert url == "https://example.test/ruling"
  end

  test "absent signature returns not_found with confirmed_absent source", %{conn: conn} do
    stub(MockSource, :lookup, fn _ -> :confirmed_absent end)

    resp = conn |> post_document("Rzekomy wyrok II CSK 999/99.") |> json_response(200)

    assert [verdict] = resp["verdicts"]
    assert verdict["verdict"] == "not_found"
    assert [%{"outcome" => "confirmed_absent"}] = verdict["sources"]
  end

  test "an errored source yields inconclusive, never not_found", %{conn: conn} do
    stub(MockSource, :lookup, fn _ -> {:errored, :timeout} end)

    resp = conn |> post_document("Zob. II CSK 555/18.") |> json_response(200)

    assert [verdict] = resp["verdicts"]
    assert verdict["verdict"] == "inconclusive"
    assert [%{"outcome" => "errored"}] = verdict["sources"]
  end

  test "a document with no signatures returns an empty verdict list", %{conn: conn} do
    resp =
      conn |> post_document("To pismo nie powołuje żadnego orzeczenia.") |> json_response(200)

    assert resp["verdicts"] == []
  end

  test "an oversized document is rejected with 413", %{conn: conn} do
    resp = conn |> post_document(String.duplicate("x", 100_001)) |> json_response(413)
    assert resp["error"] == "document_too_large"
  end

  test "a missing document param is rejected with 400", %{conn: conn} do
    resp =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/check", Jason.encode!(%{foo: "bar"}))
      |> json_response(400)

    assert resp["error"] == "missing_document"
  end
end
