# Documentation Guidelines

The recommendations and reasoning for how we compose documentation for the project.

> #### Info {: .info}
>
> See also the [community recommendations](https://hexdocs.pm/elixir/writing-documentation.html#recommendations) for documentation that should be the preferred default unless noted below.

## Inline Function Documentation Examples

The standard Phoenix generators tend to generate verbose inline examples inside the `@doc` blocks that are not runnable via `doctest` and don't offer much value over the already required typespecs.

When an example adds clarity over the typespec, do consider adding it. If the example can run using `doctest`, that is even better.
