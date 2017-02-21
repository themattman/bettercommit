#!/usr/bin/env python
#
# Forceful Git-Init
#
# Author:  Matthew Kneiser
# Date:    5/28/2015
# Purpose: Installs all Git template files into a repository
#
# Background:
#   Git-init will not overwrite anything, thus this script
#   seeks to remove everything that git-init will not overwrite.
from __future__ import print_function
import argparse
import datetime
import os
import platform
import shutil
import subprocess
import sys


def remove_files(conflicting_files, path=None):
    def failed_delete(*args):
        print("failed")

    print(os.getcwd())
    for f in conflicting_files:
        file_to_rm = ""
        if path is not None:
            file_to_rm = os.path.join(path, f)
        else:
            file_to_rm = os.path.join('.git', f)
        print("Removing... %s" % file_to_rm)
        try:
            if os.path.isfile(file_to_rm):
                os.remove(file_to_rm)
            elif os.path.isdir(file_to_rm):
                shutil.rmtree(file_to_rm, False, failed_delete)
        except OSError as e:
            print("Couldn't remove. %s" % e)


def git_init(dst_dir):
    # Update the current repository against the template
    # From the git-init(1) manpage:
    #    The primary reason for rerunning git init is to pick up newly added
    #    templates
    print("git init..")
    subprocess.call(['git', '--git-dir=%s' % dst_dir, 'init'])


def get_template_dir():
    gitdir = subprocess.Popen(
        [
            'git',
            'config',
            '--get',
            '--path',
            'init.templatedir'
        ],
        stdout=subprocess.PIPE)
    stdout, stderr = gitdir.communicate()
    template_dir = stdout.rstrip()
    return template_dir


def persist_location_of_target_repo(git_dir):
    """Used to track all the repos that use the template framework
    """
    def commit_repo_backup_file():
        backup_command = "%s" % (
            os.path.join(get_template_dir(), ".." "backup_repos_file.sh")
        )
        print('-')
        print(backup_command.split())
        print('-')
        try:
            process = subprocess.Popen(backup_command.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            (stdout, stderr) = process.communicate()
            print(stdout)
            print(stderr)
            if process.returncode == 0:
                print("Successfully backed up the all_user_repos file to the server.")
            else:
                print("Was unable to back up the all_user_repos file to the server.")

        except subprocess.CalledProcessError as e:
            print("Unhandled exception in [%s]: %s" % (backup_command, e))
            sys.exit(1)

    def write_new_repo_to_persistence(new_row, path_to_persist_file):
        with open(all_user_repos_file_name, "a") as persist_file:
            persist_file.write(str(new_row))
            persist_file.write("\n")

        # Copy new all_user_repos file to the user's HOME for redundancy
        shutil.copyfile(all_user_repos_file_name,
                        os.path.join(os.path.expanduser("~"), ".bettercommit"))

    def determine_new_repo(path_to_persist_file):
        # Figure out if the target repo already has the template framework
        with open(path_to_persist_file, "r+") as persist_file:
            contents = persist_file.read().rstrip('\n').split()

            # [
            #   (HOST, LOCATION), ...
            # ]
            repos = [tuple(x.split(':')[-2:]) for x in contents]

            print("repos_no_time:", repos)
            new_row = "%s:%s:%s" % (
                datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S"),
                platform.uname()[1],
                os.path.realpath(os.path.join(git_dir, "..")))
            new_repo = (platform.uname()[1], os.path.realpath(os.path.join(git_dir, "..")))
            print()
            print("new_repo:", new_repo)
            print("new_row:", new_row)
            print()

            if new_repo not in repos:
                return (True, new_row)
            else:
                return (False, new_row)

    # Write this repo location to a file for tracking purposes
    all_user_repos_file_name = os.path.join(get_template_dir(), "..", "all_user_repos")

    # Create the persisted repo file if it doesn't already exist
    if not os.path.exists(all_user_repos_file_name):
        open(all_user_repos_file_name, 'a').close()

    (is_new_repo, new_repo_row) = determine_new_repo(all_user_repos_file_name)
    if is_new_repo:
        print("Adding [%s] to user's repo list" % ":".join(new_repo_row.split(':')[-2:]))
        write_new_repo_to_persistence(new_repo_row, all_user_repos_file_name)
        commit_repo_backup_file()
    else:
        print("[%s] already in user's repo list" % ":".join(new_repo_row.split(':')[-2:]))


def get_conflicting_files(git_dir):
    # Get files in the current dir
    target_files = set(os.listdir(git_dir))
    print("Target: %s" % target_files)

    # Get files in the template dir
    source_files = set(os.listdir(get_template_dir()))
    print("Source: %s" % source_files)

    conflicting_files = target_files.intersection(source_files)
    print("Intersection: %s" % conflicting_files)
    return conflicting_files


def main(args):
    git_dir = os.path.abspath(args.dst_dir)
    if not os.path.exists(git_dir):
        print("Error: dst-dir doesn't exist: %s" % git_dir, file=sys.stderr)
        sys.exit(1)

    # Remove any existing files/dirs that conflict with new ones
    #  this operation is what makes this script a "forceful" git init
    remove_files(get_conflicting_files(git_dir), args.dst_dir)

    persist_location_of_target_repo(git_dir)

    git_init(args.dst_dir)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Forceful Git-Init')
    parser.add_argument('-d', '--dst-dir',
                        type=str,
                        default='default',
                        required=True,
                        help='Location to forcefully git init (Path of .git directory)')
    main(parser.parse_args())
