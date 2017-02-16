#!/usr/bin/env bash
#
# Script to make first time installation of this repo easy.
#
# Author:  Matthew Kneiser
# Date:    7/18/2015
# Purpose: Install the templates
set -e


################################################################################
##
## Help Output and Usage
##
################################################################################
HELP_TEXT="Usage: $0 [OPTION]
Install the Git template repo on your machine
(convenience script)

Options:
\t-h \tprint this help
\t-p \tproject name to use [default: 'default']
"
print_help () { echo -e "${HELP_TEXT}"; exit 0; }
usage () { echo "Usage: $0 [OPTION] " >&2; exit 1; }

################################################################################
# Function: warn_user_on_exit
################################################################################
# This is the final line of defense for reporting errors to user.
# Should only be printed when exiting this script.
warn_user_on_exit () {
    echo "${0}: Error: Something went wrong." >&2
}
trap warn_user ERR

################################################################################
# Function: get_user_acct
################################################################################
get_user_acct() {
    user_acct=$(whoami)
    if [[ (-z "${user_acct}") || ("${user_acct}" = "root") ]]; then
        if [[ (-n "${USER}") && ("${USER}" != "root") ]]; then
            user_acct="${USER}"
        else
            echo "Error: No valid user account to send log rotation emails to. Set \$USER to fix." >&2
            exit 1
        fi
    fi
}

################################################################################
##
## Utility Functions
##
################################################################################

################################################################################
# Function: setup_logs
################################################################################
setup_logs () {
    log_location="${template_top_level}/logs"
    logrotate_config_file_name="bettercommit.conf"
    log_filepath=$(readlink -f "${log_location}/${logrotate_config_file_name}")
    echo "\"${log_filepath%.conf}.log\"" > "${log_filepath}"
    get_user_acct
    sed s/mail/"mail ${USER_EMAIL}"/ "${log_filepath}.setup" \
        >> "${log_filepath}"
}

################################################################################
# Function: setup_git_config
################################################################################
setup_git_config () {
    # Template
    git config --global init.templatedir "$(pwd)/template"
    # Aliases
    echo "Installing git aliases for this framework..."
    exec 3<git_aliases.txt
    while read -u 3 LINE; do
        # Ignore blank lines and comments in the alias file
        if [[ ! ${LINE:0:1} == "#" && -n $LINE ]]; then
            git_alias_name=${LINE%,*}
            git_alias_command=${LINE#*,}
            set -x
            git config --global "alias.$git_alias_name" "$git_alias_command"
            { set +x; } 2>/dev/null
        fi
    done
}

################################################################################
# Function: install_framework
################################################################################
install_framework () {
    mkdir -p "${template_top_level}/template"
    if [ -n "${project}" ]; then
        "${template_top_level}/update.sh" -p "${project}"
    else
        "${template_top_level}/update.sh"
    fi
}

################################################################################
##
## Main
##
################################################################################
if [ ! -x update.sh ]; then
    echo "${0}: Error: cannot find or execute update.sh" >&2 && exit 1
fi

long_opts="project:,help"
if ! getopts=$(getopt -o p:h -l $long_opts -- "$@"); then
    echo "${0}: Error: couldn't parse arguments!" >&2
    usage
fi

eval set -- "$getopts"
while true; do
    case "$1" in
        -p|--project) project=$2; echo -e "\nPROJECT=[${project}]\n"; shift;;
        -h|--help) print_help;;
        --) shift ; break ;;
        *) echo "${0}: Error processing args -- unrecognized option [${1}]" >&2
            usage;;
    esac
    shift
done

expected_template_git_dir=$(readlink -f "$(dirname "${0}")"/.git)
if [[ ! -d $expected_template_git_dir ]]; then
    echo "${0}: Error: install.sh not sitting inside the bettercommit repo" >&2 && exit 1
fi
template_top_level=$(dirname "${expected_template_git_dir}")

setup_logs
setup_git_config
install_framework

echo -e "\nSuccess! Go forth and git well!"
