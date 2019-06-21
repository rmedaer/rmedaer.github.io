---
layout:     post
title:      Open RXVT terminal in current directory
date:       2019-06-21 12:00:00 +0200
image:      "/assets/img/urxvt-open-current-wd-intro.png"
categories: rxvt
---

Two years ago I switched from terminator to URXVT. This is now my day to day terminal emulator. URXVT is the unicode version of RXVT started long time ago by Rob Nation. Today I'll show you how I fixed one of the very missing useful feature: **open a new terminal in current working directory**. By _"current working directory"_ I mean _"the working directory of the shell in the most recent focused terminal"_.

This is actually a frequently asked question. However I didn't find answer which convinced me. Here are some threads talking about:

  * [on reddit: _"How to open new urxvt window in the same directory as focused (...)"_](https://www.reddit.com/r/archlinux/comments/7km09z/how_to_open_new_urxvt_window_in_the_same/)
  * [on stack superuser: _"How to open new terminal in current directory?"_](https://superuser.com/questions/759294/how-to-open-new-terminal-in-current-directory)
  * [on i3wm: _"How to launch a terminal "from here"?"_](https://faq.i3wm.org/question/150/how-to-launch-a-terminal-from-here/%3C/p%3E.html)

The proposed answers are IMHO weak scripts or hack playing with X11. I want a structural solution and thanks to RXVT plugins we can implement it ... in Perl 😒.
But first here are my requirements:

  * MUST be optional; I still have to open terminal in home directory
  * MUST work without having to parse window title or other fancy X11 trick
  * SHOULD work with multi-user and multi-display

With the following URXVT Perl extension(s), I hope to fulfill this feature once and for all.



I implemented two new URXVT extensions: `remember-last-dir` and `open-last-dir`.

`remember-last-dir` keeps in shared memory the shell PID of last focused terminal. Currently the IPC key is using only the user ID. Not the display ID. However it could be a nice improvement. This extension must always be enabled.

```pl
#!/usr/bin/perl

use IPC::Shareable;

my $glue = sprintf 'urxvt-last-dir-%d', $<;
my %options = (
    create    => 'yes',
    exclusive => 0,
    mode      => 0700,
    destroy   => 'no',
);

sub on_focus_in {
    my ($self) = @_;
    my $pid;
    tie $pid, 'IPC::Shareable', $glue, { %options };
    $pid => $self->{shell_pid};
}

sub on_child_start {
    my($self, $pid) = @_;
    $self->{shell_pid} = $pid;
}
```

`open-last-dir` is initializing the terminal with the working directory of current PID in shared memory. This extension is optionally launched from URXVT command line: `urxvt -pe open-last-dir`.


```pl
#!/usr/bin/perl

use IPC::Shareable;

my $glue = sprintf 'urxvt-last-dir-%d', $<;
my %options = (
    create    => 'yes',
    exclusive => 0,
    mode      => 0700,
    destroy   => 'no',
);

sub on_init {
    my ($self) = @_;
    my $pid;
    tie $pid, 'IPC::Shareable', $glue, { %options };

    if (defined $pid and $pid ne "") {
        my $link = sprintf "/proc/%d/cwd", $pid;
        my $wd = readlink $link;
        if (-e $wd) {
            $self->resource("chdir", $wd);
        }
    }
}
```

I guess we could improve this code. This is here a quick dump of my setup. Please don't blame me for missing error handling, code factoring, ... If you want to contribute or help me going further with this extension, please [leave me a message in my blog issues](https://github.com/rmedaer/rmedaer.github.io/issues).

Thanks for reading,

R.
