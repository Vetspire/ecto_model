defmodule EctoModel.Factory do
  use ExMachina.Ecto, repo: EctoModel.Repo

  def dog_factory do
    %EctoModel.Dog{
      breed: "Golden Retriever",
      name: "Buddy",
      date_of_birth: ~D[2015-01-01],
      notes: "Friendly and loyal",
      owner: build(:owner),
      deleted_at: nil
    }
  end

  def vaccination_factory do
    %EctoModel.Vaccination{
      name: "Rabies",
      date: ~D[2022-12-21],
      dog: build(:dog),
      deleted: false
    }
  end

  def owner_factory do
    %EctoModel.Owner{
      name: "John Smith",
      email: "john@smith.cc",
      phone: "123-456-7890"
    }
  end
end
