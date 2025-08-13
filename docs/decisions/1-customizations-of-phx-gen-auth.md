# Customizations of phx.gen.auth 

## Problem Statement

This app, like most, needs an experience for users to register accounts and authenticate. For security and to align with the community, I built on top of the community standard `phx.gen.auth` code generation tool. However, I decided to customize a few paths; this document documents what and why.

## Change: No Magic Link for registration or authentication

The out-of-the-box experience for `phx.gen.auth` is to have users exclusively register by providing their email address[^1]. Then, when the user clicks an emailed link, they confirm their identity (stored in the `User` schema) and sign in to the website.

[^1]: You can see an example of this via this blog post: <https://mikezornek.com/posts/2025/5/phoenix-magic-link-authentication/>.

I feel like magic links are a hindrance to security-minded people who are utilizing password managers. Creating an email/password pair and using those credentials to register is more convenient for these users.

The negative tradeoff is that less security-aware users may be tempted to reuse passwords. In the long term, we might mitigate that worry through required 2FA or Passkeys (which still align with those who use password managers).

## Change: Email (identity) confirmation is delayed

By removing Magic Link registration, we no longer immediately confirm the email address (user identity), which feels like a security concern. The app should consider blocking sensitive future features until the email address is confirmed.

We accept this tradeoff for now[^2], as we want people to get into the application and look around as quickly as possible.

[^2]: I made an issue to track this here: <https://github.com/zorn/wayfinder/issues/10>.

## Change: Registration form is a Controller over LiveView

While the documented (see [Command Line History](command-line-history.html#july-21-2025)) code generator preferred LiveView for pages, we converted the Registration page to a standard Phoenix Controller, allowing us to log the user in more quickly (as a LiveView can not update the session directly).

## Change: Renamed `register_user/1` to `create_user/1`.

The default code generator names a function `register_user/1` ([sample](https://github.com/zorn/magic-link-demo/blob/1de3ac787dc7e98721a2e3df468e454a3275d74b/lib/hello/accounts.ex#L77)). While I usually am ok with domain context using business verbs, I thought a more streamlined `create` felt better next to the various `update` counterparts here. When registration was an emailed link, that verb made more sense.

## Change: Renamed  `sudo_mode?/1` to `recently_authenticated?/1`

I think this new name is more express of intent.

***

Other code cleanup including: added typespecs, updated docs, and relocated changeset functions (opting to keep as much in the main `Wayfinder.Accounts` as possible).
