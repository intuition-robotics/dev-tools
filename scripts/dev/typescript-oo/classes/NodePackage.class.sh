#!/bin/bash

NodePackage() {

  declare path
  declare watch
  declare folderName
  declare packageName
  declare version
  declare outputDir
  declare outputTestDir
  declare -a watchIds
  declare -a newWatchIds

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
    [[ ! "${ts_installPackages}" ]] && return

    logInfo "Installing: ${folderName}"
    logInfo

    npm install
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

    _cd src
    local folders=($(listFolders))
    _cd..

    for folder in "${folders[@]}"; do
      [[ "${folder}" == "test" ]] && continue
      logInfo "Compiling($(tsc -v)): ${folderName}/${folder}"
      if [[ "${ts_watch}" ]]; then

        local parts=
        for watchLine in "${watchIds[@]}"; do
          parts=(${watchLine[@]})
          [[ "${parts[1]}" == "${folder}" ]] && break
        done

        [[ "${parts[2]}" ]] && execute "pkill -P ${parts[2]}"

        tsc-watch -p "./src/${folder}/tsconfig.json" --rootDir "./src/${folder}" --outDir "${outputDir}" ${compilerFlags[@]} --onSuccess "bash ../relaunch-backend.sh" &

        local _pid="${folderName} ${folder} $!"
        logInfo "${_pid}"
        newWatchIds+=("${_pid}")
      else
        tsc -p "./src/${folder}/tsconfig.json" --rootDir "./src/${folder}" --outDir "${outputDir}" ${compilerFlags[@]}
        throwWarning "Error compiling: ${module}/${folder}"
        # figure out the rest of the dirs...
      fi
    done
  }

  _lint() {
    [[ ! "${ts_lint}" ]] && return

    _cd src
    local folders=($(listFolders))
    _cd..

    for folder in "${folders[@]}"; do
      [[ "${folder}" == "test" ]] && continue

      if [[ -e ".eslintrc.js" ]]; then
        logInfo "ES Linting: ${folderName}/${folder}"
        eslint --ext .ts --ext .tsx "./src/${folder}"
        throwError "Error while ES linting: ${module}/${folder}"

      elif [[ -e "tslint.json" ]]; then
        logInfo "Linting: ${folderName}/${folder}"
        tslint --project "./src/${folder}/tsconfig.json"
        throwError "Error while linting: ${module}/${folder}"
      fi
    done
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

  _generate() {
    return 0
  }

  _flow() {
    this.purge
    this.clean

    this.install
    this.generate
    this.compile
    this.lint
    this.test
  }
}
