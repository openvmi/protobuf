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
            reponame="protobuf_${target}_${lang}"
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
    [ ! -d "$1/pb" ] && mkdir -p "$1/pb"
    cp *.go "$1/pb/"
}

function buildForpy {
    enterDir ${REPOPATH}
    source venv/bin/activate
    leaveDir
    treponame="$2"
    echo "buildForpy, repoName: ${treponame}"
    mkdir ${treponame}
    echo "buildForpy, all files is:"
    ls -al
    cp *.proto "./${treponame}"
    echo "buildForpy, all files in ${treponame}:"
    ls -al "./${treponame}/"
    python3 -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. ./${treponame}/*.proto
    echo "buildForpy, after run protoc, all files in ${treponame}:"
    ls -al "./${treponame}/"
    echo "copy files from ./${treponame} to $1"
    cp ./${treponame}/*.py "$1/"
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