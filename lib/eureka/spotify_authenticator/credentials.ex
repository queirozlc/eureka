defmodule Eureka.SpotifyAuthenticator.Credentials do
  @enforce_keys [:access_token, :token_type, :expires_in]
  defstruct [:access_token, :token_type, :expires_in, :issued_at]

  @type t :: %__MODULE__{
          access_token: String.t(),
          token_type: String.t(),
          expires_in: integer(),
          issued_at: DateTime.t()
        }

  @spec from_map(map()) :: __MODULE__.t()
  def from_map(map) do
    %__MODULE__{
      access_token: map["access_token"],
      token_type: map["token_type"],
      expires_in: map["expires_in"],
      issued_at: DateTime.utc_now()
    }
  end
end
