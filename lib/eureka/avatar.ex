defmodule Eureka.Avatar do
  @dicebear_url "https://api.dicebear.com/9.x/dylan/svg"

  def random do
    case get_image() do
      {:ok, %Req.Response{body: data, status: status}} ->
        handle_response(data, status)

      {:error, _} ->
        {:error, "Failed to fetch avatar"}
    end
  end

  defp handle_response(data, 200) do
    {:ok, %{avatar: data}}
  end

  defp handle_response(_, _), do: {:error, "Failed to fetch avatar"}

  defp seed, do: :crypto.strong_rand_bytes(16) |> Base.encode16()

  defp get_image do
    opts =
      [
        base_url: @dicebear_url,
        params: [seed: seed(), randomizeIds: true, mood: "happy,superHappy,hopeful", radius: 50]
      ]

    Req.request(opts)
  end
end
