defmodule CheckSignatureWeb.PageController do
  use CheckSignatureWeb, :controller

  # The landing page is a self-contained static document (its own CSS/JS/fonts),
  # so we serve it verbatim rather than through the app's layout/asset pipeline.
  # It is embedded at compile time; @external_resource triggers recompilation
  # whenever the HTML changes.
  @landing_path Path.join(__DIR__, "page_html/landing.html")
  @external_resource @landing_path
  @landing File.read!(@landing_path)

  def home(conn, _params) do
    html(conn, @landing)
  end
end
