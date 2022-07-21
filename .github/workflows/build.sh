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
            git clone https://github.com/openvmi/${reponame}.git $REPOPATH/$reponame
            buildFor${lang} $REPOPATH/${reponame}
            commitAndPush $REPOPATH/$reponame $reponame
        done < ".protolangs" 
    fi
    ls -al
}

function buildForgo {
    protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative ./*.proto
    cp *.go "$1/pb/"
}

function commitAndPush {
    enterDir $1
    git config user.name "kai.zhou"
    git config user.email "zhoukaisspu@163.com"
    git add -N .
    if ! git diff --exit-code > /dev/null; then
        git add .
        git commit -m "Auto creation of proto"
        git remote set-url origin https://${push_secret}@github.com/openvmi/$2.git
        git push origin HEAD
    else
        echo "No changes detected for $1"
    fi
    leaveDir
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