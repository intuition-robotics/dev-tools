#
#  This file is a part of nu-art projects development tools,
#  it has a set of bash and gradle scripts, and the default
#  settings for Android Studio and IntelliJ.
#
#     Copyright (C) 2017  Adam van der Kruk aka TacB0sS
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#          You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

#!/bin/bash

source ${BASH_SOURCE%/*}/../_core-tools/_source.sh
source ${BASH_SOURCE%/*}/_core-refactoring.sh

GIT_TAG="GIT:"

gitCheckoutBranch() {
  local branchName=${1}
  local isForced=${2}

  currentBranch=$(gitGetCurrentBranch)
  if [[ "${currentBranch}" == "${branchName}" ]]; then
    logInfo "${GIT_TAG} Already on branch: ${branchName}"
    return
  fi

  logInfo "${GIT_TAG} Checking out branch: ${branchName}"
  git checkout ${branchName}
  local ErrorCode=$?

  currentBranch=$(gitGetCurrentBranch)
  if [[ "${currentBranch}" != "${branchName}" ]] && [[ "${isForced}" == "true" ]]; then
    logWarning "${GIT_TAG} Could not find branch...  Creating a new branch named: ${branchName}"
    local output=$(git checkout -b ${branchName})
    ErrorCode=$?

    git push -u origin ${branchName}
    ErrorCode=$?
  fi
  return "${ErrorCode}"
}

git_verifyRepoExists() {
  local repoUrl=${1}

  logDebug "Verifying access to repo ${repoUrl}"
  local output=$(git ls-remote "${repoUrl}" 2>&1)
  [[ "${output}" =~ "Please make sure you have the correct access rights" ]] && return 2
  [[ "${output}" =~ "ERROR: Repository not found" ]] && return 1
  return 0
}

git_assertRepoAccess() {
  local repoUrl=${1}

  git_verifyRepoExists ${1}
  local status=$?

  [[ "${status}" == "2" ]] && throwError "Missing write permissions to repo: ${repoUrl}" 2
  [[ "${status}" != "0" ]] && throwError "Count not find repo: ${repoUrl}" 2
}

gitGetRepoUrl() {
  if [[ $(isMacOS) ]]; then
    git remote -v | grep push | perl -pe 's/origin\s//' | perl -pe 's/\s\(push\)//'
  else
    git remote -v | grep push | sed -E 's/origin\s//' | sed -E 's/\s\(push\)//'
  fi
}

getGitRepoName() {
  git remote -v | head -1 | perl -pe "s/.*:(.*?)(:?.git| ).*/\1/"
}

gitAddAll() {
  logInfo "${GIT_TAG} git add all"
  git add .
  return $?
}

gitAdd() {
  local toAdd="${1}"
  logInfo "${GIT_TAG} git add ${toAdd}"
  git add "${toAdd}"
}

gitSaveStash() {
  local stashName=${1}
  logInfo "${GIT_TAG} Stashing changes with message: ${stashName}"
  local result=$(git stash save "${stashName}")
  throwError "Error stashing changes"
}

gitStashPop() {
  logInfo "${GIT_TAG} Popping last stash"
  git stash pop
}

gitPullRepo() {
  local silent=${1}
  local currentBranch=$(gitGetCurrentBranch)
  if [[ ! "${currentBranch}" ]]; then
    logInfo "HEAD is detached... skipping repo"
    return
  fi

  if [[ "${silent}" == "true" ]]; then
    silent="--no-edit"
  else
    silent=
  fi

  git pull ${silent}
}

gitFetchRepo() {
  git fetch
}

gitRemoveSubmoduleFromCache() {
  local pathToFile=${1}
  logInfo "${GIT_TAG} Removing file from git: ${pathToFile}"
  git rm -rf --cache "${pathToFile}"
  throwError "Removing submodule $(getRunningDir) from cache"
}

gitCloneRepoByUrl() {
  local repoUrl=${1}
  local recursive=${recursive}
  logInfo "${GIT_TAG} Cloning repo from url: ${repoUrl}"
  git clone "${repoUrl}" ${recursive}
  throwError "Cloning repo!"
}

gitClearStash() {
  logInfo "${GIT_TAG} Clearing stash"
  git stash clear
}

gitCommit() {
  local message=$1
  logInfo "${GIT_TAG} Commit with message: ${message}"
  git commit -am "${message}"
  return $?
}

gitMerge() {
  local branch=origin/${1}
  logInfo "${GIT_TAG} Merging from ${branch}"
  git merge ${branch}
}

gitTag() {
  local tag=$1
  local message=$2

  logInfo "${GIT_TAG} Creating tag \"${tag}\" with message: ${message}"
  git tag -a "${tag}" -am "${message}" ${@:3}
  throwError "Setting Tag"
}

gitPush() {
  logInfo "${GIT_TAG} Pushing to origin..."
  local branchName=${1}
  local output=$(git push)
  local ErrorCode=$?
  if [[ "${branchName}" ]] && [[ "${output}" =~ "has no upstream branch" ]]; then
    git push --set-upstream origin ${branchName}
    ErrorCode=$?
  fi
  throwError "Pushing to ${branchName}" ${ErrorCode}
}

gitPushTags() {
  logInfo "${GIT_TAG} Pushing with tags to origin..."
  git push --tags
  throwError "Pushing with tags"
}

gitResetHard() {
  local origin=$([[ "${1}" == "true" ]] && echo "origin/")
  local branch=${2:-$(gitGetCurrentBranch)}
  git reset --hard "${origin}${branch}"
}

gitUpdateSubmodules() {
  local submodules=(${@})
  logInfo "${GIT_TAG} Updating Submodules: ${submodules[@]}"
  git submodule update --init ${submodules[@]}
  throwError "Updating submodules"
}

gitCommitAndTagAndPush() {
  local tag=$1
  local message=$2

  gitCommit "${message}"
  gitTag "${tag}" "${message}"
  gitPushTags
  gitPush
}

gitHasRepoChanged() {
  local status="$(git status)"
  [[ "${status}" =~ "Changes to be committed" ]] && echo "true"
  [[ "${status}" =~ "you are still merging" ]] && echo "true"
  echo "false"
}

gitListSubmodules() {
  local submodule
  local submodules=()

  if [[ ! -e ".gitmodules" ]]; then
    return
  fi

  while IFS='' read -r line || [[ -n "$line" ]]; do
    [[ ! "${line}" =~ "submodule" ]] && continue
    submodule=$(echo ${line} | sed -E 's/\[submodule "(.*)"\]/\1/')
    [[ ! "${submodule}" ]] && logError "Error extracting submodule name from line: ${line}" && exit 2
    [[ "${submodule}" == "dev-tools" ]] && continue

    submodules[${#submodules[*]}]="${submodule}"
  done < .gitmodules

  echo "${submodules[@]}"
}

gitGetCurrentBranch() {
  local onBranch=$(git status | grep "On branch" | sed -E "s/On branch //")
  echo "${onBranch}"
}

getAllChangedSubmodules() {
  local ALL_REPOS=($(git status | grep -e "modified: .*(" | sed -E "s/.*modified: (.*)\(.*/\1/"))
  local repos=()
  local toIgnore=(${1})
  for projectName in "${ALL_REPOS[@]}"; do
    [[ $(array_contains "${projectName}" "${toIgnore[@]}") ]] && continue

    repos+=(${projectName})
  done

  echo "${repos[@]}"
}

getAllConflictingSubmodules() {
  local ALL_REPOS=($(git status | grep -E "both modified: .*" | sed -E "s/.*both modified: (.*)/\1/"))
  local repos=()
  local toIgnore=(${1})
  for projectName in "${ALL_REPOS[@]}"; do
    [[ $(array_contains "${projectName}" "${toIgnore[@]}") ]] && continue
    [[ ! -e "${projectName}/.git" ]] && continue
    repos+=(${projectName})
  done

  echo "${repos[@]}"
}

getAllNoneProjectSubmodules() {
  local ALL_REPOS=($(listGitFolders))
  local repos=()
  local toIgnore=(${1})
  toIgnore+=($(gitListSubmodules))

  for projectName in "${ALL_REPOS[@]}"; do
    [[ $(array_contains "${projectName}" "${toIgnore[@]}") ]] && continue
    repos+=(${projectName})
  done

  echo "${repos[@]}"
}

hasUntrackedFiles() {
  [[ $(git status | grep "Untracked files:") ]] && echo true
}

hasConflicts() {
  if [[ $(git diff --check --diff-filter=m) ]] || [[ $(git status | grep "Unmerged files:") ]]; then echo true; else echo; fi
}

hasChanged() {
  if [[ $(git status | grep -E "Changes to be committed:|Changes not staged for commit:|you are still merging") ]]; then echo true; else echo; fi
}

hasCommits() {
  [[ $(git status | grep "Your branch is ahead") ]] && echo true
}

hasCommitsToPull() {
  [[ $(git status | grep "Your branch is behind") ]] && echo true
}

gitAssertOrigin() {
  local expectedOrigin=${1}
  local currentOrigin=$(gitGetRepoUrl)
  if [[ "${currentOrigin}" != "${expectedOrigin}" ]]; then
    throwError "Expected origin: ${expectedOrigin}\n Found Origin: ${currentOrigin}" 2
  fi
}

gitAssertTagExists() {
  local version=${1}
  git tag -l | grep "${version}"
}

gitAssertNoCommitsToPull() {
  if [[ $(hasCommitsToPull) ]]; then
    throwError "Repo is not up to date... you got to pull it baby..." 2
  fi
}

gitAssertRepoClean() {
  if [[ $(hasConflicts) ]] ; then
    echo "Repo has conflicts... Repo MUST be clean"
  fi
  if [[ $(hasUntrackedFiles) ]] ; then
    echo "Repo has untracked files... Repo MUST be clean"
  fi
  if [[ $(hasChanged) ]] ; then
    echo "Repo has changes... Repo MUST be clean"
  fi

  if [[ $(hasConflicts) ]] || [[ $(hasUntrackedFiles) ]] || [[ $(hasChanged) ]]; then
    bash ./dev-tools/scripts/git/git-status.sh -a
    throwError "Repo has changes... Repo MUST be clean" 2
  fi
}

gitAssertBranch() {
  local assertionBranches=(${@})

  local branch=$(gitGetCurrentBranch)
  if [[ $(array_contains ${branch} "${assertionBranches[@]}") ]]; then
    return
  fi

  throwError "In order to promote a app version you MUST be on one of the branches: ${assertionBranches[@]}!!!\n  found: branch ${branch} in $(getRunningDir)" 2
}

gitNoConflictsAddCommitPush() {
  local submoduleName=${1}
  local branchName=${2}
  local commitMessage=${3}
  local noPush=${4}

  if [[ $(hasConflicts) ]]; then
    git diff --check
    throwError "Submodule ${submoduleName} has conflicts... Terminating process!!" 2
  fi

  if [[ $(hasUntrackedFiles) ]]; then
    gitAddAll
    throwError "Error adding files"
  fi

  if [[ $(hasChanged) ]]; then
    gitCommit "${commitMessage}"
    throwError "Error committing changes"
  fi

  if [[ $(hasCommits) ]] && [[ ! "${noPush}" ]]; then
    gitPush ${branchName}
    throwError "Error pushing changes"
    if [[ $(hasCommits) ]]; then
      throwError "Failed to push... probably need to pull" 2
    fi
  fi
}

getSubmodulesByScope() {
  local scope=${1}
  local submodules=()
  local toIgnore=(${@:2})

  case "${scope}" in
  "external")
    submodules=($(getAllNoneProjectSubmodules "${toIgnore[@]}"))
    ;;

  "changed")
    submodules=($(getAllChangedSubmodules "${toIgnore[@]}"))
    submodules+=($(getAllConflictingSubmodules "${toIgnore[@]}"))
    ;;

  "all")
    submodules=($(listGitFolders "${toIgnore[@]}"))
    ;;

  "project")
    submodules=($(gitListSubmodules))
    ;;

  "conflict")
    submodules=($(getAllConflictingSubmodules "${toIgnore[@]}"))
    ;;

  *)
    logError "Unsupported submodule resolution type"
    exit 1
    ;;
  esac
  echo "${submodules[@]}"
}
