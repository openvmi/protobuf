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
            buildFor${lang} $REPOPATH/${reponame} ${reponame}
            commitAndPush $REPOPATH/$reponame $reponame
        done < ".protolangs" 
    fi
    ls -al
}

function buildForgo {
    protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative ./*.proto
    cp *.go "$1/pb/"
}

function buildForpy {
    enterDir ${REPOPATH}
    source venv/bin/activate
    leaveDir
    repoName="$2"
    mkdir ${reponame}
    cp *.proto "./${reponame}"
    python3 -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. ./${reponame}/*.proto
    ls -al
    cp ./${reponame}/*.py "$1/"
    deactivate
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
        tag=v$(date +'%Y.%m.%d.%H.%M')
        git tag -a ${tag} -m "auto generate tag: ${tag}"
        git push origin ${tag}

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

function setupPyVirtualEnv {
    mkdir -p ${REPOPATH}
    enterDir ${REPOPATH}
    python3 -m pip install virtualenv
    virtualenv venv
    source venv/bin/activate
    python3 -m pip install grpcio
    python3 -m pip install grpcio-tools
    deactivate
    ls -al
    leaveDir
}
setupPyVirtualEnv
buildAll