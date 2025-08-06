# Naming and Writing Tips

This guide includes some project specific documentation preferences.

See also, the [community recommendations](https://hexdocs.pm/elixir/writing-documentation.html#recommendations) for documentation.

## To Be Documented

- What modules should get a `@moduledoc` and which should not? (generally an Elixir library only documents modules it want's it's users to see and will use `@moduledoc false` for [implementation modules](https://github.com/elixir-ecto/ecto/blob/cd0f70b4cdd949767ea7cbe7d635e70917384b38/lib/ecto/repo/transaction.ex#L2).)
- I'm using `Attempts to...` for my `register_user/1` function but I'm not sure I like that style.
- When it comes to documentation examples, avoid writing out examples if the sole purpose if to visualize the return value types. Let the typespec do that. Examples that can be `doctest`-ed are best. If you want an example to otherwise provide a copy/pastable starting point for a complex syntax, that is fine too. 

## `@moduledoc`

Do not document every Elixir Module. Only document those modules that represent the intentional API boundary of the system. These include modules like 

<https://hexdocs.pm/elixir/writing-documentation.html#module-attributes>

## `@doc`
