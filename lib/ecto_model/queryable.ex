defmodule EctoModel.Queryable do
  @moduledoc """
  A behaviour for defining a `query/2` callback that can be used as an easy-to-use and fluent DSL for building
  Ecto queries in a consistent manner across different schemas.

  ## Usage

  1. Define a schema module and use the `EctoModel.Queryable` behaviour. By default, this is all you have to do
     unless you wish to customize the behaviour further.

     ```elixir
     defmodule MyApp.User do
       use Ecto.Schema
       use EctoModel.Queryable

       schema "users" do
         field(:name, :string)
         field(:email, :string)
         field(:inserted_at, :utc_datetime)
         field(:updated_at, :utc_datetime)
       end
     end

     (iex)> MyApp.Repo.exists?(MyApp.User.query(name: "John", email: nil))
     true
     (iex)> MyApp.Repo.exists?(MyApp.User.query(email: nil, inserted_at: {:>=, ~U[2021-01-01 00:00:00Z]}))
     false
     ```

  2. Implement the `base_query/0` optional callback if you want all queries, by default, to inherit a standard set
     of filters. This is useful for implementing soft deletes, for example.

     ```elixir
     def base_query, do: from(x in __MODULE__, where: is_nil(x.deleted_at))
     ```

  3. Implement the `query/2` callback to apply filters to the query. This is where you can extend the default supported
     filters or add custom filters that are specific to your schema.

     When you use the `EctoModel.Queryable` behaviour, you get a default implementation of the `query/2` callback that
     looks like the following:

     ```elixir
     def query(base_query \\ base_query(), filters) do
       Enum.reduce(filters, base_query, &apply_filter(&2, &1))
     end
     ```

     If you want to add new logic while still inheriting the default behaviour, you can do so by ensuring a clause exists
     within your `Enum.reduce/3` implementation that matches against any pattern and delegates to the default behaviour
     provided by `EctoModel.Queryable.apply_filter/2`.

  ## Supported Filters

  By default, all non-embedded fields should be supported by the default `apply_filter/2` implementation for the following
  operators:

  - Equality (`==`) via `field: value`
  - Inclusion (`in`) via `field: [value1, value2]`
  - Exclusion (`not in`) via `field: {:not, [value1, value2]}`
  - Greater than (`>`) via `field: {:gt, value} or field: {:>, value}`
  - Greater than or equal to (`>=`) via `field: {:gte, value} or field: {:>=, value}`
  - Less than (`<`) via `field: {:lt, value} or field: {:<, value}`
  - Less than or equal to (`<=`) via `field: {:lte, value} or field: {:<=, value}`
  - Is null (`nil`) via `field: nil`
  - Is not null (`not nil`) via `field: {:not, nil}`
  - Like (`like %value&`) via `field: ~r/value/`
  - Case insensitive Like (`ilike %value&`) via `field: ~r/value/i`

  Additionally, while not filters in the traditional sense, the following options are also supported:

  - Preloading (`preload`) via `preload: :association or preload: [:association1, :association2]`
  - Limiting (`limit`) via `limit: 10`
  - Offsetting (`offset`) via `offset: 10`
  - Ordering (`order_by`) via `order_by: :field or order_by: {:desc, :field} or order_by: [:field1, :field2]`
  """

  import Ecto.Query

  defmacro __using__(_opts) do
    quote do
      import Ecto.Query

      import unquote(__MODULE__)
      require unquote(__MODULE__)

      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def base_query, do: from(x in __MODULE__, as: :self)

      @impl unquote(__MODULE__)
      def query(base_query \\ base_query(), filters) do
        Enum.reduce(filters, base_query, &apply_filter(&2, &1))
      end

      defoverridable(base_query: 0, query: 1, query: 2)
    end
  end

  @callback query(Ecto.Queryable.t(), Keyword.t()) :: Ecto.Queryable.t()
  @callback base_query() :: Ecto.Queryable.t()
  @optional_callbacks base_query: 0, query: 2

  @doc "Returns true a given module implements the `Queryable` behaviour"
  @spec implemented_by?(module()) :: boolean()
  def implemented_by?(module) when is_atom(module) do
    behaviours =
      :attributes
      |> module.module_info()
      |> Enum.filter(&match?({:behaviour, _behaviours}, &1))
      |> Enum.map(&elem(&1, 1))
      |> List.flatten()

    __MODULE__ in behaviours
  end

  @doc "List of default filters that can be used in a schema's `query/2` callback"
  @spec apply_filter(Ecto.Queryable.t(), {field :: atom(), value :: term()}) :: Ecto.Queryable.t()
  def apply_filter(query, {:prefix, value}) do
    from(x in query, prefix: ^value)
  end

  def apply_filter(query, {:preload, value}) do
    from(x in query, preload: ^value)
  end

  def apply_filter(query, {:limit, value}) do
    from(x in query, limit: ^value)
  end

  def apply_filter(query, {:offset, value}) do
    from(x in query, offset: ^value)
  end

  def apply_filter(query, {:order_by, value}) when is_list(value) do
    from(x in query, order_by: ^value)
  end

  def apply_filter(query, {:order_by, {direction, value}}) do
    from(x in query, order_by: [{^direction, ^value}])
  end

  def apply_filter(query, {:order_by, value}) do
    from(x in query, order_by: [{:desc, ^value}])
  end

  def apply_filter(query, {:inserted_at_start, inserted_at}) when is_struct(inserted_at) do
    from(x in query, where: x.inserted_at >= ^inserted_at)
  end

  def apply_filter(query, {:inserted_at_end, inserted_at}) when is_struct(inserted_at) do
    from(x in query, where: x.inserted_at <= ^inserted_at)
  end

  def apply_filter(query, {:updated_at_start, updated_at}) when is_struct(updated_at) do
    from(x in query, where: x.updated_at >= ^updated_at)
  end

  def apply_filter(query, {:updated_at_end, updated_at}) when is_struct(updated_at) do
    from(x in query, where: x.updated_at <= ^updated_at)
  end

  def apply_filter(query, {field, %Regex{} = regex}) do
    if String.contains?(regex.opts, "i") do
      from(x in query, where: fragment("? ~* ?", field(x, ^field), ^regex.source))
    else
      from(x in query, where: fragment("? ~ ?", field(x, ^field), ^regex.source))
    end
  end

  def apply_filter(query, {field, {:not, value}}) when is_list(value) do
    from(x in query, where: field(x, ^field) not in ^value)
  end

  def apply_filter(query, {field, value}) when is_list(value) do
    from(x in query, where: field(x, ^field) in ^value)
  end

  def apply_filter(query, {field, {:not, nil}}) do
    from(x in query, where: not is_nil(field(x, ^field)))
  end

  def apply_filter(query, {field, nil}) do
    from(x in query, where: is_nil(field(x, ^field)))
  end

  def apply_filter(query, {field, {:not, value}}) do
    from(x in query, where: field(x, ^field) != ^value)
  end

  def apply_filter(query, {field, {gt, value}}) when gt in [:gt, :>] do
    from(x in query, where: field(x, ^field) > ^value)
  end

  def apply_filter(query, {field, {gte, value}}) when gte in [:gte, :>=] do
    from(x in query, where: field(x, ^field) >= ^value)
  end

  def apply_filter(query, {field, {lt, value}}) when lt in [:lt, :<] do
    from(x in query, where: field(x, ^field) < ^value)
  end

  def apply_filter(query, {field, {lte, value}}) when lte in [:lte, :<=] do
    from(x in query, where: field(x, ^field) <= ^value)
  end

  def apply_filter(query, {field, value}) do
    from(x in query, where: field(x, ^field) == ^value)
  end

  def apply_filter(query, _unsupported) do
    query
  end
end
