#!/usr/bin/env python
#
# Display the template framework versions of every repo on this machine
#
# Author: Matthew Kneiser
# Date:   03/17/2016

import argparse
import getpass
import os.path
import platform
import sys

def sort_dirs_by_alphabetical(parsed_file):
    """ Sort based on basename of the repo
    """
    parsed_file.sort(key=lambda tup: os.path.basename(tup[2]))
    return parsed_file

def print_dirs_by_alphabetical(parsed_file, is_time_enabled):
    parsed_file = sort_dirs_by_alphabetical(parsed_file)
    if is_time_enabled:
        print "\n".join([" \t|  ".join(x) for x in parsed_file])
    else:
        print "\n".join([" \t|  ".join(x[-2:]) for x in parsed_file])

def sort_dirs_by_time(parsed_file):
    """ Sort by time repo installed the template framework
    """
    parsed_file.sort(key=lambda tup: tup[1])
    return parsed_file

def print_dirs_by_time(parsed_file, is_time_enabled):
    parsed_file = sort_dirs_by_time(parsed_file)
    if is_time_enabled:
        print "\n".join([" \t|  ".join(x) for x in parsed_file])
    else:
        print "\n".join([" \t|  ".join(x[-2:]) for x in parsed_file])

def print_dirs_by_host(parsed_file, is_time_enabled):
    home_dir_repos = []
    other_host = 0
    hosts = set()
    print platform.uname()[1]
    print "-"*80
    for line in parsed_file:
        home_dir = os.path.join("/usr2", getpass.getuser())
        commonpath = os.path.commonprefix([line[2], home_dir])
        hosts.add(line[1])
        if commonpath and commonpath == home_dir:
            if is_time_enabled:
                home_dir_repos.append("%s \t|  %s" % (line[0], line[2]))
            else:
                home_dir_repos.append("%s" % line[2])
        elif line[1] == platform.uname()[1]:
            if is_time_enabled:
                print "%s \t|  %s" % (line[0], line[2])
            else:
                print "%s" % line[2]
        else:
            other_host += 1
    print "\nUser's Home Directory"
    print "-"*80
    for repo in home_dir_repos:
        print repo
    print "\n[%s] repos are on another host." % other_host
    print "\nHosts:"
    for host in hosts:
        print host

def main(args):
    repos_file = os.path.join(os.path.dirname(os.path.realpath(__file__)), "all_user_repos")
    try:
        parsed_file = []
        with open(repos_file, "r+") as rf:
            lines = rf.read().split()
            parsed_file = [tuple(x.split(':')) for x in lines]
        if args.host:
            if args.name:
                print_dirs_by_host(sort_dirs_by_alphabetical(parsed_file), args.times)
            elif args.creation_time:
                print_dirs_by_host(sort_dirs_by_time(parsed_file), args.times)
            else:
                print_dirs_by_host(sort_dirs_by_time(parsed_file), args.times)
        else:
            if args.name:
                print_dirs_by_alphabetical(parsed_file, args.times)
            elif args.creation_time:
                print_dirs_by_time(parsed_file, args.times)
            else:
                print_dirs_by_time(parsed_file, args.times)
    except IOError as e:
        if e.errno == 2:
            print "Error: framework does not recognize any repos for this user"
        else:
            print e

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Display info about which repos are using the template framework')
    sort_group = parser.add_mutually_exclusive_group()
    sort_group.add_argument('-n', '--name', action='store_true', help='Sorted by name')
    sort_group.add_argument('-c', '--creation-time', action='store_true', help='Sorted by creation time')
    parser.add_argument('-p', '--porcelain', action='store_true', help='Machine-readable output [Not implemented yet]')
    parser.add_argument('-t', '--times', action='store_true', help='Listed with time of creation')
    parser.add_argument('-g', '--host', action='store_true', help='Group by host')
    main(parser.parse_args())
