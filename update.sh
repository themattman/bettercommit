#!/usr/bin/env bash
#
# Update the Template Framework
#
# Author:  Matthew Kneiser
# Date:    5/27/2015
# Purpose: Update an arbitrary repository with the latest Git template
# Requirements: Should be run from inside the target git repo when updating
#
#
# Behavior:
# git update -p PROJECT
#  Affects current git repo's templates.
#
# git update -u
#  Affects global templates.
#
# git update
#  Affects current git repo's templates.
#
# Without any arguments, this script will install either the configured template
# or the "default" project depending on whether the repo has been configured
# (i.e. the 'current' file exists)
#
# Stdout from this script is printed to user [this should be extremely brief].
# All other output should be logged to a temp location based on timestamp,
# ${log_location}. These logs get rotated so they don't take up too much space
# in the user's home directory.
set -e
source "${0}/../utils/readlink.sh"

################################################################################
##
## Help Output and Usage
##
################################################################################
HELP_TEXT="Usage: $(readlink -f "${0}") [OPTIONS] [-p PROJECT]
Update an arbitrary repository with the latest Git template

Recommended usage:
$ git update [OPTIONS]

..this assumes you have the 'update' alias configured:
$ git config --global alias.update '!\$(git config --path --get init.templatedir)/../update.sh'


Requirement:
Must be run from within the target repository.

Options:
\t-i/--aliases \t\tList all aliases for the bettercommit framework
\t-a/--all \t\tList all possible projects
\t-c/--current \t\tGet current project name. If not in a git dir, get current
\t\t\t\tglobal project.
\t-g/--global \t\tGet global project name.
\t-h/--help \t\tPrint this help
\t-l/--list \t\tList all possible projects (alias for --all)
\t-n/--non-interactive \tA flag used to indicate you're not in an interactive
\t\t\t\tenvironment.
\t\t\t\tCurrently only used for internal scripts.
\t\t\t\tWhen set, will skip the prompt that asks user permission to copy
\t\t\t\ttemplates.
\t-z/--off \t\tTurn the framework off
\t-p/--project \t\tProject name to sync [default: current configured project or
\t\t\t\t'default' if not configured].
\t-u/--update \t\tUpdate the current repo by setting it to the global project
\t\t\t\t(-p) name
\t-v/--version \t\tPrints framework version (i.e. the latest tag of the
\t\t\t\ttemplate repo)
"
OPTIONS_STRING="-a --aliases --all -c --current -g --global -h --help -i -l"
OPTIONS_STRING="${OPTIONS_STRING} --list -n --non-interactive -o --off"
OPTIONS_STRING="${OPTIONS_STRING} --options -p --project -u --update"
OPTIONS_STRING="${OPTIONS_STRING} -v --version -z"
print_help () { echo -e "${HELP_TEXT}"; exit 0; }
usage () {
    echo "Usage: $(readlink -f "${0}") [OPTIONS] [-p PROJECT]" >&2
    exit 1
}

################################################################################
# Function: warn_user_on_exit
################################################################################
# This is the final line of defense for reporting errors to user.
# Should only be printed when exiting this script.
warn_user_on_exit () {
    echo "${0}: Error: Something went wrong." >&2
}
trap warn_user_on_exit ERR


################################################################################
##
## Utility Functions
##
################################################################################

################################################################################
# Function: print_version
################################################################################
print_version () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    git --git-dir="${template_gitdir}" describe --tags --abbrev=0
}

################################################################################
# Function: turn_framework_off
################################################################################
turn_framework_off () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    echo -n "Turning the Git Template framework off"
    echo "Turning the Git Template framework off" >> "${log_location}"
    exec 3<"${template_top_level}/all_user_repos"
    while read -u 3 target_repo; do
        target_repo=${target_repo#*:*:}
        if [[ -d $target_repo ]]; then
            pushd "${target_repo}"                    >> "${log_location}" 2>&1
            echo ">>$PWD"                             >> "${log_location}"
            set -x
            {
                rm .git/hooks/*
                rm -rf ".git/${template_namespace}"
            } >> "${log_location}" 2>&1
            { set +x; } 2>/dev/null
            popd                                      >> "${log_location}" 2>&1
        else
            echo "repo [${target_repo}] doesn't exist anymore. skipping."      \
                 >> "${log_location}"
        fi
        echo -n "."
    done
    rm "${template_top_level}/all_user_repos"
    exec 3<"${template_top_level}/git_aliases.txt"
    while read -u 3 LINE; do
        if [[ ! ${LINE:0:1} == "#" && -n $LINE ]]; then
            git_alias_name=${LINE%,*}
            echo "unsetting alias: [${git_alias_name}]" >> "${log_location}"
            git config --unset "${git_alias_name}" >> "${log_location}" 2>&1
        fi
    done
    echo " Done!"
}

################################################################################
# Function: get_all_aliases
################################################################################
# @returns: all framework git aliases by printing to stdout
get_all_aliases() {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    exec 3<"${template_top_level}/git_aliases.txt"
    while read -u 3 LINE; do
        if [[ ! ${LINE:0:1} == "#" && -n $LINE ]]; then
            git_alias_name=${LINE%,*}
            echo "${git_alias_name}"
        fi
    done
}

################################################################################
# Function: get_all_projects
################################################################################
# @returns: all project names
get_all_projects () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    path_to_configs="${template_top_level}/configs"
    if [[ ! -d "${path_to_configs}" ]]; then
        echo "${0}: Error: ${path_to_configs} does not exist." >&2 && exit 1
    fi
    project_list=$(\ls "${path_to_configs}"                                    \
                          | grep -v "README\.md"                               \
                          | cut -d'-' -f2 | cut -d'.' -f1 | sort)
    echo "${project_list//\\\n/ }" | sed  -e 's/ $//'
}

################################################################################
# Function: get_current_project
################################################################################
# @params:  1) path to top-level of repo to investigate
# @params:  2) non-null: exit program if 'current' file doesn't exist
#              null:     return "default"
# @returns: current project name by printing to stdout
get_current_project () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    path_to_current="${1}/${template_namespace}/current"
    if [[ ! -f "${path_to_current}" ]]; then
        if [[ -n "$2" ]]; then
            echo -n "${0}: Error: ${path_to_current} does not exist. " >&2
            echo "Try installing the templates again." >&2 && exit 1
        else
            echo "default" && return
        fi
    fi
    cat "${path_to_current}"
}

################################################################################
# Function: exit_on_project_missing
################################################################################
# @params:  1) project name
# @effects: exits if project does not exist
exit_on_project_missing () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    for p in $(get_all_projects); do
        if [[ "${p}" = "${1}" ]]; then
            return
        fi
    done
    echo "${0}: Error: ${1} is not a valid project." >&2 && exit 1
}

################################################################################
# Function: ensure_template_directory_exists
################################################################################
# @brief: Only needs to be run during installation.
ensure_template_directory_exists () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    if [[ ! -d ${template_top_level}/${template_file_subdir} ]]; then
        mkdir -p "${template_top_level}/${template_file_subdir}"
    fi
    if [[ ! -d ${template_top_level}/template/hooks ]]; then
        mkdir -p "${template_top_level}/template/hooks"
    fi
}

################################################################################
# Function: rotate_logs
################################################################################
# @brief: Rotate the logs so they don't get too big
rotate_logs () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    logrotate "${log_dir}/bettercommit.conf" -s "${log_dir}/bettercommit.state"
}

################################################################################
# Function: update_global_templates
################################################################################
# @brief: Update the global template directory
# @params: 1) project name
update_global_templates () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    echo -en "${FONT_COLOR_GREEN}"
    echo -en "Updating the template directory on your machine..."
    echo -e  "${ENDCOLOR}"
{
    if [[ "${#}" -ne 1 ]]; then
        echo "${0}: Error: Something went wrong." >&2 && exit 1
    fi
    global_configure_arg="${1}"

    # Get the latest updates from the server
    set -x
    git --git-dir="${template_gitdir}" pull "${TEMPLATE_REMOTE}"               \
        "${TEMPLATE_BRANCH}"
    { set +x; } 2>/dev/null

    # Update the metadata files with the latest commit hash / git tag
    set -x
    git --git-dir="${template_gitdir}" rev-parse HEAD                          \
        > "${template_top_level}/${template_file_subdir}/head_sha.txt"
    git --git-dir="${template_gitdir}" describe --tags --abbrev=0              \
        > "${template_top_level}/${template_file_subdir}/version.txt"
    { set +x; } 2>/dev/null

    # In the template directory,
    # create the stock hooks so that git-init works
    set -x
    "${template_top_level}/utils/configure.py"                                 \
        --cur-dir "${template_top_level}/${template_file_subdir}"              \
        --cfg-dir "${template_top_level}/configs"                              \
        --src-dir "${template_top_level}/custom-hooks"                         \
        --dst-dir "${template_top_level}/template/hooks"                       \
        --project "${global_configure_arg}"
    { set +x; } 2>/dev/null

    # Copy hooks from template to template's .git
    set -x
    "${template_top_level}/utils/install_templates.py"                         \
        --dst-dir "${template_gitdir}"
    { set +x; } 2>/dev/null
} >> "${log_location}" 2>&1
}

################################################################################
# Function: update_local_templates
################################################################################
# @brief: Update the arbitrary repo where the script was run from
# @params: 1) project name
update_local_templates () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    echo -en "${FONT_COLOR_GREEN}"
    echo -en "Updating your current git repository against your machine's "
    echo -en "newly updated template..."
    echo -e  "${ENDCOLOR}"

    if [[ "${#}" -ne 1 ]]; then
        echo "${0}: Error: Something went wrong." >&2 && exit 1
    fi
    target_configure_arg="${1}"
    prompt="[${target_configure_arg}] template into ${current_gitdir}"
    if [[ "${interactive}" -ne 1 ]]; then
        # Prompt user to install hooks into target repo
        read -p "Install ${prompt}? [y/n]: " -n 1 -r
        echo
    else
        echo "Installing ${prompt}."
    fi
    {
        if [[ ( "${interactive}" -eq 1 ) || ( $REPLY =~ ^[Yy]$ ) ]]; then
            # Copy template to target repo's .git
            set -x
            "${template_top_level}/utils/install_templates.py"                 \
                --dst-dir "${current_gitdir}"
            { set +x; } 2>/dev/null

            # In the target repo,
            # create the stock hooks based on the config file chosen by the user
            # This step maintains global configuration of hooks in custom-hooks/
            # and allows for per-repo configuration
            set -x
            "${template_top_level}/utils/configure.py"                         \
                --cur-dir "${current_gitdir}/${template_namespace}"            \
                --cfg-dir "${template_top_level}/configs"                      \
                --src-dir "${template_top_level}/custom-hooks"                 \
                --dst-dir "${current_gitdir}/hooks"                            \
                --project "${target_configure_arg}"
            { set +x; } 2>/dev/null
        else
            # Log the user's intention to not install hooks into target repo
            echo -en "\n${FONT_COLOR_GREEN}NOT installing template. Exiting."
            echo -e "${ENDCOLOR}"
        fi
    } >> "${log_location}" 2>&1
}

################################################################################
# Function: update_project
################################################################################
# @brief: Update the global and current repos
# @params: 1) project name of target repo
update_project () {
    echo "TRACE: func:[${FUNCNAME[0]}], args:[${*}]" >> "${log_location}"
    ensure_template_directory_exists
    global_project_name=$(get_current_project "${template_gitdir}")
    exit_on_project_missing "${global_project_name}"
    update_global_templates "${global_project_name}"
    if [[ "${#}" -eq 1 ]]; then
        if [[ "${1}" = "_local" ]]; then
            project_name=$(get_current_project "${current_gitdir}")
        else
            project_name="${1}"
        fi
        exit_on_project_missing "${project_name}"
        update_local_templates "${project_name}"
    fi
    rotate_logs
    echo -en "${FONT_COLOR_GREEN}"
    echo -en "Machine's template updated successfully"
    echo -e  "${ENDCOLOR}"
}

################################################################################
##
## Main
##
################################################################################
if [[ "linux-gnu" = "${OSTYPE}" ]]; then
    FONT_COLOR_GREEN="\e[0;32m"
    ENDCOLOR="\033[0m"
fi
# Sanity Checks
template_dir=$(git config --path --get init.templatedir) || :
template_top_level=$(readlink -f "${template_dir}/..")
template_gitdir="${template_top_level}/.git"
if [[ (-z "${template_dir}") || (! -d "${template_top_level}") ]]; then
    echo -n "${0}: Error: Your global Git template dir is not set. " >&2
    echo -n "Run \"git config --global init.templatedir \$(pwd)'/template'" >&2
    echo "\" from the root of the bettercommit repo." >&2 && exit 1
fi
# Are we outside a Git repo?
if [[ ! $(git rev-parse --git-dir 2>/dev/null) ]]; then
    current_gitdir="${template_top_level}/.git"
else
    current_gitdir=$(git rev-parse --git-dir)
fi
current_gitdir=$(readlink -f "${current_gitdir}/hooks/..")

# Parse Command Line
long_opts="aliases,all,current,global,help,list,non-interactive,off,options"
long_opts="${long_opts},project:,update,version"
if ! getopts=$(getopt -o acghlnop:uvz -l "${long_opts}" -- "$@"); then
    echo "${0}: Error: couldn't parse arguments!" >&2
    usage
fi
eval set -- "$getopts"
interactive=0
template_namespace="bettercommit"
template_file_subdir="template/${template_namespace}"
log_dir="${template_top_level}/logs"
mkdir -p "${log_dir}"
log_location="${log_dir}/bettercommit.log"
TEMPLATE_BRANCH="master"
TEMPLATE_REMOTE="origin"
echo "---$(date '+%F %T')---" >> "${log_location}"
echo "SCRIPT_TRACE: args: [${*}]" >> "${log_location}"
while true; do
    case "$1" in
        -i|--aliases)         get_all_aliases; exit 0;;
        -a|--all)             get_all_projects; exit 0;;
        -c|--current)         get_current_project "${current_gitdir}" err;
                              exit 0;;
        -g|--global)          get_current_project "${template_gitdir}" err;
                              exit 0;;
        -h|--help)            print_help;;
        -l|--list)            get_all_projects; exit 0;;
        -n|--non-interactive) interactive=1;;
        -z|--off)             turn_framework_off; exit 0;;
        -o|--options)         echo "${OPTIONS_STRING}"; exit 0;;
        -p|--project)         update_project "${2}"; exit 0;;
        -u|--update)          update_project; exit 0;;
        -v|--version)         print_version; exit 0;;
        --)                   shift; break ;;
        *) echo "${0}: Error: processing args -- unrecognized option [${1}]" >&2
            usage;;
    esac
    shift
done
# No args
update_project _local
