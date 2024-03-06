# EctoModel

EctoModel is a library that aims to overhaul your `Ecto.Schema`s with additional functionality such as easy, fluent querying of data as well as easy soft deletes!

## Installation

This package can be installed by adding `ecto_model` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_model, "~> 0.0.1"}
  ]
end
```

## Features

Currently, EctoModel provides the following features:

- Easy and fluent API for querying your data with `EctoModel.Queryable`
- Easy and compile-time validated soft delete functionality with `EctoModel.SoftDelete`

All of the provided functionality is provided in an opt-in basis, so you can mix and match the functionality
you need as needed.

Please see the documentation for each feature for more information.

## License

EctoModel is released under the MIT License.

## Links

EctoModel is built on top of the following libraries, and as such, you may care about their documentation as well:

- [Ecto](https://hexdocs.pm/ecto/Ecto.html)
- [EctoMiddleware](https://hexdocs.pm/ecto_middleware/EctoMiddleware.html)
- [EctoHooks](https://hexdocs.pm/ecto_hooks/EctoHooks.html)

## Contributing

We don't currently have any contributing guidelines, but if you'd like to contribute, please feel free to open an issue or a pull request.

Please note that we do enforce 100% test coverage, so any changes will need to be accompanied by tests.

Additionally, we withhold the right to refuse any changes that we feel do not align with the goals of the project.
