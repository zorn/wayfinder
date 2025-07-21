# Command Line History

## July 21, 2025

<https://hexdocs.pm/phoenix/mix_phx_gen_auth.html>

We prefer `argon2` for our hashing.

```bash
mix phx.gen.auth Accounts User users --binary-id --hashing-lib argon2
```

## July 20, 2025

Doing a update of the project from Phoenix `v1.8.0-rc.3` to `v1.8.0-rc.4`.

Leaning on diffs from the following to guide me:

<https://www.phoenixdiff.org/compare/1.8.0-rc.3%20--binary-id...1.8.0-rc.4%20--binary-id>|

I also generated a local new `wayfinder` project using the `rc.4` `phx_new` so I could copy wholesale some the vendor DaisyUI files.

## July 13, 2025

The project was created with a pre-release version of the Phoenix project template. To install that we used:

```bash
mix archive.install hex phx_new 1.8.0-rc.3
```

When creating the project we wanted UUID-based id values and utilized the `--binary-id` [option](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html#module-options).

```bash
mix phx.new --binary-id wayfinder
```
