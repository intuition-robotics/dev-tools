#!/bin/bash

FrontendPackage() {
  extends class NodePackage

  _deploy() {
    [[ ! "$(array_contains "${folderName}" "${ts_deploy[@]}")" ]] && return

    logInfo "Deploying: ${folderName}"

    getJsonValueForKeyAndIndex() {
      local fileName=${1}
      local key=${2}
      local i=${3}
      if [[ ! "${i}" ]]; then
          i=1
      fi

      local value=$(cat "${fileName}" | grep "\"${key}\":" | head "-${i}" | tail -1 | sed -E "s/.*\"${key}\".*\"(.*)\".*/\1/")
      echo "${value}"
    }

    local target1="$(getJsonValueForKeyAndIndex "../firebase.json" "target" 1)"
    ${CONST_Firebase} target:apply hosting "${target1}" "${target1}"

    local target2="$(getJsonValueForKeyAndIndex "../firebase.json" "target" 2)"
    ${CONST_Firebase} target:apply hosting "${target2}" "${target2}"

    ${CONST_Firebase} deploy --only hosting
    throwWarning "Error while deploying hosting"
    logInfo "Deployed: ${folderName}"
  }

  _setEnvironment() {
    #    TODO: iterate on all source folders
    logDebug "Setting ${folderName} env: ${envType}"
    copyConfigFile "./.config/config-ENV_TYPE.ts" "./src/main/config.ts" true "${envType}" "${fallbackEnv}"
  }

  _compile() {
    logInfo "Compiling: ${folderName}"

    npm run build
    throwWarning "Error compiling: ${folderName}"
  }

  _lint() {
    logInfo "Linting: ${folderName}"

    npm run lint
    throwWarning "Error linting: ${folderName}"
  }

  _launch() {
    [[ ! "$(array_contains "${folderName}" "${ts_launch[@]}")" ]] && return

    this.link $@

    logInfo "Launching: ${folderName}, app is: ${ts_feApp}"
    npm run launch -- --name="${ts_feApp}"
  }

  _install() {
    if [[ ! -e "./.config/ssl/server-key.pem" ]]; then
      createDir "./.config/ssl"
      bash ../dev-tools/scripts/utils/generate-ssl-cert.sh --output=./.config/ssl
    fi

    this.NodePackage.install ${@}
  }

}
