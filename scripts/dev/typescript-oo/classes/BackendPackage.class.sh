#!/bin/bash
CONST_DOT_ENV_FILE=".env"

BackendPackage() {
  extends class NodePackage

  _deploy() {
    [[ ! "$(array_contains "${folderName}" "${ts_deploy[@]}")" ]] && return

    logInfo "Deploying: ${folderName}"
    ${CONST_Firebase} deploy --only functions
    throwWarning "Error while deploying functions"
    logInfo "Deployed: ${folderName}"
  }

  _copySecrets() {
    if [[ ! -e "./src/main/secrets" ]]; then
      return 0
    fi

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
    logInfo "Compiling: ${folderName}"

    npm run build
    throwWarning "Error compiling: ${folderName}"

  }

  _generate() {
    [[ ! "$(array_contains "${folderName}" "${ts_generate[@]}")" ]] && return

    logInfo "Generating: ${folderName}"
  }

  _lint() {
    logInfo "Linting: ${folderName}"

    npm run lint
    throwWarning "Error linting: ${folderName}"
  }

  _launch() {
    [[ ! "$(array_contains "${folderName}" "${ts_launch[@]}")" ]] && return

    logInfo "Launching: ${folderName}"
    npm run launch
  }

  _clean() {
    this.NodePackage.clean
    deleteDir ".dependencies"
  }
}
