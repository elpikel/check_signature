defmodule CheckSignatureWeb.CheckControllerTest do
  use CheckSignatureWeb.ConnCase, async: true

  alias CheckSignature.Rulings

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

  test "a Signature in the index returns found with a matched source and url", %{conn: conn} do
    Rulings.upsert_all("supreme_court", [
      %{signature: "II CSK 234/19", url: "https://example.test/ruling"}
    ])

    resp =
      conn |> post_document("Powołano wyrok II CSK 234/19 w tej sprawie.") |> json_response(200)

    assert [verdict] = resp["verdicts"]
    assert verdict["signature"] == "II CSK 234/19"
    assert verdict["verdict"] == "found"

    assert [%{"name" => "Sąd Najwyższy", "outcome" => "matched", "url" => url}] =
             verdict["sources"]

    assert url == "https://example.test/ruling"
  end

  test "a Signature absent from the index returns inconclusive, never not_found", %{conn: conn} do
    resp = conn |> post_document("Rzekomy wyrok II CSK 999/99.") |> json_response(200)

    assert [verdict] = resp["verdicts"]
    assert verdict["verdict"] == "inconclusive"
    assert verdict["sources"] == []
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
