defmodule EctoModel.QueryableTest do
  use ExUnit.Case, async: true
  import EctoModel.Factory

  alias EctoModel.Dog
  alias EctoModel.Owner
  alias EctoModel.Queryable
  alias EctoModel.Repo

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoModel.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(EctoModel.Repo, {:shared, self()})
    end

    :ok
  end

  describe "__using__/1" do
    test "adds `base_query/0` to the schema module" do
      assert %Ecto.Query{} = query = Owner.base_query()
      assert query.aliases == %{self: 0}
      assert query.from.source == {"owners", Owner}
    end

    test "adds `query/2` to the schema module" do
      insert(:dog,
        name: "Buddy",
        breed: "Golden Retriever",
        date_of_birth: ~D[2015-01-01],
        deleted_at: nil
      )

      assert [] = Repo.all(Dog.query(name: "does not exist"))
      assert [%Dog{} = dog] = Repo.all(Dog.query(name: "Buddy"))
      assert [^dog] = Repo.all(Dog.query(breed: "Golden Retriever"))
      assert [] = Repo.all(Dog.query(date_of_birth: {:>=, Date.utc_today()}))

      refute is_nil(dog.owner_id)
      assert is_struct(dog.owner, Ecto.Association.NotLoaded)

      assert [%Dog{owner: %Owner{} = owner}] = Repo.all(Dog.query(preload: :owner))
      assert [] = Repo.all(Owner.query(name: "Spongebob"))
      assert [^owner] = Repo.all(Owner.query(id: owner.id))

      assert is_struct(owner.dogs, Ecto.Association.NotLoaded)

      assert [%Owner{dogs: [%Dog{}]}] = Repo.all(Owner.query(preload: :dogs))
    end
  end

  describe "implemented_by?/1" do
    test "returns false when given model does not `use EctoModel.Queryable`" do
      refute Queryable.implemented_by?(Enum)
    end

    test "returns true when given model `use EctoModel.Queryable`" do
      for schema <- [Owner, Dog], do: assert(Queryable.implemented_by?(schema))
    end
  end

  describe "apply_filter/2" do
    setup do
      {:ok, query: Dog}
    end

    test "is able to change the schema prefix", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:prefix, "test"})
      assert query.from.prefix == "test"
    end

    test "is able to preload singular associations", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:preload, :owner})
      assert query.preloads == [:owner]
    end

    test "is able to preload a list of associations", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:preload, [:owner]})
      assert query.preloads == [:owner]
    end

    test "is able to add limit to the query", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:limit, 10})
      assert match?(%Ecto.Query.LimitExpr{params: [{10, :integer}]}, query.limit)
    end

    test "is able to add offset to the query", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:offset, 10})
      assert match?(%Ecto.Query.QueryExpr{params: [{10, :integer}]}, query.offset)
    end

    test "is able to order the query (literal)", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:order_by, :name})

      assert match?(
               %Ecto.Query.QueryExpr{expr: [desc: {{_, _, [_, :name]}, _, _}]},
               hd(query.order_bys)
             )
    end

    test "is able to order the query (list asc)", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:order_by, [asc: :name]})

      assert match?(
               %Ecto.Query.QueryExpr{expr: [asc: {{_, _, [_, :name]}, _, _}]},
               hd(query.order_bys)
             )
    end

    test "is able to order the query (list desc)", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:order_by, [desc: :name]})

      assert match?(
               %Ecto.Query.QueryExpr{expr: [desc: {{_, _, [_, :name]}, _, _}]},
               hd(query.order_bys)
             )
    end

    test "is able to order the query (tuple asc)", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert %Ecto.Query{} = query = Queryable.apply_filter(ctx.query, {:order_by, {:asc, :name}})

      assert match?(
               %Ecto.Query.QueryExpr{expr: [asc: {{_, _, [_, :name]}, _, _}]},
               hd(query.order_bys)
             )
    end

    test "is able to order the query (tuple desc)", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert %Ecto.Query{} =
               query = Queryable.apply_filter(ctx.query, {:order_by, {:desc, :name}})

      assert match?(
               %Ecto.Query.QueryExpr{expr: [desc: {{_, _, [_, :name]}, _, _}]},
               hd(query.order_bys)
             )
    end

    test "is able to filter on `inserted_at_start`", ctx do
      datetime = ~U[2022-01-01 00:00:00Z]
      refute is_struct(ctx.query, Ecto.Query)

      assert %Ecto.Query{} =
               query =
               Queryable.apply_filter(ctx.query, {:inserted_at_start, datetime})

      assert match?(
               %Ecto.Query.BooleanExpr{
                 expr: {:>=, _, [{{:., _, [_, :inserted_at]}, _, _}, {:^, _, [0]}]},
                 params: [{^datetime, {0, :inserted_at}}],
                 op: :and
               },
               hd(query.wheres)
             )
    end

    test "is able to filter on `inserted_at_end`", ctx do
      datetime = ~U[2022-01-01 00:00:00Z]
      refute is_struct(ctx.query, Ecto.Query)

      assert %Ecto.Query{} =
               query =
               Queryable.apply_filter(ctx.query, {:inserted_at_end, datetime})

      assert match?(
               %Ecto.Query.BooleanExpr{
                 expr: {:<=, _, [{{:., _, [_, :inserted_at]}, _, _}, {:^, _, [0]}]},
                 params: [{^datetime, {0, :inserted_at}}],
                 op: :and
               },
               hd(query.wheres)
             )
    end

    test "is able to filter on `updated_at_start`", ctx do
      datetime = ~U[2022-01-01 00:00:00Z]
      refute is_struct(ctx.query, Ecto.Query)

      assert %Ecto.Query{} =
               query =
               Queryable.apply_filter(ctx.query, {:updated_at_start, datetime})

      assert match?(
               %Ecto.Query.BooleanExpr{
                 expr: {:>=, _, [{{:., _, [_, :updated_at]}, _, _}, {:^, _, [0]}]},
                 params: [{^datetime, {0, :updated_at}}],
                 op: :and
               },
               hd(query.wheres)
             )
    end

    test "is able to filter on `updated_at_end`", ctx do
      datetime = ~U[2022-01-01 00:00:00Z]
      refute is_struct(ctx.query, Ecto.Query)

      assert %Ecto.Query{} =
               query =
               Queryable.apply_filter(ctx.query, {:updated_at_end, datetime})

      assert match?(
               %Ecto.Query.BooleanExpr{
                 expr: {:<=, _, [{{:., _, [_, :updated_at]}, _, _}, {:^, _, [0]}]},
                 params: [{^datetime, {0, :updated_at}}],
                 op: :and
               },
               hd(query.wheres)
             )
    end

    test "is able to filter by regex (case-sensitive)", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:name, ~r/buddy/})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"name\" ~ $1)"
      assert Enum.at(params, 0) == "buddy"
    end

    test "is able to filter by regex (case-insensitive)", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:name, ~r/riley/i})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"name\" ~* $1)"
      assert Enum.at(params, 0) == "riley"
    end

    test "is able to filter for non-inclusion of a list of values", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:name, {:not, ["Cindy", "Judy"]}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (NOT (d0.\"name\" = ANY($1)))"
      assert Enum.at(params, 0) == ["Cindy", "Judy"]
    end

    test "is able to filter for inclusion of a list of values", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:name, ["Buddy", "Riley"]})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"name\" = ANY($1))"
      assert Enum.at(params, 0) == ["Buddy", "Riley"]
    end

    test "is able to filter for non-null values", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, []} =
               ctx.query
               |> Queryable.apply_filter({:name, {:not, nil}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (NOT (d0.\"name\" IS NULL))"
    end

    test "is able to filter for null values", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, []} =
               ctx.query
               |> Queryable.apply_filter({:name, nil})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"name\" IS NULL)"
    end

    test "is able to filter for inequality", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:name, {:not, "Bob"}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"name\" != $1)"
      assert Enum.at(params, 0) == "Bob"
    end

    test "is able to filter for equality", ctx do
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:name, "Bob"})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"name\" = $1)"
      assert Enum.at(params, 0) == "Bob"
    end

    test "is able to filter for values greater than (`:gt`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:gt, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" > $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values greater than (`:>`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:>, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" > $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values greater than or equal to (`:gte`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:gte, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" >= $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values greater than or equal to (`:>=`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:>=, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" >= $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values less than (`:lt`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:lt, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" < $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values less than (`:<`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:<, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" < $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values less than or equal to (`:lte`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:lte, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" <= $1)"
      assert Enum.at(params, 0) == now
    end

    test "is able to filter for values less than or equal to (`:<=`)", ctx do
      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      refute is_struct(ctx.query, Ecto.Query)

      assert {query, params} =
               ctx.query
               |> Queryable.apply_filter({:inserted_at, {:<=, now}})
               |> then(&Repo.to_sql(:all, &1))

      assert query =~ "WHERE (d0.\"inserted_at\" <= $1)"
      assert Enum.at(params, 0) == now
    end

    test "does nothing with unsupported filters", ctx do
      refute is_struct(ctx.query, Ecto.Query)
      assert ctx.query == Queryable.apply_filter(ctx.query, :unsupported)
    end
  end
end
