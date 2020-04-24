---
layout:     post
title:      Manage multiple identities with Git
date:       2020-04-24 08:42:00 +0200
categories: misc
---

I work on many different Git repositories. For each of them I have a particular email address and sometimes
a GPG key. Even the Git flow might be different; always `--no-ff` (or not), `pull --rebase` instead of merge,...

To deal with it I recently learned about [_Conditional includes_](https://git-scm.com/docs/git-config#_conditional_includes).
It's basically a way to include additional Git config files with a given condition. You have to configure it as a
new section in your Git repository.

In my case I organize projects and repositories with the following tree:

```
documents
└── development
    ├── allocloud
    │   └── (...) # ALLOcloud's repos
    ├── <project x>
    │   └── (...) # Repos from project x
    └── (...) # Other repos
```

For each project, I created a specific `.gitconfig` file that include in my main `~/.gitconfig`:

```
[user]
    name = Raphael Medaer
    email = raphael@medaer.me
    signingkey = D4D764423DCEA9FC90327C78FE29196052B47DF1

[commit]
    gpgSign = true

[includeIf "gitdir:~/documents/development/allocloud/**"]
    path = ~/documents/development/allocloud/.gitconfig

# (...)
```
