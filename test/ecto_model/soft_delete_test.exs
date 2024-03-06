defmodule EctoModel.SoftDeleteTest do
  use ExUnit.Case, async: true

  import EctoModel.Factory

  alias EctoModel.Dog
  alias EctoModel.Owner
  alias EctoModel.Vaccination
  alias EctoModel.Repo

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoModel.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(EctoModel.Repo, {:shared, self()})
    end

    :ok
  end

  setup do
    vaccination =
      insert(:vaccination,
        name: "Rabies",
        date: ~D[2022-12-21],
        dog:
          insert(:dog,
            breed: "Golden Retriever",
            name: "Buddy",
            date_of_birth: ~D[2019-12-21],
            owner: insert(:owner, name: "John Doe")
          )
      )

    {:ok, vaccination: vaccination, dog: vaccination.dog, owner: vaccination.dog.owner}
  end

  describe "__after_compile__/2" do
    test "throws an exception if the schema has `field` misconfigured" do
      assert_raise ArgumentError, ~r/this field does not exist/, fn ->
        Code.eval_string("""
        defmodule Test.SchemaOne do
          use Ecto.Schema
          use EctoModel.Queryable
          use EctoModel.SoftDelete, field: :deleted, type: :boolean

          schema "schema_ones" do
            field(:deleted_at, :string)
          end
        end
        """)
      end
    end

    test "throws an exception if the schema has `type` misconfigured (schema)" do
      assert_raise ArgumentError, ~r/this field has the wrong type/, fn ->
        Code.eval_string("""
        defmodule Test.SchemaTwo do
          use Ecto.Schema
          use EctoModel.Queryable
          use EctoModel.SoftDelete, field: :deleted, type: :boolean

          schema "schema_twos" do
            field(:deleted, :string)
          end
        end
        """)
      end
    end

    test "throws an exception if the schema has `type` misconfigured (config)" do
      assert_raise ArgumentError, ~r/Unsupported soft delete type/, fn ->
        Code.eval_string("""
        defmodule Test.SchemaThree do
          use Ecto.Schema
          use EctoModel.Queryable
          use EctoModel.SoftDelete, field: :deleted, type: :string

          schema "schema_twos" do
            field(:deleted, :boolean)
          end
        end
        """)
      end
    end

    test "assumes `field` is `deleted_at` and `type` is `utc_datetime` when not explicitly set" do
      assert {{:module, Test.SchemaFour, _binary, _bindings}, []} =
               Code.eval_string("""
               defmodule Test.SchemaFour do
                 use Ecto.Schema
                 use EctoModel.Queryable
                 use EctoModel.SoftDelete

                 schema "schema_twos" do
                   field(:deleted_at, :utc_datetime)
                 end
               end
               """)
    end

    test "does nothing if a schema is configured correctly" do
      assert {{:module, Test.SchemaFive, _binary, _bindings}, []} =
               Code.eval_string("""
               defmodule Test.SchemaFive do
                 use Ecto.Schema
                 use EctoModel.Queryable
                 use EctoModel.SoftDelete, field: :deleted, type: :boolean

                 schema "schema_twos" do
                   field(:deleted, :boolean)
                 end
               end
               """)
    end
  end

  describe "__using__/1" do
    test "if schema also implements `EctoModel.Queryable`, adjusts `base_query/0` to exclude `:deleted` records" do
      # This schema uses `EctoModel.Queryable` and `EctoModel.SoftDelete`
      assert Dog.base_query() |> then(&Repo.to_sql(:all, &1)) |> elem(0) =~
               "WHERE (d0.\"deleted_at\" IS NULL)"

      # This schema uses `EctoModel.Queryable` and `EctoModel.SoftDelete`, but is a boolean field
      assert Vaccination.base_query() |> then(&Repo.to_sql(:all, &1)) |> elem(0) =~
               "WHERE ((v0.\"deleted\" IS NULL) OR (v0.\"deleted\" = FALSE)"

      # This schema only uses `EctoModel.Queryable`
      refute Owner.base_query() |> then(&Repo.to_sql(:all, &1)) |> elem(0) =~
               "WHERE (d0.\"deleted_at\" IS NULL)"
    end
  end

  describe "middleware/2" do
    import Ecto.Query

    test "raises if you try hard deleting a struct that opts into soft deletes", ctx do
      for struct <- [ctx.dog, ctx.vaccination] do
        assert_raise ArgumentError,
                     ~r/You are trying to delete a schema that uses soft deletes. Please use `Repo.soft_delete\/2` instead/,
                     fn -> Repo.delete(struct) end
      end

      # This is allowed because this schema does not use `EctoModel.SoftDelete`
      assert {:ok, _owner} = Repo.delete(ctx.owner)
    end

    test "raises if you try hard deleting a query that opts whose source opts into soft deletes",
         ctx do
      for %schema{} <- [ctx.dog, ctx.vaccination] do
        assert_raise ArgumentError,
                     ~r/You are trying to delete a schema that uses soft deletes. Please use `Repo.soft_delete\/2` instead/,
                     fn -> Repo.delete(from(x in schema)) end
      end
    end
  end

  describe "soft_delete!/2" do
    test "soft deletes a struct that opts into soft deletes (timestamp)", ctx do
      assert Repo.exists?(Dog.query([]))
      assert is_nil(ctx.dog.deleted_at)

      assert %Dog{} = dog = Repo.soft_delete!(ctx.dog)

      assert is_struct(dog.deleted_at)
      refute Repo.exists?(Dog.query([]))
    end

    test "soft deletes a struct that opts into soft deletes (boolean)", ctx do
      assert Repo.exists?(Vaccination.query([]))
      assert ctx.vaccination.deleted == false

      assert %Vaccination{} = vaccination = Repo.soft_delete!(ctx.vaccination)

      assert vaccination.deleted == true
      refute Repo.exists?(Vaccination.query([]))
    end

    test "raises if given a module that does not opt into soft deletes", ctx do
      assert_raise ArgumentError, ~r/not configured to implement soft deletes/, fn ->
        Repo.soft_delete!(ctx.owner)
      end
    end
  end

  describe "soft_delete/2" do
    test "soft deletes a struct that opts into soft deletes (timestamp)", ctx do
      assert Repo.exists?(Dog.query([]))
      assert is_nil(ctx.dog.deleted_at)

      assert {:ok, %Dog{} = dog} = Repo.soft_delete(ctx.dog)

      assert is_struct(dog.deleted_at)
      refute Repo.exists?(Dog.query([]))
    end

    test "soft deletes a struct that opts into soft deletes (boolean)", ctx do
      assert Repo.exists?(Vaccination.query([]))
      assert ctx.vaccination.deleted == false

      assert {:ok, %Vaccination{} = vaccination} = Repo.soft_delete(ctx.vaccination)

      assert vaccination.deleted == true
      refute Repo.exists?(Vaccination.query([]))
    end

    test "raises if given a module that does not opt into soft deletes", ctx do
      assert_raise ArgumentError, ~r/not configured to implement soft deletes/, fn ->
        Repo.soft_delete(ctx.owner)
      end
    end
  end
end
