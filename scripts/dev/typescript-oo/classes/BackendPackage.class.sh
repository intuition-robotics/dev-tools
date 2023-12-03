#!/bin/bash
CONST_DOT_ENV_FILE=".env"

BackendPackage() {
  extends class NodePackage

  _deploy() {
    _copySecrets

    [[ ! "$(array_contains "${folderName}" "${ts_deploy[@]}")" ]] && return

    logInfo "Deploying: ${folderName}"
    ${CONST_Firebase} deploy --only functions
    throwWarning "Error while deploying functions"
    logInfo "Deployed: ${folderName}"
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
    #    TODO: iterate on all source folders
    logDebug "Setting ${folderName} env: ${envType}"
    copyConfigFile "./.config/config-ENV_TYPE.ts" "./src/main/config.ts" true "${envType}" "${fallbackEnv}"

    copyConfigFromFirebase

    copyConfigFile "./.config/secrets-ENV_TYPE" "./src/main/secrets" true "${envType}" "${fallbackEnv}"
  }

  copyConfigFromFirebase() {
    if [ ! -d ./src/main/configs ]; then
      mkdir ./src/main/configs
    fi
    if [ -f ./src/main/configs/default.json ]; then
      rm ./src/main/configs/default.json
    fi
    ${CONST_Firebase} database:get /_config/default >> ./src/main/configs/default.json

    res=$(${CONST_Firebase} database:get /_config/${envType})
    if [[ ${res} =~ null ]] && [ ! -z $fallbackEnv ]; then
      res=$(${CONST_Firebase} database:get /_config/${fallbackEnv})
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
      ln -s "${libPath}/${libFolderName}/${outputDir}"/* "${backendDependencyPath}/"
    done

    this.NodePackage.install ${@}
  }

  _purge() {
    [[ ! "${ts_purge}" ]] && return
    this.NodePackage.purge
    deleteDir ".dependencies"
  }
}
