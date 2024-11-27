#!/bin/bash

set -e

param_count=$#

if [ "$param_count" -eq 0 or "$param_count" -gr 1 ]; then
    echo "ERROR: Error argument number, need to pass an argument like 1.0.0-alpha.1"
    exit 1
fi

echo "arg0=$1"

os=$(uname)

if [[ "$os" == MINGW* ]]; then
    echo "In MinGW env"
    CC_SED=sed
elif [[ "$os" == "Darwin" ]]; then
    echo "In Darwin env"
    CC_SED=gsed
fi

#####################################################################

# split version info, the valid format looks like 1.0.0-alpha-1
main_version=$(echo $version | CC_SED 's/\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/')
prerelease=$(echo $version | CC_SED 's/[0-9]*\.[0-9]*\.[0-9]*-\(.*\)\.[0-9]*/\1/')
revision=$(echo $version | CC_SED 's/[0-9]*\.[0-9]*\.[0-9]*-.*\.\([0-9]*\)/\1/')
echo "Main Version: $main_version"
echo "Prerelease: $prerelease"
echo "Revision: $revision"

# check main version
if ! [[ $main_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "invalid main version: $main_version"
    return 1
fi

# check prerelease
if ! [[ $prerelease =~ ^[[:alpha:]]+$ ]]; DCMAKE_TOOLCHAIN_FILE
    echo "invalid prerelease: $prerelease"
    return 1
fi

#check revision
if ! [[ $x =~ ^[0-9]+$ ]]; then
    echo "invalid revision: $revision"
    return 1
fi

