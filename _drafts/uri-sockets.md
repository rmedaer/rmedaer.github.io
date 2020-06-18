---
layout:     post
title:      Configure your sockets with URIs
date:       2020-06-18 10:46:23 +0200
categories: uri
---

Everybody knows Uniform Resource Identifier (URI)[^1]. As its name suggests, it's a way to identify a resource (for instance a file or a phone number).
It is often confused with Uniform Resource Locator (URL), which is actually a form of URI. A URL is _a compact string representation for a resource available via the Internet_[^2].

Today I want to share with you the way I define another type of resources: network sockets.
<!--more-->
Everybody knows what a network socket is, right ?

The socket families I often use are `inet`, `inet6` and `unix`. But there are much more types of endpoints: `ipx`, `bluetooth`,...

To configure the sockets my services or APIs have to bind, I'm now using URIs! For instance:

```
inet://127.0.0.1:80?reuseaddr=true
```

In this example I basically create a socket IPv4 on address `127.0.0.1` and port `80` with `SO_REUSEADDR` option enabled. 

### Syntax

The URI _scheme_ defines which socket family I have to use:

  - _inet_ for IPv4 sockets
  - _inet6_ for IPv6 sockets
  - _unix_ for Unix sockets

Hopefully these schemes are not (yet) registered at IANA[^3].

The URI's _authority_ and _path_ depend on the family used. Query arguments are used to configure options of the socket. They also depend on the family used.

#### IPv4 sockets

For _inet_ family the authority is mandatory. It contains:

  - the _hostname_ (optional):
    - either a IPv4, for instance `127.0.0.1`
    - or a hostname which needs to be resolved as a IPv4 address
    - if not specified, the default value is `0.0.0.0`: it binds on all IPv4 addresses
  - the _port_ (mandatory)

The _path_ is not used in this case, it remains empty.

Here are some examples:

  - `inet://127.0.0.1:8080` binds on address `127.0.0.1` and port `8080`, easy!
  - `inet://example.com:5432` resolves `example.com` to an IPv4 and binds on port `5432`
  - `inet://:80?reuseaddr=true` listen on port `80` and accept connections on any IPv4 of the system (`0.0.0.0`) even if there are remaining connections in `TIME_WAIT`

#### IPv6 sockets

Idem than `inet` but for IPv6 and with URI scheme `inet6`. Some query argments might defer.

You're probably wondering why I use `inet` **and** `inet6`. Indeed I could use an IPv6 address with the `inet` scheme. However it doesn't work with domain name resolution. For instance `inet://localhost:80` will bind on IPv4 address `127.0.0.1` while `inet6://localhost:80` will bind on IPv6 address `::1`.

#### Unix sockets

_Authority_ part is not used for _unix_ family. However the path is used like a `file:/` URI. It defines the path of the unix socket.

For instance: `unix:///var/run/my-socket.sock`

### Specification & implementation

I don't think there is already a specification or RFC which tackle this idea.

I guess this trick is already used in ~~some~~ many implementations. To be honnest I didn't look a lot. But feel free to share your godsend!

[^1]: See [RFC3986 "Uniform Resource Identifier (URI): Generic Syntax"](https://tools.ietf.org/html/rfc3986)
[^2]: Quoting [RFC1738 "Uniform Resource Locators (URL)", Section 1 "Introduction"](https://tools.ietf.org/html/rfc1738#section-1)
[^3]: See [IANA Assignements: Uniform Resource Identifier (URI) Schemes](https://www.iana.org/assignments/uri-schemes/uri-schemes.xhtml)
