# Formal Attributes

## Problem Statement

Many Phoenix applications have a pattern where a changeset function is defined at the schema level, and web interface call sites tend to call these functions directly or indirectly via `create_noun/1` or `update_noun/2` functions of a domain context.

The problem with this approach is that it encourages a typespec of `map()` for those context functions because there is no formal shape to the attribute value --  a changeset function inherently expects a string-keyed map value.

I am interested in having stricter types for these values.

## Solution

I have built `t:Wayfinder.Accounts.create_user_attrs/0` and `t:Wayfinder.Accounts.update_user_email_attrs/0` types for creation and mutation functions. These are expressive about the expected function argument value, and that value should be an atom-keyed map value. To help web interface call sites create these `Wayfinder.Accounts.cast_create_user_attrs/1` and `Wayfinder.Accounts.cast_update_user_email_attrs/1` functions are available.

It is up for debate how this will feel in the long run, but I have wanted to have better-shaped types for these kinds of functions for a while, and this is a test of sorts to see how I like it.
