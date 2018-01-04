defmodule Phauxth.Remember do
  @moduledoc """
  Remember me module.

  Check for a `remember_me` cookie, which contains a token. The token is
  then checked, and if it is valid, the user is added to the session.

  This module also contains functions to add / delete the `remember_me`
  cookie.

  ## Options

  There are three options:

    * `:max_age` - the length of the validity of the cookie / token
      * the default is one week
    * `:user_context` - the user context module to be used
      * the default is MyApp.Accounts
    * `:log_meta` - additional custom metadata for Phauxth.Log
      * this should be a keyword list

  In addition, there are also options for generating the token.
  See the documentation for the Phauxth.Token module for details.

  ## Examples

  Add the following line to the pipeline you want to authenticate in
  the `web/router.ex` file:

      plug Phauxth.Authenticate
      plug Phauxth.Remember

  Make sure you add the Phauxth.Remember Plug after Phauxth.Authenticate.
  """

  use Phauxth.Authenticate.Base
  alias Phauxth.{Login, Token}

  @max_age 7 * 24 * 60 * 60

  @impl true
  def init(opts) do
    {
      {
        Keyword.get(opts, :max_age, @max_age),
        Keyword.get(opts, :user_context, Utils.default_user_context()),
        opts
      },
      Keyword.get(opts, :log_meta, [])
    }
  end

  @impl true
  def call(%Plug.Conn{assigns: %{current_user: %{}}} = conn, _), do: conn

  def call(%Plug.Conn{req_cookies: %{"remember_me" => token}} = conn, {opts, log_meta}) do
    get_user_data(conn, token, opts)
    |> report(log_meta)
    |> set_user(conn)
  end

  def call(conn, _), do: conn

  def get_user_data(conn, token, {max_age, user_context, opts}) do
    with {:ok, user_id} <- Token.verify(conn, token, max_age, opts), do: user_context.get(user_id)
  end

  @impl true
  def set_user(nil, conn), do: assign(conn, :current_user, nil)

  def set_user(user, conn) do
    assign(conn, :current_user, user)
    |> Login.add_session(Login.gen_session_id("S"), user.id)
  end

  @doc """
  Add a remember me cookie to the conn.
  """
  def add_rem_cookie(conn, user_id, max_age \\ @max_age) do
    cookie = Token.sign(conn, user_id)
    put_resp_cookie(conn, "remember_me", cookie, http_only: true, max_age: max_age)
  end

  @doc """
  Delete the remember_me cookie from the conn.
  """
  def delete_rem_cookie(conn) do
    register_before_send(conn, &delete_resp_cookie(&1, "remember_me"))
  end
end
