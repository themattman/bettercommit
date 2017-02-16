# Custom Hooks

## Naming convention

    stock_hook.DESCRIPTION[_USERNAME]

Example: `pre-commit.WHITESPACE`

"stock_hook" must be lowercase. The DESCRIPTION and USERNAME *must* be uppercase.

## Purpose

All developers are encouraged to push updates to these hooks in this directory.

Your changes to this directory will be picked up by all other users of this

repository next time a githook is invoked on their machine due to their activity.

## Naming Tips

Be liberal with appending usernames or project names to the end of hooks to

avoid name collision. This is intended for times when you want to make a custom

version of a hook.

Example:

```shell
pre-push.STOP_ALL_PUSHES

pre-push.STOP_ALL_PUSHES_THEMATTMAN
```

The actual hooks (stock hooks) get created by `configure.py`

according to the config file you have pointed to

(default is `configs/config-default.json`).

If you do not know which config file you have installed, run

```shell
$ git update --current
```

## Stock Hooks

These are the possible Git hooks that you can implement. `man githooks` for more

info.


```shell
applypatch-msg

pre-applypatch

post-applypatch

pre-commit

prepare-commit-msg

post-commit

pre-rebase

post-checkout

post-merge

pre-push

pre-receive

update

post-receive

post-update

pre-auto-gc

post-rewrite
```


## Common Edge Cases for Hook Authors to Consider & Test (Please add to this list!)

* Deleted files

* Binary files

* Empty files

* Malicious or special file names/paths

* How to handle files when overwriting (e.g. remove trailing whitespace)

  * Should probably have convention for backup files

    (.bak, .<hook_name>, or .$(basename $0) ??)

    currently, ".working_directory_backup" is used in a hook (INTRODUCED_TRAILING_WHITESPACE_REMOVER)

## Colors

Recommended usage of color in any hook:

```shell
if [[ "linux-gnu" = "${OSTYPE}" ]]; then
  COLOR_YELLOW="\e[1;35m"
  COLOR_GREEN="\e[0;32m"
  COLOR_<COLOR_NAME>="<LINUX_COLOR_CODE>"
  COLOR_END="\033[0m"
fi
```
