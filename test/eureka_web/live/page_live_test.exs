defmodule EurekaWeb.PageLiveTest do
  use EurekaWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /" do
    test "renders the page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")
      assert html =~ "Listen and Guess"
      assert has_element?(view, "#player_info-content")
    end
  end
end
