#!/bin/bash
CONST_DOT_ENV_FILE=".env"

BackendPackage() {
  extends class NodePackage

  _deploy() {
    [[ ! "$(array_contains "${folderName}" "${ts_deploy[@]}")" ]] && return

    firebase_json=$(<../firebase.js.json)
    hosting_array=$(echo "$firebase_json" | sed -n '/"hosting": \[/,/^\s*\],$/p')

    local target_names=()

    while read -r -d '}' target; do
      public_directory=$(echo "$target" | grep -o '"public": "[^"]*' | cut -d'"' -f4)
      [[ ! "$(array_contains "$(echo "$public_directory" | cut -d'/' -f1)" "${ts_deploy[@]}")" ]] && continue

      # Extract the "target" value
      target_name=$(echo "$target" | grep -o '"target": "[^"]*' | cut -d'"' -f4)
      if [ -n "$target_name" ]; then
        $(resolveCommand firebase) target:apply hosting "$target_name" "$target_name"
        target_names+=("$target_name")
      fi
    done <<< "$hosting_array"

    $(resolveCommand firebase) deploy
    throwError "Error while deploying app"
  }

  _copySecrets() {
    [[ ! "${ts_copySecrets}" ]] && return

    if [[ ! -e "./src/main/secrets" ]]; then
      return 0
    fi

    bannerInfo "Copy Secrets"

    logInfo "Copying Secrets: ${folderName}"
    for i in `cat ./src/main/secrets`; do
        # Set comma as delimiter
        IFS='='

        read -a strarr <<< "$i"
        local secretKey="${strarr[0]}"
        local secret=$(gcloud secrets versions access 1 --secret="${secretKey}" --project=ir-secrets)
        local replacementString="${strarr[1]}=${secret}"
        local isThereAValue=false
        if [[ ! -e "${CONST_DOT_ENV_FILE}" ]]; then
          isThereAValue=false
        else
          local condition=$(cat ${CONST_DOT_ENV_FILE} | grep -E "${strarr[1]}")
          if [[ "${condition}" ]]; then
            isThereAValue=true
          else
            isThereAValue=false
          fi
        fi
        if [[ "${isThereAValue}" = true ]]; then
          file_replace "^"${strarr[1]}"(.*)$" "${replacementString}" ${CONST_DOT_ENV_FILE} "" "%"
        else
          echo "${replacementString}" >> ${CONST_DOT_ENV_FILE}
        fi

        logInfo "Copied Secret: ${strarr[0]} from ir-secrets into ${strarr[1]} in .env"

      done
  }

  _setEnvironment() {
    [[ ! "${ts_setEnv}" ]] && return

    logInfo "Setting ${folderName} env: ${envType}"

    local firebaseProject="$(getJsonValueForKey ../.firebaserc default)"
    this.verifyFirebaseProjectIsAccessible "${firebaseProject}"
    $(resolveCommand firebase) use "${firebaseProject}"

    #    TODO: iterate on all source folders
    copyConfigFile "./.config/config-ENV_TYPE.ts" "./src/main/config.ts" true "${envType}" "${fallbackEnv}"

    copyConfigFromFirebase

    copyConfigFile "./.config/secrets-ENV_TYPE" "./src/main/secrets" true "${envType}" "${fallbackEnv}"
  }

  _verifyFirebaseProjectIsAccessible() {
     local firebaseProject=${1}

     logDebug "Verifying You are logged in to firebase tools...'"
     [[ "${USER,,}" != "jenkins" ]] && $$(resolveCommand firebase) login:ci
     logDebug

     logDebug "Verifying access to firebase project: '${firebaseProject}'"
     local output=$($(resolveCommand firebase) projects:list | grep "${firebaseProject}" 2>&1)
     if [[ "${output}" =~ "Command requires authentication" ]]; then
       logError "    User not logged in"
       return 2
     fi

     # shellcheck disable=SC2076
     if [[ ! "${output}" =~ "${firebaseProject}" ]]; then
       logError "    No access found"
       return 1
     fi
     return 0
   }

  copyConfigFromFirebase() {
    if [ ! -d ./src/main/configs ]; then
      mkdir ./src/main/configs
    fi
    if [ -f ./src/main/configs/default.json ]; then
      rm ./src/main/configs/default.json
    fi
    $(resolveCommand firebase) database:get /_config/default >> ./src/main/configs/default.json

    res=$($(resolveCommand firebase) database:get /_config/${envType})
    if [[ ${res} =~ null ]] && [ ! -z $fallbackEnv ]; then
      res=$($(resolveCommand firebase) database:get /_config/${fallbackEnv})
    fi

    if [[ ${res} =~ null ]]; then
      res="{}"
    fi

    if [ -f ./src/main/configs/env.json ]; then
      rm ./src/main/configs/env.json
    fi
    echo $res >> ./src/main/configs/env.json
  }

  _compile() {
    this.copySecrets

    [[ ! "${ts_compile}" ]] && return

    logInfo "Compiling: ${folderName}"

    npm run build
    throwWarning "Error compiling: ${folderName}"
  }

  _launch() {
    [[ ! "$(array_contains "${folderName}" "${ts_launch[@]}")" ]] && return

    logInfo "Launching: ${folderName}"
    npm run launch
  }

  _install() {
    [[ ! "${ts_installPackages}" ]] && [[ ! "${ts_updatePackages}" ]] && return

    logInfo "Linking Dep: ${folderName}"
    logInfo

    for lib in ${@}; do
      [[ "${lib}" == "${_this}" ]] && break
      local libPath="$("${lib}.path")"
      local libFolderName="$("${lib}.folderName")"
      local libPackageName="$("${lib}.packageName")"

      [[ ! "$(cat package.json | grep "${libPackageName}")" ]] && continue

      local backendDependencyPath="./.dependencies/${libFolderName}"
      createDir "${backendDependencyPath}"
      cp -rf "${libPath}/${libFolderName}/${outputDir}"/* "${backendDependencyPath}/"
    done

    this.NodePackage.install ${@}
  }

  _purge() {
    [[ ! "${ts_purge}" ]] && return
    this.NodePackage.purge
    deleteDir ".dependencies"
  }
}
