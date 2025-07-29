# A Review of the Alterations Made from the `phx.gen.auth` Output

## Problem Statement

This app, like many, needs an experience for users to register accounts and authenticate. For security and to align with the community, we build on top of the community standard `phx.gen.auth`. We did, however, decide to customize a few paths. This document serves to document what and why.

## Change: No Magic Link for Registration or Authentication

The out-of-the-box experience for `phx.gen.auth` is to have users exclusively register by providing their email address only[^1]. Then, when the user clicks the emailed link, they confirm their identity (stored in the `User` schema) and sign in to the website.

[^1]: You can see an example of this via this blog post: <https://mikezornek.com/posts/2025/5/phoenix-magic-link-authentication/>.

I feel like magic links are a hindrance to security-minded people who are utilizing password managers. For these users, creating an email/password pair and using those credentials to register is more convenient.

The negative tradeoff is that less security-aware users may be tempted to reuse passwords. In the long term, we might mitigate this through required 2FA or Passkeys (which still align with those who use password managers).

## Change: Email (identity) confirmation is delayed

By removing Magic Link registration, we no longer immediately confirm the email address (user identity), which feels like a security concern. The app should consider blocking sensitive future features until the email address is confirmed.

We accept this tradeoff, as we want people to get into the system and look around quickly, and will reconsider in the future[^2] as needed.

[^2]: I made an issue to track this concern here: <https://github.com/zorn/wayfinder/issues/10>.

## Change: Registration Form is a Controller over LiveView

While the documented (see Command Line History) generator preferred LiveView for the related pages, we converted the Registration page to a standard controller, allowing us to log the user in more quickly.

## Change: Renamed `register_user/1` to `create_user/1`.
