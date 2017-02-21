#!/usr/bin/env bash
#
# Backup the all_user_repos file on the remote server
#
# Author: Matthew Kneiser
# Date:   03/21/2016
set -e
source "$(dirname ${0})/utils/readlink.sh"

exit_error () {
    if [[ -n $git_str ]]; then
        if [[ $(git $git_str rev-parse --abbrev-ref HEAD 2>/dev/null) != "master" ]]; then
            echo "Reverting to the 'master' branch" >&2
            git $git_str checkout -f master || echo "Error: Checking out 'master' branch failed." >&2
            \cp -f ${HOME}/.bettercommit ${template_work_tree}/all_user_repos
        fi
    fi
    echo "$0 Error: exiting." >&2
}
trap exit_error ERR

template_work_tree=$(readlink -f $(git config --get --path init.templatedir)/..)
template_dir=$(readlink -f $template_work_tree/.git)
git_str="--git-dir=$template_dir --work-tree=$template_work_tree"
git_config="--file=$template_dir/config"
echo "git_str=[${git_str}]"
echo "git_config=[${git_config}]"
set -x
remote_url=$(git config "$git_config" --get remote.origin.url)
echo "remote_url: [${remote_url}]"

git $git_str fetch origin

# Ensure that ~/.bettercommit is an exact duplicate of all_user_repos
#   ((Prefer all_user_repos if they differ))
diff -q ~/.bettercommit ${template_work_tree}/all_user_repos &> /dev/null || rc=1
if [[ $rc -eq 1 ]]; then
    \cp -f ${template_work_tree}/all_user_repos ~/.bettercommit
    unset -v rc
fi

# Check to see if a branch by the name of $USER exists on the server
#   ((That way we can create it if it does not exist))
git $git_str ls-remote --exit-code --heads $remote_url $USER || branch_no_exist=1
if [[ -n $branch_no_exist ]]; then
    new_push="-u"
    new_checkout="-f"
    echo "<<new branch>>"
    git $git_str checkout --orphan $USER
    git $git_str rm -r --cached ${template_work_tree}
else
    echo "<<branch exists>>"
    git $git_str checkout $USER
    \cp -f ${HOME}/.bettercommit ${template_work_tree}/all_user_repos
fi

if [[ ! $(git $git_str diff --quiet ${template_work_tree}/all_user_repos) ]]; then
    git $git_str add --force ${template_work_tree}/all_user_repos
    git $git_str commit --no-verify -m "Backing up all_user_repos @ [$(date)]"
    template_location=$(git config --global --get init.templatedir)

    # Disable pre-push hook for push...
    if [[ -x ${template_dir}/hooks/pre-push ]]; then
        chmod u-x ${template_dir}/hooks/pre-push
    fi
    git $git_str push $new_push origin $USER || { chmod u+x ${template_dir}/hooks/pre-push && false; }
    # Reset pre-push hook
    if [[ -f ${template_dir}/hooks/pre-push ]]; then
        chmod u+x ${template_dir}/hooks/pre-push
    fi

    git $git_str checkout $new_checkout master
    \cp -f ${HOME}/.bettercommit ${template_work_tree}/all_user_repos
    echo "Successfully backed up the all_user_repos file."
else
    echo "No new repos have installed the framework. No need to push."
fi
set +x
