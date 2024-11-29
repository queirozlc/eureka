defmodule Eureka.SpotifyAuthenticatorTest do
  use ExUnit.Case, async: true
  alias Eureka.SpotifyAuthenticator

  @valid_response %{
    access_token: "token",
    token_type: "bearer",
    expires_in: 3600,
    issued_at: DateTime.utc_now()
  }

  describe "request_token/0" do
    test "creates ets table if not exists" do
      assert :undefined == :ets.whereis(SpotifyAuthenticator.table())
      SpotifyAuthenticator.request_token()
      refute :undefined == :ets.whereis(SpotifyAuthenticator.table())
    end

    test "do not creates a new table if already exists one" do
      :ets.new(SpotifyAuthenticator.table(), [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

      table = SpotifyAuthenticator.table()
      SpotifyAuthenticator.request_token()
      assert table == SpotifyAuthenticator.table()
    end

    test "requests a token from Spotify" do
      Req.Test.stub(Eureka, fn conn ->
        Req.Test.json(conn, @valid_response)
      end)

      SpotifyAuthenticator.request_token()

      assert_receive {:token, "token"}
    end
  end

  describe "get_acces_token/0" do
    test "returns the token from the cache" do
      Req.Test.stub(Eureka, fn conn ->
        Req.Test.json(conn, @valid_response)
      end)

      SpotifyAuthenticator.request_token()

      assert_receive {:token, token}

      assert {:ok, token} == SpotifyAuthenticator.get_access_token()
    end

    test "requests a new token if the cache is empty" do
      Req.Test.stub(Eureka, fn conn ->
        Req.Test.json(conn, @valid_response)
      end)

      SpotifyAuthenticator.get_access_token()

      assert_receive {:token, "token"}
    end

    test "refreshes the token if it is expired" do
      expired_token = %{
        access_token: "token expired",
        token_type: "bearer",
        expires_in: 0,
        issued_at: DateTime.utc_now()
      }

      Req.Test.stub(Eureka, fn conn ->
        Req.Test.json(conn, expired_token)
      end)

      SpotifyAuthenticator.request_token()

      assert_receive {:token, "token expired"}

      Req.Test.stub(Eureka, fn conn ->
        Req.Test.json(conn, @valid_response)
      end)

      SpotifyAuthenticator.get_access_token()

      assert_receive {:token, "token"}
    end
  end
end
