defmodule TheDotfather.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TheDotfather.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  @repo_enabled? Application.compile_env(:the_dotfather, :start_repo?, true)

  using do
    quote do
      alias TheDotfather.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import TheDotfather.DataCase
    end
  end

  setup tags do
    TheDotfather.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    if @repo_enabled? do
      pid =
        Ecto.Adapters.SQL.Sandbox.start_owner!(TheDotfather.Repo,
          shared: not tags[:async]
        )

      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    else
      :ok
    end
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
