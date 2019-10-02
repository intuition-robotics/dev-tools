#!/bin/bash

new (){
    local className=${1}
    local instanceName=${2}
    logDebug "loading class ${className} as ${instanceName}"


    local classFile=$(cat ${className}.class.sh)
#    classFile=`echo -e "${classFile}" | sed -E "s/declare ([a-zA-Z_]{1,})=(.*)$/local \1=; function ${instanceName}.\1() { if [[ \"\\$1\" == \"=\" ]]; then ${className}.property \1 = \"\\$2\"; else ${className}.property \1; fi }; ${className}.\1 = \2/g"`
    classFile=`echo -e "${classFile}" | sed -E "s/declare ([a-zA-Z_]{1,})$/local \1=; function ${instanceName}.\1() { if [[ \"\\$1\" == \"=\" ]]; then ${className}.property \1 = \"\\$2\"; else ${className}.property \1; fi }/g"`
    classFile=`echo -e "${classFile}" | sed -E "s/function create\(\) {/function create() { ${className}.property() { if [[ \"\\$2\" == \"=\" ]]; then setVariableName \\$1 \"\\$3\"; else echo \"\\${!1}\" \"\\${2}\" ; fi }/g"`
    classFile=`echo -e "${classFile}" | sed -E "s/${className}/${instanceName}/g"`
#    echo -e "${classFile}"

    . <(echo -e "${classFile}")
    create
}






