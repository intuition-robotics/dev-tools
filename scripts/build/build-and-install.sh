#!/bin/bash

bashVersion=`bash --version | grep version | sed -E "s/.* version (.).*/\1/"`

source ${BASH_SOURCE%/*}/_generic-tools.sh

source ${BASH_SOURCE%/*}/../utils/tools.sh
source ${BASH_SOURCE%/*}/../utils/coloring.sh
source ${BASH_SOURCE%/*}/../utils/log-tools.sh
source ${BASH_SOURCE%/*}/../utils/error-handling.sh

paramColor=${BBlue}
valueColor=${BGreen}
function printUsage {
    local errorMessage=${1}

    packageNameParam="${paramColor}--packageName=${NoColor}"
    if [ "${packageName}" == "" ]; then
        packageNameParam="${packageNameParam}${valueColor}your.package.name.here${NoColor}"
    else
        packageNameParam="${packageNameParam}${valueColor}${packageName}${NoColor}"
    fi

    projectParam="${paramColor}--project=${NoColor}"
    if [ "${projectName}" == "" ]; then
        projectParam="${projectParam}${valueColor}you-project-name${NoColor}"
    else
        projectParam="${projectParam}${valueColor}${projectName}${NoColor}"
    fi

    buildParam="${paramColor}--build=${NoColor}${buildParam}${valueColor}build-type${NoColor}"
    deviceIdParam="${paramColor}--deviceId=${NoColor}${valueColor}your-device-id-here${NoColor}"
    uninstallParam="${paramColor}optional flags:${NoColor} ${valueColor}--uninstall${NoColor} | ${valueColor}--offline${NoColor} | ${valueColor}--nobuild${NoColor} | ${valueColor}--clear-cache${NoColor}"

    echo
    if [ "${errorMessage}" != "" ]; then
        logError "    ${errorMessage}"
        echo
    fi
    echo -e "   USAGE:"
    echo -e "     ${BBlack}bash${NoColor} ${BCyan}${0}${NoColor}"
    echo
    echo -e "               MUST:"
    echo -e "                         ${packageNameParam}"
    echo -e "                         ${projectParam}"
    echo -e "                         ${buildParam}"
    echo -e "                               |-- or use the --no-build flag"
    echo
    echo -e "           OPTIONAL:"
    echo -e "                         ${deviceIdParam}"
    echo -e "                         ${uninstallParam}"
    echo
    exit
}

if [ "${ANDROID_HOME}" == "" ]; then
    ANDROID_HOME="/Users/$USER/Library/Android/sdk"
fi

adbCommand=${ANDROID_HOME}/platform-tools/adb

build="Release"
build="Debug"

offline=""
nobuild=""

for (( lastParam=1; lastParam<=$#; lastParam+=1 )); do
    paramValue="${!lastParam}"
    if [[ "${paramValue}" =~ "--deviceId=" ]]; then
        deviceId=`echo "${paramValue}" | sed -E "s/--deviceId=(.*)/\1/"`
        deviceAdbCommand=" -s ${deviceId}"
        continue;
    fi

    if [[ "${paramValue}" =~ "--packageName=" ]]; then
        packageName=`echo "${paramValue}" | sed -E "s/--packageName=(.*)/\1/"`
        continue;
    fi

    if [[ "${paramValue}" =~ "--project=" ]]; then
        projectName=`echo "${paramValue}" | sed -E "s/--project=(.*)/\1/"`
        outputFolder="${projectName}/build/outputs/apk"
        continue;
    fi

    if [[ "${paramValue}" =~ "--build=" ]]; then
        _command=`echo "${paramValue}" | sed -E "s/--build=(.*)/\1/"`
        command="${command} assemble${_command}"
        continue;
    fi
done

for (( lastParam=1; lastParam<=$#; lastParam+=1 )); do
    paramValue="${!lastParam}"
    case ${paramValue} in
        "--clear-cache")
            execute "Clearing app cache:" "${adbCommand}${deviceAdbCommand} shell pm clear ${packageName}"
        ;;

        "--uninstall")
            execute "Uninstalling apk:" "${adbCommand}${deviceAdbCommand} uninstall ${packageName}"
        ;;

        "--offline")
            offline=" --offline"
        ;;

        "--no-build")
            noBuild=" --no-build"
        ;;
    esac
done
echo

if [ "${packageName}" == "" ]; then
    printUsage
fi

if [ ! -d "${projectName}" ]; then
    printUsage "No project module named: '${projectName}'"
fi

if [ "${command}" == "" ] && [ "${noBuild}" == "" ]; then
    printUsage "MUST specify build type or set flag --no-build"
fi

if [ "${outputFolder}" == "" ]; then
    printUsage
fi

if [ "${noBuild}" == "" ]; then

    if [ -e "${outputFolder}" ]; then
        execute "deleting output folder:" "rm -rf ${outputFolder}"
    fi

    execute "Building... " "bash gradlew ${command}${offline}"
    checkExecutionError "Build error..."
fi

pathToApk=`find "${outputFolder}" -name '*.apk'`
execute "Installing apk:" "${adbCommand}${deviceAdbCommand} install -r ${pathToApk}"
execute "Launching app:" "${adbCommand}${deviceAdbCommand} shell am start -n ${packageName}/com.nu.art.cyborg.ui.ApplicationLauncher -a android.intent.action.MAIN -c android.intent.category.LAUNCHER"