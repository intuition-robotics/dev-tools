#!/bin/bash

FrontendPackage() {
  extends class NodePackage

  _setEnvironment() {
    [[ ! "${ts_setEnv}" ]] && return

    #    TODO: iterate on all source folders
    logDebug "Setting ${folderName} env: ${envType}"
    copyConfigFile "./.config/config-ENV_TYPE.ts" "./src/main/config.ts" true "${envType}" "${fallbackEnv}"
  }

  _compile() {
    [[ ! "${ts_compile}" ]] && return

    logInfo "Compiling: ${folderName}"

    npm run build
    throwWarning "Error compiling: ${folderName}"
  }

  _launch() {
    [[ ! "$(array_contains "${folderName}" "${ts_launch[@]}")" ]] && return

    logInfo "Launching: ${folderName}, app is: ${ts_feApp}"
    npm run launch -- --name="${ts_feApp}"
  }

  _install() {
    [[ ! "${ts_installPackages}" ]] && [[ ! "${ts_updatePackages}" ]] && return

    if [[ ! -e "./.config/ssl/server-key.pem" ]]; then
      createDir "./.config/ssl"
      bash ../dev-tools/scripts/utils/generate-ssl-cert.sh --output=./.config/ssl
    fi

    this.NodePackage.install ${@}
  }
}
