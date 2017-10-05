defmodule CaptainFact.Accounts.UserPermissions do
  @moduledoc """
  Check and log user permissions. State is a map looking like this :
  """

  require Logger
  import Ecto.Query

  alias CaptainFact.Repo
  alias CaptainFact.Accounts.User
  alias CaptainFact.Actions.Recorder
  defmodule PermissionsError do
    defexception message: "forbidden", plug_status: 403
  end

  @levels [-30, -5, 15, 30, 50, 100, 200, 500, 1000]
  @reverse_levels Enum.reverse(@levels)
  @nb_levels Enum.count(@levels)
  @lowest_acceptable_reputation List.first(@levels)
  @limit_warning_threshold 5
  @limitations %{
    #                        /!\ |️ New user          | Confirmed user
    # reputation            {-30 , -5 , 15 , 30 , 50 , 100 , 200 , 500 , 1000}
    #-------------------------------------------------------------------------
    create: %{
      comment:              { 3  ,  5 , 10 , 20 , 30 , 200 , 200 , 200 , 200 },
      statement:            { 0  ,  5 ,  5 , 15 , 30 ,  50 , 100 , 100 , 100 },
      speaker:              { 0  ,  3 ,  10, 15 , 20 ,  30 ,  50 , 100 , 100 },
    },
    add: %{
      video:                { 0  ,  1 ,  5 , 10 , 15 ,  30 ,  30 ,  30 ,  30 },
      speaker:              { 0  ,  5 ,  10, 15 , 20 ,  30 ,  50 , 100 , 100 },
    },
    update: %{
      comment:              { 3  , 10 , 15 , 30 , 30 , 100 , 100 , 100 , 100 },
      statement:            { 0  ,  5 ,  0 ,  3 ,  5 ,  50 , 100 , 100 , 100 },
      speaker:              { 0  ,  0 ,  3 ,  5 , 10 ,  30 ,  50 , 100 , 100 },
    },
    delete: %{
    },
    remove: %{
      statement:            { 0  ,  5 ,  0 ,  3 ,  5 ,  10 ,  10 ,  10 ,  10 },
      speaker:              { 0  ,  0 ,  3 ,  5 , 10 ,  30 ,  50 , 100 , 100 },
    },
    restore: %{
      statement:            { 0  ,  5 ,  0 ,  3 ,  5 ,  15 ,  15 ,  15 ,  15 },
      speaker:              { 0  ,  0 ,  0 ,  5 , 10 ,  30 ,  50 , 100 , 100 }
    },
    approve: %{
      history_action:       { 0  ,  0 ,  0 ,  0 ,  0 ,   0 ,   0 ,   0 ,   0 },
    },
    flag: %{
      history_action:       { 0  ,  1 ,  3 ,  5 ,  5 ,   5 ,   5 ,   5 ,   5 },
      comment:              { 0  ,  0 ,  1 ,  3 ,  3 ,   5 ,  10 ,  10 ,  10 },
    },
    vote_up:                { 0  ,  5 , 15 , 30 , 45 , 100 , 125 , 150 , 200 },
    vote_down:              { 0  ,  0 ,  0 ,  5 , 10 ,  20 ,  40 ,  80 , 150 },
    self_vote:              { 3  ,  10, 15 , 30 , 50 , 250 , 250 , 250 , 250 },
  }
  @error_not_enough_reputation "not_enough_reputation"
  @error_limit_reached "limit_reached"

  # --- API ---

  @doc """
  DEPRECATED - No need for such a security, use check!

  The safe way to ensure limitations and record actions as state is locked during `func` execution.
  Raises PermissionsError if user doesn't have the permission.

  lock! will do an optimistic lock by incrementing the counter for this action then execute func.
  Returning a tupe like {:error, _} or raiseing / raising in `func` will revert the action
  """
  def lock!(user = %User{}, action_type, entity, func) do
    check!(user, action_type, entity)
    return = func.(user)
    unless match?({:error, _}, return), do: Recorder.record!(user, action_type, entity)
    return
  end
  def lock!(user_id, action_type, entity, func) when is_integer(user_id) or is_nil(user_id),
    do: lock!(do_load_user!(user_id), action_type, entity, func)

  @doc """
  Run Repo.transaction while locking permissions. Usefull when piping
  """
  def lock_transaction!(transaction = %Ecto.Multi{}, user, action_type, entity),
    do: lock!(user, action_type, entity, fn _ -> Repo.transaction(transaction) end)

  @doc """
  Check if user can execute action. Return {:ok, nb_available} if yes, {:error, reason} otherwise
  ## Examples
      iex> alias CaptainFact.Accounts.{User, UserPermissions}
      iex> user = CaptainFact.Factory.insert(:user, %{reputation: 45})
      iex> UserPermissions.check(user, :create, :comment)
      {:ok, 20}
      iex> UserPermissions.check(%{user | reputation: -42}, :remove, :statement)
      {:error, "not_enough_reputation"}
      iex> limitation = UserPermissions.limitation(user, :create, :comment)
      iex> for _ <- 1..limitation, do: UserPermissions.record_action(user, :create, :comment)
      iex> UserPermissions.check(user, :create, :comment)
      {:error, "limit_reached"}
  """
  def check(user = %User{}, action_type, entity) do
    limit = limitation(user, action_type, entity)
    if (limit == 0) do
      {:error, @error_not_enough_reputation}
    else
      action_count = if is_wildcard_limitation(action_type),
        do: Recorder.count(user, action_type),
        else: Recorder.count(user, action_type, entity)
      if action_count >= limit do
        if action_count >= limit + @limit_warning_threshold,
          do: Logger.warn("User #{user.username} (#{user.id}) overthrown its limit for [#{action_type} #{entity}] (#{action_count}/#{limit})")
        {:error, @error_limit_reached}
      else
        {:ok, limit - action_count}
      end
    end
  end
  def check(nil, _, _), do: {:error, "unauthorized"}
  def check!(user = %User{}, action_type, entity) do
    case check(user, action_type, entity) do
      {:ok, _} -> :ok
      {:error, message} -> raise %PermissionsError{message: message}
    end
  end
  def check!(user_id, action_type, entity) when is_integer(user_id)  do
     check!(do_load_user!(user_id), action_type, entity)
  end
  def check!(nil, _, _), do: raise %PermissionsError{message: "unauthorized"}

  @doc """
  DEPRECATED - This is a job for CaptainFact.Actions.Recorder
  Doesn't verify user's limitation nor reputation, you need to check that by yourself
  """
  def record_action(user = %User{}, action_type, entity) do
    Recorder.record!(user, action_type, entity)
  end
  def record_action(user_id, action_type, entity) when is_integer(user_id),
    do: record_action(%User{id: user_id}, action_type, entity)

  # DEPRECATED - Use Recorder
  def user_nb_action_occurences(user = %User{}, action_type, entity) do
    Recorder.count(user, action_type, entity)
  end

  def limitation(user = %User{}, action_type, entity) do
    case level(user) do
      -1 -> 0 # Reputation under minimum user can't do anything
      level ->
        case Map.get(@limitations, action_type) do
          l when is_tuple(l) -> elem(l, level)
          l when is_map(l) -> elem(Map.get(l, entity), level)
        end
    end
  end

  def is_wildcard_limitation(action_type) do
    is_tuple(Map.get(@limitations, action_type))
  end

  def level(%User{reputation: reputation}) do
    if reputation < @lowest_acceptable_reputation,
      do: -1,
      else: (@nb_levels - 1) - Enum.find_index(@reverse_levels, &(reputation >= &1))
  end

  # Static getters
  def limitations(), do: @limitations
  def nb_levels(), do: @nb_levels

  defp do_load_user!(nil), do: raise %PermissionsError{message: "unauthorized"}
  defp do_load_user!(user_id) do
    User
    |> where([u], u.id == ^user_id)
    |> select([:id, :reputation])
    |> Repo.one!()
  end
end
