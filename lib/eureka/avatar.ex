defmodule Eureka.Avatar do
  @dicebear_url "https://api.dicebear.com/9.x/dylan/svg"

  def random(pid) do
    Task.async(fn -> fetch_avatar(pid) end)
  end

  defp fetch_avatar(pid) do
    url =
      @dicebear_url <> "?seed=#{seed()}&randomizeIds=true&mood=happy,superHappy,hopeful"

    Req.get(url, into: fn {:data, data}, {req, res} -> handle_response(data, {req, res}, pid) end)
  end

  defp handle_response(data, {req, res}, pid) do
    send(pid, {:avatar, data})
    {:halt, {req, res}}
  end

  defp seed, do: System.unique_integer([:positive])
end
