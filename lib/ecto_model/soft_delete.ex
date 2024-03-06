defmodule EctoModel.SoftDelete do
  @moduledoc """
  Module responsible for allowing your schemas to opt into soft delete functionality.

  ## Usage

  There are two things that need to happen in order to make a schema soft deletable:

  1) You need to ensure your `MyApp.Repo` module is using the `EctoMiddleware` behaviour, and you add the `EctoModel.SoftDelete` middleware to
     the `middleware/2` callback before the `EctoMiddleware.Super` middleware.

     This will enable `EctoModel.SoftDelete` to raise errors if users try to hard delete records when schemas have opted into soft deletes.

     In future, we may add support for automatically delegating hard delete operations to transparently behave transparently as soft deletes in an
     opt in basis.

     You can also optionally add the following code to your `MyApp.Repo` module to enable easy soft delete operations:

     ```elixir
     def soft_delete!(resource, opts \\ []) do
       EctoModel.SoftDelete.soft_delete!(resource, Keyword.put(opts, :repo, __MODULE__))
     end

     def soft_delete(resource, opts \\ []) do
       EctoModel.SoftDelete.soft_delete(resource, Keyword.put(opts, :repo, __MODULE__))
     end
     ```

  2) You need to `use EctoModel.SoftDelete` in your schema, and configure the `field` and `type` options.

     The specified field and type must match what is defined on said schema, though there are compile time validations provided for you to ensure
     this remains in sync with your schema's natural evolution.

     Additionally, if your schema also opts into implementing the `EctoModel.Queryable` behaviour, we automatically provide a `base_query/0`
     implementation to will apply the neccessary filters to automatically filter out soft deleted records from query results.

     If you need to specify a custom `base_query/0` implementation, you can do so while still inheriting the default behaviour provided when
     using this module by calling `super()` in your custom implementation like so:

     ```elixir
     @impl EctoModel.Queryable
     def base_query do
       from x in ^super(), where: x.show_by_default != false
     end
     ```

  A full example of how to use `EctoModel.SoftDelete` is as follows:

  ```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo, otp_app: :my_app
    use EctoMiddleware

    def middleware(_resource, _resolution) do
      [EctoModel.SoftDelete, EctoMiddleware.Super]
    end
  end

  defmodule MyApp.User do
    use Ecto.Schema
    use EctoModel.SoftDelete, field: :deleted_at, type: :utc_datetime

    schema "users" do
      field(:name, :string)
      field(:email, :string)
      field(:deleted_at, :utc_datetime)
    end
  end
  ```
  """

  @type soft_delete_type :: :utc_datetime | :datetime | :boolean

  # TODO: implement support for `delete_all/2` in `EctoMiddleware`
  @delete_callbacks [:delete, :delete!]
  @supported_types [:utc_datetime, :datetime, :boolean]

  defmodule Config do
    @moduledoc false
    @type t :: %__MODULE__{field: atom(), type: EctoModel.SoftDelete.soft_delete_type()}
    defstruct field: :deleted_at, type: :utc_datetime
  end

  @doc "After compile hook responsible for validating that a schema is properly configured for soft deletes."
  def __after_compile__(env, _bytecode) do
    module = env.module
    :ok = __MODULE__.validate_schema_fields!(module)
  end

  @doc "Persists the configuration for soft deletes on the schema, as well as providing a default impl. for `EctoModel.Queryable.base_query/0`."
  defmacro __using__(opts) do
    field = __MODULE__.soft_delete_field!(opts[:field])
    type = __MODULE__.soft_delete_type!(opts[:type])

    quote location: :keep do
      @after_compile unquote(__MODULE__)

      def soft_delete_config,
        do: %unquote(__MODULE__).Config{field: unquote(field), type: unquote(type)}

      @impl EctoModel.Queryable
      def base_query do
        import Ecto.Query
        unquote(__MODULE__).apply_filter!(__MODULE__, __MODULE__)
      end

      defoverridable base_query: 0
    end
  end

  @doc false
  @spec validate_schema_fields!(schema :: module()) :: :ok | no_return()
  # Internal only, exposed as a public function as this is intended to be called by the `__after_compile__/2` callback from another module.
  # Validates configuration for soft deletes on a schema is valid and matches schema definition.
  def validate_schema_fields!(schema) do
    callbacks = [soft_delete_config: 0, __schema__: 1]

    if Enum.all?(callbacks, fn {fun, arity} -> function_exported?(schema, fun, arity) end) do
      %Config{} = config = schema.soft_delete_config()

      cond do
        config.field not in schema.__schema__(:fields) ->
          field_not_configured(schema, config)

        schema.__schema__(:type, config.field) != config.type ->
          field_type_mismatch(schema, config)

        true ->
          :ok
      end
    end

    :ok
  end

  defp field_not_configured(schema, %Config{} = config) when is_atom(schema) do
    raise ArgumentError, """
    The `#{inspect(schema)}` schema is configured to implement soft deletes via the
    `#{inspect(config.field)}` field, but this field does not exist on said schema.

    Please ensure that the `#{inspect(config.field)}` field is defined on the schema,
    with the type `#{inspect(config.type)}`, or change the configuration to point
    to a different field via the `field: field_name :: atom()` when `use`-ing
    `inspect(#{__MODULE__})`
    """
  end

  defp field_type_mismatch(schema, %Config{} = config) when is_atom(schema) do
    raise ArgumentError, """
    The `#{inspect(schema)}` schema is configured to implement soft deletes via the
    `#{inspect(config.field)}` field of type `#{inspect(config.type)}`,
    but this field has the wrong type.

    Please ensure that the `#{inspect(config.field)}` field is defined on the schema,
    with the type `:#{inspect(config.type)}`, or change the configuration to point
    to a different field via the `type: type_name :: atom()` when `use`-ing
    `inspect(#{__MODULE__})`
    """
  end

  @doc false
  @spec soft_delete_field!(field :: atom() | nil) :: atom()
  # Handlers for configuring the `field` option when `use`-ing `EctoModel.SoftDelete`
  def soft_delete_field!(nil), do: :deleted_at
  def soft_delete_field!(field) when is_atom(field), do: field

  @doc false
  @spec soft_delete_type!(type :: atom()) :: soft_delete_type() | no_return()
  # Handlers for configuring the `type` option when `use`-ing `EctoModel.SoftDelete`
  def soft_delete_type!(nil), do: :utc_datetime
  def soft_delete_type!(type) when type in @supported_types, do: type

  def soft_delete_type!(type),
    do: raise(ArgumentError, message: "Unsupported soft delete type: #{inspect(type)}")

  @doc """
  Given a schema that has been configured to implement soft deletes, this function will apply the neccessary
  filters to the query to ensure that soft deleted records are not included in the result set.

  Note that the strategy used for soft deletes is determined by the `type` option when `use`-ing `EctoModel.SoftDelete`,
  and we will apply the appropriate filter against the `field` option when `use`-ing `EctoModel.SoftDelete`.

  For example, if a schema is configured to implement soft deletes like so:

  ```elixir
  defmodule MyApp.User do
    use Ecto.Schema
    use EctoModel.SoftDelete, field: :deleted_at, type: :utc_datetime

    schema "users" do
      field(:name, :string)
      field(:email, :string)
      field(:deleted_at, :utc_datetime)
    end
  end
  ```

  Then the `apply_filter!/2` function will apply the following filter to the query:

  ```elixir
  from(x in query, where: is_nil(x.deleted_at))
  ```

  However, if the schema is configured to implement soft deletes like so:

  ```elixir
  defmodule MyApp.User do
    use Ecto.Schema
    use EctoModel.SoftDelete, field: :deleted, type: :boolean

    schema "users" do
      field(:name, :string)
      field(:email, :string)
      field(:deleted, :boolean)
    end
  end
  ```

  Then the `apply_filter!/2` function will apply the following filter to the query:

  ```elixir
  from(x in query, where: is_nil(x.deleted) or x.deleted == false)
  ```
  """
  @spec apply_filter!(schema :: module(), query :: Ecto.Query.t() | atom()) :: Ecto.Query.t()
  def apply_filter!(schema, query) when is_atom(schema) do
    import Ecto.Query

    # This clause is only ever going to be reached if someone does something naughty!
    # coveralls-ignore-start
    unless function_exported?(schema, :soft_delete_config, 0) do
      raise ArgumentError,
        message: "The `#{inspect(schema)}` schema is not configured to implement soft deletes."
    end

    # coveralls-ignore-stop

    case schema.soft_delete_config() do
      %Config{type: :boolean} = config ->
        from(x in query,
          where: is_nil(field(x, ^config.field)) or field(x, ^config.field) == false
        )

      %Config{type: _datetime} = config ->
        from(x in query, where: is_nil(field(x, ^config.field)))
    end
  end

  @behaviour EctoMiddleware
  @impl EctoMiddleware
  def middleware(resource, resolution) when resolution.action not in @delete_callbacks do
    resource
  end

  # TODO: this fallback clause will never be reached until `EctoMiddleware` supports `delete_all/2`
  # coveralls-ignore-start
  def middleware(%Ecto.Query{} = queryable, resolution) do
    schema =
      case queryable.from.source do
        {_table, schema} when is_atom(schema) ->
          schema

        _otherwise ->
          nil
      end

    :ok = maybe_validate_repo_action!(schema, resolution.action)

    queryable
  end

  # coveralls-ignore-stop

  def middleware(%schema{} = resource, resolution)
      when resolution.action in [:delete, :delete!, :delete_all] do
    :ok = maybe_validate_repo_action!(schema, resolution.action)
    resource
  end

  # TODO: this clause will never be reached until `EctoMiddleware` supports `delete_all/2`
  # coveralls-ignore-start
  def middleware(schema, resolution) when is_atom(schema) and resolution.action == :delete_all do
    :ok = maybe_validate_repo_action!(schema, resolution.action)
    schema
  end

  def middleware(resource, _resolution) do
    resource
  end

  # coveralls-ignore-stop

  defp maybe_validate_repo_action!(schema, action)
       when is_atom(schema) and action in [:delete, :delete!, :delete_all] do
    if function_exported?(schema, :soft_delete_config, 0) && schema.soft_delete_config() do
      raise ArgumentError,
        message: """
        You are trying to delete a schema that uses soft deletes. Please use `Repo.soft_delete/2` instead.
        """
    end

    :ok
  end

  @doc " See `Ecto.Repo.soft_delete/2` for more information."
  @spec soft_delete!(resource :: struct(), opts :: Keyword.t()) :: struct() | no_return()
  def soft_delete!(resource, opts \\ []) do
    {:ok, resource} = soft_delete(resource, opts)
    resource
  end

  @doc """
  Will soft delete a given resource, and persist the changes to the database, based on that resource's configured
  soft delete field and type.

  Will raise if given an entity that does not opt into soft deletes.

  # TODO: we will need to implement something more fully fledged to support `delete_all/2` and the like
  """
  @spec soft_delete!(resource :: struct(), opts :: Keyword.t()) ::
          {:ok, struct()} | {:error, term()}
  def soft_delete(%schema{} = resource, opts \\ []) do
    # coveralls-ignore-start
    unless opts[:repo] do
      raise ArgumentError,
        message: "You must provide a `:repo` option when delegating to, or using `soft_delete/2`"
    end

    # coveralls-ignore-stop

    unless function_exported?(schema, :soft_delete_config, 0) do
      raise ArgumentError,
        message:
          "The `#{inspect(schema)}` schema is not configured to implement soft deletes, please use `Repo.delete/2` instead."
    end

    case schema.soft_delete_config() do
      %Config{type: :boolean} = config ->
        resource
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_change(config.field, true)
        |> opts[:repo].update(opts)

      %Config{type: type} = config when type in [:utc_datetime, :datetime] ->
        now = DateTime.truncate(DateTime.utc_now(), :second)

        resource
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_change(config.field, now)
        |> opts[:repo].update(opts)
    end
  end
end
