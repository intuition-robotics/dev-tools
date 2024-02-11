#!/bin/bash

NodePackage() {

  declare path
  declare folderName
  declare packageName
  declare version
  declare outputDir
  declare outputTestDir

  _prepare() {
    packageName="$(getJsonValueForKey "${folderName}/package.json" "name")"
  }

  _printDependencyTree() {
    logInfo "Dependencies: ${folderName}"
    createDir "../.trash/dependencies"
    npm list > "../.trash/dependencies/${folderName}.txt"
  }

  _assertNoCyclicImport() {
    logInfo "Assert Circular Imports: ${folderName}"
    npx madge --circular --extensions ts ./src/main
    throwError "Error found circular imports:  ${module}"
  }

  _purge() {
    [[ ! "${ts_purge}" ]] && return

    logInfo "Purging: ${folderName}"
    deleteDir node_modules
    [[ -e "package-lock.json" ]] && rm package-lock.json
  }

  _install() {
    [[ ! "${ts_installPackages}" ]] && [[ ! "${ts_updatePackages}" ]] && return

    createFolder "${outputDir}"
    copyFileToFolder package.json "${outputDir}"

    logDebug "Setting version '${version}' to module: ${folderName}"
    setVersionName "${version}" "${outputDir}/package.json"

    if [[ "${ts_updatePackages}" ]]; then
      logInfo "Updating: ${folderName}"
      npm update
    else
      logInfo "Installing: ${folderName}"
      npm install
    fi
  }

  _clean() {
    [[ ! "${ts_clean}" ]] && return

    logInfo "Cleaning: ${folderName}"

    [[ ! "${outputTestDir}" ]] && throwError "No test output directory specified" 2
    [[ ! "${outputDir}" ]] && throwError "No output directory specified" 2

    createFolder "${outputDir}"
    clearFolder "${outputDir}"

    createFolder "${outputTestDir}"
    clearFolder "${outputTestDir}"
  }

  _compile() {
    [[ ! "${ts_compile}" ]] && return

    logInfo "Compiling: ${folderName}"

    npm run build
    throwWarning "Error compiling: ${folderName}"
  }

  _lint() {
    [[ ! "${ts_lint}" ]] && return

    logInfo "Linting: ${folderName}"
    npm run lint
    throwError "Error while linting: ${folderName}"
  }

  _test() {
    [[ ! "${ts_runTests}" ]] && return
    [[ ! "${testServiceAccount}" ]] && throwError "MUST specify path to a test service account" 2

    [[ ! -e "./src/test/tsconfig.json" ]] && logVerbose "./src/test/tsconfig.json was not found... skipping test phase" && return 0
    [[ "${testServiceAccount}" ]] && [[ ! -e "${testServiceAccount}" ]] && throwError "Service account cannot be resolved from path: ${testServiceAccount}" 2

    export GOOGLE_APPLICATION_CREDENTIALS="${testServiceAccount}"
    logInfo "Testing: ${folderName}"

    deleteDir "${outputTestDir}"
    tsc -p ./src/test/tsconfig.json --outDir "${outputTestDir}"
    throwError "Error while compiling tests in:  ${folderName}"

    copyFileToFolder package.json "${outputTestDir}/test"
    throwError "Error while compiling tests in:  ${folderName}"

    logInfo "${folderName} - Linting tests..."
    tslint --project ./src/test/tsconfig.json
    throwError "Error while linting tests in:  ${folderName}"

    logInfo "${folderName} - Running tests..."

    local testsToRun=()
    for testToRun in "${ts_testsToRun[@]}"; do
      testsToRun+=("--test=${testToRun}")
    done
    node "${outputTestDir}/test/test" "--service-account=${testServiceAccount}" "${testsToRun[@]}"
    throwError "Error while running tests in:  ${folderName}"
  }

  _canPublish() {
    [[ ! -e "./${outputDir}" ]] && throwError "WILL NOT PUBLISH ${folderName}.. NOT OUTPUT DIR" 2
  }

  _publish() {
    _pushd "./${outputDir}"

    logInfo "Publishing: ${folderName}"
    npm publish --access public
    throwError "Error publishing: ${folderName}"
    _popd
  }

  _exists() {
    [[ -e "${folderName}" ]] && return 0

    return 1
  }

  _toLog() {
    logDebug "${folderName}: ${packageName}"
  }
}
