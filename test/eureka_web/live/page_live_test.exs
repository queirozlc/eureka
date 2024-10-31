defmodule EurekaWeb.PageLiveTest do
  use EurekaWeb.ConnCase, async: true
  import Eureka.AccountsFixtures

  import Phoenix.LiveViewTest

  describe "Home page" do
    test "renders home page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Listen and Guess"
      assert html =~ "Log in"
      assert html =~ "Register"
    end
  end

  describe "users authentication" do
    test "renders registration page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("li > a", "Register")
      |> render_click()

      assert_redirected(view, ~p"/users/register")
    end

    test "renders sign in page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, %Plug.Conn{} = conn} =
        view
        |> element("li > a", "Log in")
        |> render_click()
        |> follow_redirect(conn)

      assert_redirected(view, ~p"/users/log_in")

      html = conn.resp_body
      assert html =~ "Log in"
    end
  end

  describe "user guest authentication modal" do
    test "renders sign in modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert view
             |> element("button", "Create a new room")
             |> render_click()

      assert_patch(view, ~p"/users/guest/log_in")
    end

    test "ensures avatar rendered in guest modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert view
             |> element("#create_room")
             |> render_click()

      html = render_async(view, 2000)

      assert html =~ "Enter as guest"
      assert has_element?(view, "#avatar_container svg")
    end

    test "renders sign in modal when tries to access an authenticated route", %{conn: conn} do
      result =
        conn
        |> live(~p"/rooms/B23A/settings")
        |> follow_redirect(conn, ~p"/users/guest/log_in")

      assert {:ok, %Plug.Conn{resp_body: html} = _conn} = result
      assert html =~ "You must log in to access this page."
      assert html =~ "Enter as guest"
    end

    test "performs a guest sign in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/guest/log_in")

      nickname = "caslu"

      form = form(view, "#guest-form", user: %{"nickname" => nickname})
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ "Settings"
      assert response =~ "Log out"
    end

    test "guest modal redirects to sign in page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/guest/log_in")

      {:ok, _lv, disconnected_html} =
        view
        |> element(~s"{[href='/users/log_in'][data-phx-link='redirect']}", "Log in")
        |> render_click()
        |> follow_redirect(conn)

      assert_redirected(view, ~p"/users/log_in")
      assert disconnected_html =~ "Log in"
      assert disconnected_html =~ "Register"
      assert disconnected_html =~ "Forgot your password?"
    end
  end

  describe "user settings and logout" do
    setup %{conn: conn} do
      current_user = user_fixture()
      conn = log_in_user(conn, current_user)
      {:ok, conn: conn, current_user: current_user}
    end

    test "renders a user settings page", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/")

      assert {:ok, %Plug.Conn{} = _conn} =
               view
               |> element("li > a", "Settings")
               |> render_click()
               |> follow_redirect(conn)

      assert_redirected(view, ~p"/users/settings")
    end

    test "logs out a user", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/")

      assert {:ok, %Plug.Conn{} = _conn} =
               view
               |> element("li > a", "Log out")
               |> render_click()
               |> follow_redirect(conn)

      assert_redirected(view, ~p"/users/log_out")
    end
  end

  describe "creating and joining new room" do
    setup %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      {:ok, conn: conn}
    end

    test "creates a room and redirects to room settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> element("#create_room")
               |> render_click()

      assert to =~ ~r"/rooms/\w+/settings"
    end
  end
end
