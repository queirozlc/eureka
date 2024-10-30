defmodule Eureka.AvatarTest do
  use ExUnit.Case, async: true

  alias Eureka.Avatar

  describe "random/0" do
    test "returns a map with avatar" do
      assert {:ok, response} = Avatar.random()
      assert %{avatar: avatar} = response
      assert avatar =~ ~r/<svg/
    end
  end
end
