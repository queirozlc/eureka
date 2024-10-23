defmodule Eureka.Avatar do
  @dicebear_url "https://api.dicebear.com/9.x/dylan/svg"

  def random do
    url =
      @dicebear_url <> "?seed=#{seed()}&randomizeIds=true&mood=happy,superHappy,hopeful"

    case Req.get(url) do
      {:ok, %Req.Response{body: data, status: status}} ->
        handle_response(data, status)

      {:error, _} ->
        {:error, "Failed to fetch avatar"}
    end
  end

  defp handle_response(data, 200) do
    {:ok, %{avatar: data}}
  end

  defp handle_response(_, 404), do: {:error, "Avatar not found"}

  defp handle_response(_, _), do: {:error, "Failed to fetch avatar"}

  defp seed, do: System.unique_integer([:positive])
end
