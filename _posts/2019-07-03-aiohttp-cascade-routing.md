---
layout:     post
title:      Cascade routing with AIOHTTP
date:       2019-07-03 07:30:00 +0200
image:      "/assets/img/cascade.png"
categories: aiohttp 
---

A common routing use-case is to share a route URL pattern for multiple purposes. For instance GitHub is using `github.com/<something>` for both users and organizations. Indeed the user and organization pages are different. A way to implement this is using a fallback mechanism called by some of us _cascade routing_. Meaning: fallback to next request handler if current one is not suitable. You'll find this kind of behavior in popular front/backend framework [such as Angular](https://github.com/angular/angular/pull/16416). Actually it's not yet available in Angular... 😒 and as far as I know not implemented in [AIOHTTP](https://aiohttp.readthedocs.io/). 😭

_AN: I don't compare AIOHTTP and Angular... obviously ! I just challenge the popularity of this feature._

In this short post I implement this mechanism with [AIOHTTP](https://aiohttp.readthedocs.io/) !

```python
class NotHandledException(Exception):
    pass

class CascadeRouter:
    def __init__(self, handlers):
        self._handlers = handlers

    async def __call__(self, *args, **kwargs):
        for handler in self._handlers:
            try:
                return (await handler(*args, **kwargs))
            except NotHandledException:
                # Fallback on next handler
                pass
        else:
            raise HTTPNotFound()
```

DONE ! Yes, that's it ! Let's analyze the code above...

First we define a new kind of `Exception` named `NotHandledException`. Users (aka developers) will have to raise this exception if they can't deal with the given request.

The second class `CascadeRouter` is the router itself. _Ah bon ?!_ It is instantiated with the ordered list of handlers to call. Thanks to `__call__` method, we can give this router to AIOHTTP which can call it like any handler.

Here is an example of usage:

```python
async def handler_a(request):
    raise NotHandledException()
    return Response(text='Hello from A')

async def handler_b(request):
    return Response(text='Hello from B')

def main():
    app = Application()
    app.add_routes([
        web.get('/', CascadeRouter([
            handler_a,
            handler_b,
        ]))
    ])
```

In closing, we can discuss about the `for ... else` in `CascadeRouter#__call__`. Indeed it's not mandatory however it's IMHO more readable. Later we will be able to replace the `return` statement by a `break` and do some extra processing on handler result.

As usual, please [leave me a message in my blog issues](https://github.com/rmedaer/rmedaer.github.io/issues) if you have any comment or advice.

R.
