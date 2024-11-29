defmodule Eureka.ExGroq do
  alias __MODULE__.Response
  @api_url "https://api.groq.com/openai/v1/chat/completions"
  @app :eureka
  @api_key Application.compile_env!(:eureka, :groq_api_key)

  @doc """
  Sends a prompt to the Groq API to generate a response.

  Using this function you will not be able to get the response
  streamed neither the response as a chat message.

  The response of this function will be always a json format, and that's why you **MUST** to pass a json object somewhere in the prompt.

  preferably especify the format of the json object in the prompt as well, example: "Please, answer me in a json format with the following structure:

  ```
    {
      "key": "value"
    }
  ```
  """
  @spec ask!(prompt :: String.t()) :: Response.t()
  def ask!(prompt) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{@api_key}"}
    ]

    body =
      %{
        "messages" => [
          %{
            "role" => "system",
            "content" => prompt
          }
        ],
        "model" => "llama3-8b-8192",
        "temperature" => 1,
        "max_tokens" => 1024,
        "top_p" => 1,
        "stream" => false,
        "stop" => nil,
        "response_format" => %{
          "type" => "json_object"
        }
      }

    opts =
      [
        url: @api_url,
        headers: headers,
        retry: :transient,
        method: :post,
        json: body
      ]
      |> Keyword.merge(Application.get_env(@app, :eureka_req_options, []))

    [choice] = Req.post!(opts).body |> Map.get("choices")
    choice |> Map.get("message") |> Response.new!()
  end
end

defmodule Eureka.ExGroq.Response do
  @enforce_keys [:content]
  defstruct content: nil

  @type t :: %__MODULE__{
          content: map()
        }

  def new!(params) do
    content =
      params
      |> Map.get("content")
      |> Jason.decode!()

    %__MODULE__{
      content: content
    }
  end
end
