defmodule CF.Authenticator.OAuth.Facebook do
  @moduledoc """
  OAuth2 for Facebook.
  Inspired by https://github.com/chrislaskey/oauth2_facebook
  """
  use OAuth2.Strategy
  alias CF.Authenticator.ProviderInfos
  alias DB.Schema.User
  alias Kaur.Result
  alias OAuth2.Client

  @client_defaults [
    strategy: __MODULE__,
    site: "https://graph.facebook.com",
    authorize_url: "https://www.facebook.com/dialog/oauth",
    token_url: "/v2.8/oauth/access_token",
    token_method: :get
  ]

  @query_defaults [
    user_fields: "id,email,locale,name,verified,picture"
  ]

  @doc """
  Construct a client for requests to Facebook.
  """
  def client(opts \\ []) do
    opts =
      @client_defaults
      |> Keyword.merge(config())
      |> Keyword.merge(opts)

    Client.new(opts)
  end

  def get_token!(params \\ [], opts \\ []) do
    opts
    |> client
    |> Client.get_token!(params)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param(:client_secret, client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  # Specific to Facebook
  @doc """
  revoke token on token on facebook
  """
  def revoke_permissions(user = %User{fb_user_id: fb_user_id}) do
    app_client()
    |> Client.delete("/#{fb_user_id}/permissions")
    |> Result.either(
      fn _error ->
        Result.error(
          "A problem with facebook permissions revocation happened with user #{fb_user_id}"
        )
      end,
      fn _ -> Result.ok(user) end
    )
  end

  @doc """
  Returns user information from Facebook graph's `/me` endpoint using the access_token.
  """
  def fetch_user(client, query_params \\ []) do
    case Client.get(client, user_path(client, query_params)) do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        {:error, "Unauthorized"}

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        {:ok, provider_infos(user)}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def user_path(client, query_params \\ []) do
    "/me?" <> user_query(client.token.access_token, query_params)
  end

  def appsecret_proof(access_token) do
    access_token
    |> hmac(:sha256, get_config(:client_secret))
    |> Base.encode16(case: :lower)
  end

  defp config do
    Application.get_env(:cf, :oauth)[:facebook]
  end

  defp get_config(key) do
    Keyword.get(config(), key)
  end

  defp hmac(data, type, key) do
    :crypto.hmac(type, key, data)
  end

  # ---- Private ----

  # Translate Facebook user structure into a generic ProviderInfos
  defp provider_infos(infos) do
    has_picture = get_in(infos, ["picture", "data", "is_silhouette"]) == false
    picture_url = "https://graph.facebook.com/#{infos["id"]}/picture?type=normal"

    %ProviderInfos{
      provider: :facebook,
      uid: infos["id"],
      name: infos["name"],
      nickname: infos["nickname"],
      email: infos["email"],
      locale: infos["locale"],
      picture_url: has_picture && picture_url
    }
  end

  defp user_query(access_token, query_params) do
    %{}
    |> Map.put(:fields, query_value(:user_fields))
    |> Map.put(:appsecret_proof, appsecret_proof(access_token))
    |> Map.merge(Enum.into(query_params, %{}))
    |> Enum.filter(fn {_, v} -> v != nil and v != "" end)
    |> URI.encode_query()
  end

  defp query_value(key) do
    @query_defaults
    |> Keyword.get(key)
  end

  # Construct a client with captain fact credentials to request Facebook
  @spec app_client(list()) :: Client.t()
  defp app_client(opts \\ []) do
    token = OAuth2.AccessToken.new("#{app_id()}|#{app_secret()}")

    opts
    |> client
    |> Map.put(:token, token)
  end

  defp app_id do
    Application.get_env(:cf, :oauth)[:facebook][:client_id]
  end

  defp app_secret do
    Application.get_env(:cf, :oauth)[:facebook][:client_secret]
  end
end
