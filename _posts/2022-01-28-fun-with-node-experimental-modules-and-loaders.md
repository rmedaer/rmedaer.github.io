---
layout:     post
title:      Fun with Node experimental modules and loaders
date:       2022-01-28 15:00:00 +0200
categories: js
---

If you are a front-end or a fullstack developer, you maybe already imported CSS files from a Javascript or a Typescript file. For instance:

```js
import styles from "./styles.css"
```

A few months ago it would not have been possible out of the shelf. Indeed you would need a bundler (such as WebPack, Rollup,...) to "inline" the CSS file as a string in your Javascript file.

Nowadays it's possible thanks to the "CSS Modules" (to not confuse with [the homonym open-source project](https://github.com/css-modules/css-modules)).<!--more--> It's even already [implemented in Chrome](https://chromestatus.com/feature/5948572598009856). For more details, please read the [_"CSS Modules (The Native Ones)"_ article](https://css-tricks.com/css-modules-the-native-ones/) from [Chris Coyier](https://css-tricks.com/author/chriscoyier/). However it's not yet brought to NodeJS implementation. In the meantime, NodeJS allow us to [customize the default module resolution](https://nodejs.org/api/esm.html#loaders) through three JS hooks: [`resolve`](https://nodejs.org/api/esm.html#resolvespecifier-context-defaultresolve), [`load`](https://nodejs.org/api/esm.html#loadurl-context-defaultload) and [`globalPreload`](https://nodejs.org/api/esm.html#globalpreload). These hooks are provided via the command line argument `--experimental-loader`. Pay attention that it's an experimental feature. Furthermore the _"API is currently being redesigned and will still change"_.

We will use this feature to load CSS file as an ECMAScript module and therefore bypass the bundling/building phase. We will also have to use ECMAScript modules to make it work:

> To load an ES module, set "type": "module" in the package.json or use the .mjs extension.

Our project starts with the following files:

```js
/* index.mjs */
import styles from "./styles.css";

console.log(styles);
```

and

```css
/* styles.css */
html, body {
    margin: 0;
}
```

Without custom loader, the result would be an _"Unknown file extension"_.

```bash
$ node index.mjs
node:internal/errors:464
    ErrorCaptureStackTrace(err);
    ^

TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".css" for /(...)/styles.css
    at new NodeError (node:internal/errors:371:5)
    (...)
    at async ModuleWrap.<anonymous> (node:internal/modules/esm/module_job:81:21) {
  code: 'ERR_UNKNOWN_FILE_EXTENSION'
}

Node.js v17.3.0
```

Let's write our basic custom loader:

```js
/* loader.mjs */
import { URL } from "url";
import { readFile } from "fs/promises";

/**
 * This function loads the content of files ending with ".css" to an ECMAScript Module
 * so the default export is a string containing the CSS stylesheet.
 */     
export async function load(url, context, defaultLoad) {
    if (url.endsWith(".css")) {
        const content = await readFile(new URL(url));

        return {
            format: "module",
            source: `export default ${JSON.stringify(content.toString())};`,
        }
    }

    return defaultLoad(url, context, defaultLoad);
}
```

Running NodeJS with our loader will now print[^1] the content of _styles.css_:

```bash
$ node --no-warnings --experimental-loader ./loader.mjs index.mjs
html, body {
    margin: 0;
}
```

This is a really basic example to understand NodeJS custom loaders. As you may have noticed, I didn't use [_"Import Assertions"_](https://github.com/tc39/proposal-import-assertions) although it's mandatory for [JSON modules](https://nodejs.org/api/esm.html#json-modules) in NodeJS. For security reasons the import should actually look like:

```js
import styles from "./styles.css" assert { type: "css" };
```

[^1]: The argument `--no-warnings` is used for ease of reading, I recommend you to keep warnings in your development and deployments.
