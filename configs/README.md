# Project-Specific Hook Configurations

Feel free to create as many config files as you like.

## Naming convention

```shell
config-PROJECT.json
```

Example: `config-foobar.json`

## Purpose

This directory should be modified and maintained by project leads. These

leads should be the ones that endorse a specific configuration for their team.

It is highly recommended that maintainers/leads include all the hooks in the

`default` configuration, as they ensure proper behavior of the framework.

## Usage

```shell
$ git update -p NEW_PROJECT
```

## Schema of Config Files

There is one top level object that should contain one list with a key of "hooks".

Inside the list should only be one object per Git hook action (i.e. one for

"pre-commit", "pre-push", etc.). The rest should be self-explanatory.

Look at the `default` config file for a great example.
