#!/bin/bash
set -e

project_root="$(cd "$(dirname "$0")" && pwd -P)"
build_folder="$project_root/build"

time=""
[ -x ~/bin/ntime ] && time=~/bin/ntime

mkdir -p "$build_folder"
pushd $build_folder

    $time odin build .. -out:main -debug
    
    $time ./main
    
popd