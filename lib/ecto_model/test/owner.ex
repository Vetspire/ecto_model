# coveralls-ignore-start
if Mix.env() == :test do
  defmodule EctoModel.Owner do
    use Ecto.Schema
    use EctoModel.Queryable
    import Ecto.Changeset

    schema "owners" do
      field(:name, :string)
      field(:email, :string)
      field(:phone, :string)
      has_many(:dogs, EctoModel.Dog)
    end

    def changeset(owner, attrs) do
      owner
      |> cast(attrs, [:name, :email, :phone])
      |> validate_required([:name, :email, :phone])
    end
  end
end
