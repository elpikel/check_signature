defmodule CheckSignatureWeb.AnalyticsControllerTest do
  # async: false — the script cache lives in global :persistent_term
  use CheckSignatureWeb.ConnCase, async: false

  setup do
    # Start each test from a cold script cache
    :persistent_term.erase({CheckSignatureWeb.AnalyticsController, :script})
    :ok
  end

  describe "GET /js/stats.js" do
    test "proxies and serves the Plausible script with caching headers", %{conn: conn} do
      Req.Test.stub(CheckSignatureWeb.AnalyticsController, fn upstream ->
        upstream
        |> Plug.Conn.put_resp_content_type("application/javascript")
        |> Plug.Conn.send_resp(200, "console.log('plausible')")
      end)

      conn = get(conn, ~p"/js/stats.js")

      assert response(conn, 200) =~ "plausible"
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "javascript"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
    end

    test "returns 502 when the upstream script fetch fails", %{conn: conn} do
      Req.Test.stub(CheckSignatureWeb.AnalyticsController, fn upstream ->
        Plug.Conn.send_resp(upstream, 500, "boom")
      end)

      conn = get(conn, ~p"/js/stats.js")
      assert response(conn, 502)
    end
  end

  describe "POST /api/event" do
    test "forwards the event body to Plausible and returns its status (no CSRF token)", %{
      conn: conn
    } do
      payload = ~s({"name":"pageview","domain":"orzecze-nie.pl"})

      Req.Test.stub(CheckSignatureWeb.AnalyticsController, fn upstream ->
        # verify the raw event body is forwarded untouched
        {:ok, body, upstream} = Plug.Conn.read_body(upstream)
        assert body == payload
        Plug.Conn.send_resp(upstream, 202, "accepted")
      end)

      # Plausible posts as text/plain, which passes through the endpoint parsers unparsed.
      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/api/event", payload)

      assert response(conn, 202) == "accepted"
    end
  end
end
