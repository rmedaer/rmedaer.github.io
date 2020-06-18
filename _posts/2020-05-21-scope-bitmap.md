---
layout:     post
title:      JWT scope claim compression using a bitmap
date:       2020-05-21 21:22:12 +0200
categories: oauth
---

[JSON Web Tokens (JWT)](https://tools.ietf.org/html/rfc7519) are often used in stateless authentication flows. Thanks to the signature, the server does not need anything else to verify the token validity.
The `scope` claim ([RFC8693 section 4.2](https://tools.ietf.org/html/rfc8693#section-4.2)) contains _a space-separated list of scopes associated with the token_. The server can use it to check the application permissions.
Although this claim can quickly become heavy. The more scopes you have, the bigger your token is!
But JWT are meant to be a [_compact token format_](https://tools.ietf.org/html/rfc7519#section-1)...

Today I'm proud to present you an idea to compress scope list into a bitmap where one bit represents one scope.
<!--more-->

### From space-separated list to bitmap

The idea is quite simple. Instead of a huge string with all the scopes associated with the token, I associate each scope to a bit in a byte sequence. Each bit tells us if a scope is associated (or not) to the token.

For instance:

```
          0  1  1  0  1  0  0  1     1  0  1 (...)
scope_a ──┘  │  │  │  │  │  │  │     │  │  │
scope_b ─────┘  │  │  │  │  │  │     │  │  │
scope_c ────────┘  ┆  ┆  ┆  ┆  ┆     ┆  ┆  ┆
(...)                 ┆  ┆  ┆  ┆     ┆  ┆  ┆
```

In this example, `scope_b` and `scope_c` are enabled, not `scope_a`.

As you already know, _byte-array_ is not a JSON data type. But it's not a big deal, we can encode these bytes in [Base 64](https://tools.ietf.org/html/rfc4648#section-4).

For a 3 bytes (max 24 scopes) claim, it would look like:

```
{
    (...)
    "b_scope": "NDIh"
}
```

### Towards a new claim

I ~~don't want to~~ can't override the current `scope` claim specification. Even if technically it would not break the specification (because we still store a string inside), this is not a good practice IMO. Furthermore, in some cases you might want to have both a traditional `scope` claim and a bitmap scope claim.

That's the reason why I decided to create a new claim: `b_scope`.

### Where and how to define the scope list ?

Any resource provider is documenting the list of scopes available in its API. It's defined either in a "human readable" documentation (text, html, pdf,...) or in a structured specification ([OAuth Authorization Server Metadata](https://tools.ietf.org/html/rfc8414), [OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html), OpenAPI,...).

For structured specifications my suggestion would be to keep the same ordered list and use the index of each scope as bit number.
The [`scopes_supported` field in OAuth Metadata](https://tools.ietf.org/html/rfc8414#section-2) is a JSON array. Order of elements is preserved. However the [`scopes` field in OpenAPI](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.3.md#oauth-flow-object) is a map (JSON Object). We should not rely on the ordering of keys. Hopefuly the OpenAPI specification [allows extensions](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.3.md#specificationExtensions). It means that we could define a `x-scopes-order` keyword which would list (JSON Array) the scopes with preserved ordering (like in OAuth Metadata).

### Performances

Is it a good idea from **size** point of view ?

Let say that you have 42 scopes in your API ([I use Facebook API as example](https://developers.facebook.com/docs/facebook-login/permissions/)). It would require 6 bytes to store them in the bitmap. Because of Base 64 encoding we have to do `4 * n / 3` (+ rounded up mult 4) = 8 bytes. And to be fair, I added 2 bytes in claim name (prefix `b_` compared to `scope` claim) for a total of 10 bytes. The equivalent in size of scope list `email name`.

Is it a good idea from **parsing** (CPU load) point of view ?

Testing a byte sequence with binary operators is not CPU consuming. Compared to string manipulation and comparison it's probably more performant.

### Remaining questions

#### About bit numbering (endianness)

_LSB_ vs _MSB_. Currently I don't know what's the best option. I guess the answer should come from the following criteria:

  - What's the most efficient/performant ?
    To be tested in multiple web-oriented languages (JS, Python, Ruby, Rust, Swift,...)
  - What's the most "natural" in OAuth/JWT ecosystem ?

#### How-to deprecate a scope ?

You might want to deprecate a scope but you can't remove this scope from the list otherwise it would shift all other following scopes.

In this case you will loose a bit. But if your tokens are limited in time, you could replace the bit scope with another after a deprecation period (longer than the max token lifetime).

But... do you often deprecate a scope ?

#### And the "dynamic" scopes ?

Some people are definining "dynamic" scopes. For instance: `pets.{id}.read`. I don't think it's a good practice. My understanding of scopes is to grant access to an API feature, not to the resource itself. In other words, IMHO you should have only one scope `pet.read` which allows application to read a pet. Your resources (aka content) ACL should not be in the scope itself.

Btw this bitmap scope mechanism is compatible with existing standard `scope` claim.

#### Could we use this `b_scope` outside of JWT ?

Why not ? I didn't analyze (yet) where and how we could use it but I guess it could be useful in some cases.
However I don't see a big benefit to use it in OAuth (token and authorize) endpoints. These endpoints are called punctually while JWT is sent in each API request.


### Follow up

You might have questions or you just want to discuss about it. Please open issue in my blog repository or feel free to send me an email.

Here is some feedback from HN: [https://news.ycombinator.com/item?id=23270052](https://news.ycombinator.com/item?id=23270052)
