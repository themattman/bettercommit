#!/usr/bin/env bash
#
# Store location of every repo that uses the bettercommit framework on local
#  machine to a server. Allows framework to turn itself off.
#
# Author:  Matthew Kneiser
# Date:    03/21/2016
# Purpose: Backup the all_user_repos file on the remote server
set -e

exit_error () {
    if [[ -n "${git_str}" ]]; then
        if [[ $(git ${git_str} rev-parse --abbrev-ref HEAD 2>/dev/null) != "master" ]]; then
            echo "Reverting to the 'master' branch" >&2
            git ${git_str} checkout -f master || echo "Error: Checking out 'master' branch failed." >&2
            \cp -f ~/.bettercommit "${template_worktree}/all_user_repos"
        fi
    fi
    echo "$0 Error: exiting." >&2
}
trap exit_error ERR

template_worktree=$(readlink -f "$(git config --get --path init.templatedir)/..")
template_gitdir=$(readlink -f "${template_worktree}/.git")
git_str="--git-dir=${template_gitdir} --work-tree=${template_worktree}"
git_config="--file=${template_gitdir}/config"
echo "git_str=[${git_str}]"
echo "git_config=[${git_config}]"
set -x
remote_url=$(git config "${git_config}" --get remote.origin.url)
echo "remote_url: [${remote_url}]"

git ${git_str} pull --strategy=ours origin master

# Ensure that ~/.bettercommit is an exact duplicate of all_user_repos
#   ((Prefer all_user_repos if they differ))
diff -q ~/.bettercommit "${template_worktree}/all_user_repos" >/dev/null 2>&1 || rc=1
if [[ "${rc}" -eq 1 ]]; then
    \cp -f "${template_worktree}/all_user_repos" ~/.bettercommit
    unset -v rc
fi

# TODO: Use git-stash in the future to avoid exiting early
git ${git_str} diff-index --quiet HEAD
if [[ "${?}" -ne 0 ]]; then
    echo "${0}: Error: changes in bettercommit repo exist." && exit 1
fi

# Check to see if a branch by the name of $USER exists on the server
#   ((That way we can create it if it does not exist))
git ${git_str} ls-remote --exit-code --heads "${remote_url}" "${USER}" || branch_no_exist=1
if [[ -n "${branch_no_exist}" ]]; then
    new_push="-u"
    new_checkout="-f"
    echo "<<new branch>>"
    git ${git_str} checkout --orphan "${USER}"
    git ${git_str} rm -r --cached "${template_worktree}"
else
    echo "<<branch exists>>"
    git ${git_str} checkout "${USER}"
    \cp -f ~/.bettercommit "${template_worktree}/all_user_repos"
fi

if [[ ! $(git ${git_str} diff --quiet "${template_worktree}/all_user_repos") ]]; then
    git ${git_str} add --force "${template_worktree}/all_user_repos"
    git ${git_str} commit --no-verify -m "Backing up all_user_repos @ [$(date)]"

    # Disable pre-push hook for push...
    if [[ -x "${template_gitdir}/hooks/pre-push" ]]; then
        chmod u-x "${template_gitdir}/hooks/pre-push"
    fi
    git ${git_str} push ${new_push} origin "${USER}" || { chmod u+x "${template_gitdir}/hooks/pre-push" && false; }
    # Reset pre-push hook
    if [[ -f "${template_gitdir}/hooks/pre-push" ]]; then
        chmod u+x "${template_gitdir}/hooks/pre-push"
    fi

    git ${git_str} checkout ${new_checkout} master
    \cp -f ~/.bettercommit "${template_worktree}/all_user_repos"
    echo "Successfully backed up the all_user_repos file."
else
    echo "No new repos have installed the framework. No need to push."
fi
set +x
