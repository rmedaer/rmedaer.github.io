---
layout:     post
title:      I hate capital letters!
date:       2020-04-23 21:31:00 +0200
categories: misc
---

I hate capital letters! At least in directory and file names. By default your home directory
has a few directories with first capital letter (`Documents`, `Music`, `Downloads`,...). Ok, it looks nice! But I always make mistake when I type capital letter in my terminal. Fortunately, all of this is configurable...

Thanks to [`xdg`](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
and its command line tool: `xdg-user-dirs-update`! Man describes how to use `xdg-user-dirs-update --set NAME PATH` otherwise you can edit your global (or local) `xdg` configuration (on Debian `/etc/xdg/user-dirs.defaults`). Here is mine:

```
# Default settings for user directories
#
# The values are relative pathnames from the home directory and
# will be translated on a per-path-element basis into the users locale
DESKTOP=desktop
DOWNLOAD=downloads
TEMPLATES=templates
PUBLICSHARE=public
DOCUMENTS=documents
MUSIC=music
PICTURES=pictures
VIDEOS=videos
```
