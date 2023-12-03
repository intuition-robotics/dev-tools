#!/bin/bash

FrontendPackage() {
  extends class NodePackage

  _deploy() {
    [[ ! "$(array_contains "${folderName}" "${ts_deploy[@]}")" ]] && return

    logInfo "Deploying: ${folderName}"

    firebase_json=$(<../firebase.json)
    hosting_array=$(echo "$firebase_json" | sed -n '/"hosting": \[/,/^\s*\],$/p')

    local target_names=()

    while read -r -d '}' target; do
      public_directory=$(echo "$target" | grep -o '"public": "[^"]*' | cut -d'"' -f4)
      [[ ! "$(array_contains "$(echo "$public_directory" | cut -d'/' -f1)" "${ts_deploy[@]}")" ]] && continue

      # Extract the "target" value
      target_name=$(echo "$target" | grep -o '"target": "[^"]*' | cut -d'"' -f4)
      if [ -n "$target_name" ]; then
        ${CONST_Firebase} target:apply hosting "$target_name" "$target_name"
        target_names+=("$target_name")
      fi
    done <<< "$hosting_array"

    if [[ ${#target_names[@]} == 1 ]]; then
      ${CONST_Firebase} deploy --only hosting:"${target_names[0]}"
    else
      ${CONST_Firebase} deploy --only hosting
    fi

    throwWarning "Error while deploying hosting"
    logInfo "Deployed: ${folderName}"
  }

  _setEnvironment() {
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
