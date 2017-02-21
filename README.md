# Centralized, Automated Git Workflow

### Welcome to a better way of life

This repo is intended to automate your team's Git workflow by acting as a

central location to store Git hooks that different teams may configure and

customize. Automate away common issues and repetitive tasks.


## Installation

### Quick way

```shell
$ mkdir ~/template_dir && cd ~/template_dir && echo "Previous template dir:[$(git config --path --get init.templatedir)]"

$ git config --global --unset init.templatedir; git clone git@github.com:themattman/bettercommit.git && cd bettercommit && ./install.sh [-p PROJECT]
```

## Updating

From now on, go inside any pre-existing git repository and run this command to

install the template files. The PROJECT should correspond to

configs/config-PROJECT.json

```shell
$ git update [-p PROJECT]
```


### Install different hooks in one repo

```shell
$ git update -p NEW_PROJECT_NAME
```

The update command is your entry point to this framework.

```shell
$ git update --help
```

Confirm that different hooks are installed *only* in current repo:

```shell
$ git update -c # current configuration installed in current repo
NEW_PROJECT_NAME
```

```shell
$ git update -g # global configuration
default
```

### Auto-Updating

By default, the pre-commit hook updates the template directory.

Thus, every time you commit (from any repo that is configured with this template)

the main template directory updates itself and all new hooks and configuration

changes to the track you're using will immediately take effect and execute.

Pretty neat, eh?

### Remove framework

Bettercommit tracks all the repos on your machine that contain hooks from the

framework in two files called

* `~/.bettercommit`

* `~/git_template/bettercommit/all_user_repos`

To entirely disable bettercommit, use either of these commands:

```shell
git off

git update --off
```

## Dependencies

* logrotate(8)

* readlink(1)
