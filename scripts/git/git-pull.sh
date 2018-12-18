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

source ${BASH_SOURCE%/*}/_core.sh

pids=()
projectsToIgnore=("dev-tools")
stashName="pull-all-script"
scope="changed"
runningDir=${PWD##*/}
mainRepoBranch=`gitGetCurrentBranch`

params=(stashName scope mainRepoBranch)

function extractParams() {
    for paramValue in "${@}"; do
        case "${paramValue}" in
            "--stash-name="*)
                stashName=`echo "${paramValue}" | sed -E "s/--stash-name=(.*)/\1/"`
            ;;

            "--all")
                scope="all"
            ;;

            "--project")
                scope="project"
            ;;

            "--debug")
                debug="true"
            ;;
        esac
    done
}

if [ ! "${mainRepoBranch}" ]; then
    logError "Main repo head detached... "
    exit 1
fi

extractParams "$@"

signature "Pull repo"
printDebugParams ${debug} "${params[@]}"

function execute() {
    local submoduleBranch=`gitGetCurrentBranch`
    local runningDir=${PWD##*/}

    if [ "${mainRepoBranch}" != "${submoduleBranch}" ]; then
        cd ..
            local submodules=(`getSubmodulesByScope "project" "${projectsToIgnore[@]}"`)
            # Make sure that the submodule is a part of the project before updating its pointer
            for submodule in "${submodules[@]}"; do
                if [ "${runningDir}" == "${submodule}" ]; then
                    git submodule update ${runningDir}
                fi
            done
        cd - > /dev/null
        return
    fi
    local dirName=${PWD##*/}

    local isClean=`git status | grep "nothing to commit.*"`
    if [ ! "${isClean}" ]; then
        logDebug "${dirName} - Stashing with message: ${stashName}"
        result=`git stash save "${stashName}"`
    fi

   logDebug "${dirName} - Pulling..."
    gitPullRepo true

    if [ ! "${isClean}" ] && [ "${result}" != "No local changes to save" ]; then
        gitStashPop
    fi
   logInfo "${dirName} - Pulled"
}

function processSubmodule() {
    local mainModule=${1}
    local submodules=(`getSubmodulesByScope ${scope} "${projectsToIgnore[@]}"`)
    if [ "${#submodules[@]}" -gt "0" ]; then
        execute
    else
        execute &
        pid=$!
        pids+=(${pid})
    fi

    for submodule in "${submodules[@]}"; do
        cd ${submodule}
            processSubmodule "${mainModule}/${submodule}"
        cd ..
    done
}

processSubmodule "${runningDir}"

for pid in "${pids[@]}"; do
    wait ${pid}
done

