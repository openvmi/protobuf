#!/usr/bin/env bash

set -e 

REPOPATH="${GITHUB_WORKSPACE}/.temp/_buildoutput"
CURRENT_BRANCH=${CURRENT_BRANCH-"branch-not-available"}
export PATH="$PATH:$(go env GOPATH)/bin"
function enterDir {
    echo "Entering $1"  
    pushd $1 > /dev/null
}

function leaveDir {
    echo "Leaving `pwd`"
    popd > /dev/null
}

function buildDir {
    currentDir="$1"
    echo "Building directory ${currentDir}"
    enterDir ${currentDir}
    buildProtoForTypes $currentDir
    leaveDir ${currentDir}
}

function buildProtoForTypes {
    target=${1%/}
    echo ${target}
    if [ -f .protolangs ]; then
        echo "this file is exist"
        ls -al
        while IFS= read -r lang || [ -n "$lang" ]; do
            echo $lang
            reponame="protobuf-${target}-${lang}"
            rm -rf ${REPOPATH}/${reponame}
            echo "Cloneing repo: https://github.com/openvmi/${reponame}.git"
            git clone https://github.com/openvmi/${reponame}.git
        done < ".protolangs" 
    fi
    ls -al
}

function buildAll {
    echo "Build services's protocol buffers"
    mkdir -p ${REPOPATH}
    for d in *; do
        if [ -d "$d" ]; then
            echo $d
            buildDir $d
        fi
    done
}

buildAll