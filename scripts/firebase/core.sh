#!/bin/bash
storeFirebasePath() {
  CONST_Firebase=$(resolveCommand firebase)
  echo $CONST_Firebase
}

verifyFirebaseProjectIsAccessible() {
  local firebaseProject=${1}

  logDebug "Verifying You are logged in to firebase tools...'"
  if [[ "${USER,,}" != "jenkins" ]] && [[ "${USER,,}" != "runner" ]]; then
    ### NOT NEEDED IN K8S
    # Check for authentication credentials
    if [[ ! "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
      # Try to use gcloud application-default credentials
      local gcloudCreds="${HOME}/.config/gcloud/application_default_credentials.json"
      if [[ -f "${gcloudCreds}" ]]; then
        export GOOGLE_APPLICATION_CREDENTIALS="${gcloudCreds}"
        logDebug "Using gcloud application default credentials"
      else
        logError "No authentication credentials found!"
        logError "Please run: gcloud auth application-default login"
        logError "This is a one-time setup that works across all projects."
        return 2
      fi
    fi
  fi

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
