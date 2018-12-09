#!/bin/bash


source ${BASH_SOURCE%/*}/../utils/tools.sh
source ${BASH_SOURCE%/*}/../utils/coloring.sh
source ${BASH_SOURCE%/*}/../utils/log-tools.sh
source ${BASH_SOURCE%/*}/../utils/error-handling.sh
source ${BASH_SOURCE%/*}/git-core.sh
source ${BASH_SOURCE%/*}/../_fun/signature.sh

paramColor=${BRed}
projectsToIgnore=("dev-tools")

function extractParams() {
    echo
    logInfo "Process params: "
    for paramValue in "${@}"; do
        logDebug "  param: ${paramValue}"

        case "${paramValue}" in
            "--branch="*)
                branchName=`echo "${paramValue}" | sed -E "s/--branch=(.*)/\1/"`
            ;;

            "--message="*)
                commitMessage=`echo "${paramValue}" | sed -E "s/--message=(.*)/\1/"`
            ;;
        esac
    done

    echo
    logInfo "Running with params:"
    logDebug "  branchName: ${branchName}"
    logDebug "  commitMessage: ${commitMessage}"
}

function printUsage() {
    echo
    echo -e "   USAGE:"
    echo -e "     ${BBlack}bash${NoColor} ${BCyan}${0}${NoColor} ${branchName} ${commitMessage}"
    echo -e "  "
    echo
    exit 0
}

function verifyRequirement() {
    local missingParamColor=${BRed}
    local existingParamColor=${BBlue}

    local missingData=false
    if [ "${branchName}" == "" ]; then
        branchName="${missingParamColor}new-branch-name"
        missingData=true
    fi

    if [ "${commitMessage}" == "" ]; then
        commitMessage="${missingParamColor}Commit message here"
        missingData=true
    fi

    if [ "${missingData}" == "true" ]; then
        branchName="--branch=${existingParamColor}${branchName}${NoColor}"
        commitMessage="--message=\"${existingParamColor}${commitMessage}${NoColor}\""
        printUsage
    fi
}

extractParams "$@"
verifyRequirement

changedSubmodules=(`getAllChangedSubmodules "${projectsToIgnore[@]}"`)
echo
echo "changedSubmodules: ${changedSubmodules[@]}"

if [ "${changedSubmodules#}" == "0" ]; then
    exit 0
fi

currentBranch=`gitGetCurrentBranch`
if [ "${currentBranch}" != "${branchName}" ]; then
    logError "Main Repo MUST be on branch: ${branchName}"
    exit 1
fi

signature
bannerDebug "Main Repo"
gitCheckoutBranch ${branchName} true

for submoduleName in "${changedSubmodules[@]}"; do
    echo
    bannerDebug "${submoduleName}"
    cd ${submoduleName}
        pwd
        gitCheckoutBranch ${branchName} true
        gitAddAll
        gitCommit "${commitMessage}"
        gitPush ${branchName}
    cd ..
done

echo
bannerDebug "Main Repo"
gitAddAll
gitCommit "${commitMessage}"
gitPush ${branchName}
