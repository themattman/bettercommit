#!/usr/bin/env python
#
# Generate Stock Hooks from config file
#
# Author:  Matthew Kneiser
# Date:    5/27/2015
# Purpose: Create hook files based on a config file in the same dir as
#          this script
#
# The hooks should be set up in the src-dir as follows:
#   pre-commit (default file that will be generated by this file and called by git)
#   pre-commit.UPDATE_README (custom hook that may or may not be used)
from __future__ import print_function
from install_templates import remove_files
import argparse
import json
import os
import stat
import sys
import time

class HookFile(object):
    """
    This class lets you create a git hook file that calls custom hooks in a
    specified order.
    """
    contents       = ""
    shebang        = "#!/usr/bin/env bash"
    linux_color    = "\e[0;37m"
    linux_red      = "\e[1;31m"
    linux_endcolor = "\e[0m"
    def __init__(self, fully_qualified_file_path):
        self.path = "%s" % fully_qualified_file_path
        self.create_hook()

    def create_hook(self):
        self.contents = "%s\n" % self.shebang
        self.contents += ("# Auto-generated by the 'configure' script at %s\n"
                          % time.strftime("%c"))
        self.contents += "exit_error() {\n"
        self.contents += "    if [[ $# -gt 0 ]]; then\n"
        self.contents += ("        echo -e \"%sCommit has failed. Fix the errors and try again.%s\"\n"
                          % (self.linux_red, self.linux_endcolor))
        self.contents += "    fi\n"
        self.contents += "}\n"
        self.contents += "trap exit_error ERR\n"
        self.contents += "set -eo pipefail\n"
        self.contents += "{\n"

    def insert_update_hook_logic(self, hook_path):
        self.contents += "%s || bad_cmd=$?\n" % hook_path
        self.contents += "if [[ (-n $bad_cmd) && ($# -gt 0) && ($bad_cmd -ne 2) ]]; then\n"
        self.contents += "    # Remote has new changes and needs to be pulled from\n"
        self.contents += "    echo \"Re-executing the pre-commit with an updated template.\"\n"
        self.contents += "    " + '.'.join(hook_path.split('.')[:-1]) + " 1\n"
        self.contents += "    exit $?\n"
        self.contents += "elif [[ (-n $bad_cmd) && ($bad_cmd -ne 2) ]]; then\n"
        self.contents += "    echo 'pre-commit.UPDATE_TEMPLATE failed.' && false\n"
        self.contents += "elif [[ (-n $bad_cmd) && ($bad_cmd -eq 2) ]]; then\n"
        self.contents += "    echo 'No new updates to the template. Skipping update.'\n"
        self.contents += "fi\n"
        self.contents += "git diff --quiet > /dev/null 2>&1 || keep_index=1\n"
        self.contents += "if [[ $keep_index -eq 1 ]]; then\n"
        self.contents += "    git stash save --quiet --keep-index \"[bettercommit @ $(date)] saving temporary work for safe hook operation\"\n"
        self.contents += "fi\n"

    def insert_script_into_hook(self, hook_path):
        if os.path.exists(hook_path):
            self.contents += "echo -e '%sExecuting %s hook...%s'\n" % (
                self.linux_color,
                os.path.basename(hook_path).split('.')[-1],
                self.linux_endcolor)
            self.contents += "printf \"%0.s-\" {1..80} && echo\n"
            if "pre-commit.UPDATE_TEMPLATE" in hook_path:
                self.insert_update_hook_logic(hook_path)
            else:
                self.contents += "%s \"$@\" || (echo '%s failed.' && false)\n" % (hook_path, os.path.basename(hook_path))
            self.contents += "printf \"%0.s-\" {1..80} && echo\n"
        else:
            print("Error: %s does not exist. Ignoring." % hook_path,
                  file=sys.stderr)

    def write_hook_to_file(self):
        self.contents += "if [[ $keep_index -ne 0 ]]; then\n"
        self.contents += "    git stash pop --index || echo \"Error: there are conflicts between the stash and the index. Inspect 'git stash list'\"\n"
        self.contents += "fi\n"
        self.contents += "} | less -iFXR;\n"
        with open(self.path, "w+") as hook_fh:
            print(" [%s] written." % self.path)
            print(self.contents, file=hook_fh)
        os.chmod(self.path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP)

if __name__ == "__main__":
    msg = """The name of the config file to configure for this project.
    This script looks for 'config-PROJECT.json in the configs/
    directory."""
    parser = argparse.ArgumentParser(description='Configure Git hooks.')
    parser.add_argument('-p', '--project',
                        type=str,
                        default='default',
                        help=msg)
    parser.add_argument('-s', '--src-dir',
                        type=str,
                        required=True,
                        help="Where custom hooks currently exist")
    parser.add_argument('-d', '--dst-dir',
                        type=str,
                        required=True,
                        help="Location to install stock hooks (existing stock hooks in this location will be cleared out)")
    parser.add_argument('-c', '--cfg-dir',
                        type=str,
                        required=True,
                        help="Path to config dir. Typically similar to the target location of the stock hooks")
    parser.add_argument('-u', '--cur-dir',
                        type=str,
                        required=True,
                        help="Path to dir that should contain the 'current' file with the configured config name inside. This file will get updated.")

    args = parser.parse_args()
    config_file_name = "config-%s.json" % args.project
    config_file_path = os.path.join(args.cfg_dir, config_file_name)
    print("Config file used: [%s]\n" % config_file_path)

    # Write the "current" file so that the UPDATE_TEMPLATE hook knows which
    # config file is being used. Overwrite whatever is there. Users were
    # warned.
    print("Writing project [%s] to 'current' file @ [%s]" %
          (args.project, os.path.join(args.cur_dir, 'current')))
    with open(os.path.join(args.cur_dir, 'current'), "w+") as current_fh:
        print(args.project, file=current_fh)

    valid_hook_names = [
        "applypatch-msg",
        "pre-applypatch",
        "post-applypatch",
        "pre-commit",
        "prepare-commit-msg",
        "post-commit",
        "pre-rebase",
        "post-checkout",
        "post-merge",
        "pre-push",
        "pre-receive",
        "update",
        "post-receive",
        "post-update",
        "pre-auto-gc",
        "post-rewrite"
    ]
    config = {}
    try:
        json_fh = open(config_file_path)
        try:
            config = json.load(json_fh)
        except ValueError:
            config["hooks"] = []
    except IOError:
        print("Error: %s is not a valid project name" % args.project,
              file=sys.stderr)
        sys.exit(1)

    if args.dst_dir:
        # Destroy any pre-existing hook files
        hooks_to_destroy = set(valid_hook_names).difference(
            set([x["name"] for x in config["hooks"]]))
        remove_files(list(hooks_to_destroy), args.dst_dir)

    # Create new stock hooks
    print("\nCreating new stock hooks:")
    for hook_type in config["hooks"]:
        print(hook_type["name"])
        generated_hookfile = HookFile(
            os.path.join(args.dst_dir, "%s" % hook_type["name"]))
        for hook in hook_type["ordering"]:
            hook_file_name = "%s.%s" % (hook_type["name"], hook.upper())
            hook_path      = os.path.join(args.src_dir, hook_file_name)
            print(" ", hook_file_name)
            generated_hookfile.insert_script_into_hook(hook_path)
        generated_hookfile.write_hook_to_file()
    print("\ndone configuring.")
