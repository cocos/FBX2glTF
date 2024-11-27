#!/bin/bash

IsWindows=false
IsMacOS=false
IsLinux=false
CurrentDir=$(dirname "$0")

cmakeInstallPrefix='out/install'
ArtifactPath=''
IncludeDebug=false
Version=''

# check platform
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     IsLinux=true;;
    Darwin*)    IsMacOS=true;;
    CYGWIN*)    IsWindows=true;;
    MINGW*)     IsWindows=true;;
    *)          ;;
esac

parseArgs() {
    args=("$@")
    for ((i=0; i<${#args[@]}; i++)); do
        case ${args[i]} in
            '-ArtifactPath')
                ArtifactPath=${args[++i]}
                ;;
            '-IncludeDebug')
                IncludeDebug=true
                ;;
            '-Version')
                Version=${args[++i]}
                ;;
            *)
                ;;
        esac
    done
}

printEnvironments() {
    cat << EOF
IsWindows: $IsWindows
IsMacOS: $IsMacOS
Current working directory: $(pwd)
ArtifactPath: $ArtifactPath
IncludeDebug: $IncludeDebug
Version: $Version
EOF
}

downloadFile() {
    url="$1"
    dest="$2"
    
    file=$(basename "$dest")
    dir=$(dirname "$dest")
    mkdir -p "$dir"
    
    while true; do
        curl -L --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" -o "$file" "$url"
        ret=$?
        if [ $ret -eq 0 ]; then
            mv "$file" "$dest"
            break
        fi
    done
}

installFbxSdk() {
    fbxSdkHome=$(pwd)/fbxsdk/Home
    mkdir -p fbxsdk

    if [ "$IsWindows" = true ]; then
        fbxSdkUrl='https://www.autodesk.com/content/dam/autodesk/www/adn/fbx/2020-2-1/fbx202021_fbxsdk_vs2019_win.exe'
        fbxSdkWindowsInstaller="fbxsdk\\fbxsdk.exe"

        downloadFile "$fbxSdkUrl" "$fbxSdkWindowsInstaller"
        
        fbxSdkHome_unix=$fbxSdkHome
        echo fbxSdkHome_unix=$fbxSdkHome_unix

        fbxSdkHome=$(cygpath -w $fbxSdkHome_unix)

        echo fbxSdkHome=$fbxSdkHome

        cmd "/C CI\install-fbx-sdk.bat $fbxSdkWindowsInstaller $fbxSdkHome"
        echo "Installation finished($fbxSdkHome)."

    elif [ "$IsMacOS" = true ]; then
        fbxSdkUrl='https://www.autodesk.com/content/dam/autodesk/www/adn/fbx/2020-2-1/fbx202021_fbxsdk_clang_mac.pkg.tgz'
        fbxSdkVersion='2020.2.1'
        fbxSdkMacOSTarball='./fbxsdk/fbxsdk.pkg.tgz'

        downloadFile "$fbxSdkUrl" "$fbxSdkMacOSTarball"

        tar -zxvf "$fbxSdkMacOSTarball" -C fbxsdk
        fbxSdkMacOSPkgFile=$(find fbxsdk -name '*.pkg' -type f)
        echo "FBX SDK MacOS pkg: $fbxSdkMacOSPkgFile"
        sudo installer -pkg "$fbxSdkMacOSPkgFile" -target /
        ln -s "/Applications/Autodesk/FBX SDK/$fbxSdkVersion" fbxsdk/Home
    else
        echo 'FBXSDK is not available on target platform.'
        exit 1
    fi

    echo "$fbxSdkHome"
}

installDependencies() {
    git clone --branch v1.3.1 --single https://github.com/madler/zlib.git third_party/zlib
    git clone --branch libxml2-2.11.9 https://github.com/winlibs/libxml2.git third_party/libxml2
    git clone --branch 11.0.2 https://github.com/fmtlib/fmt third_party/fmt

    vcpkg install libiconv
}

runCMake() {
    buildType="$1"
    echo "Build $buildType ..."
    cmakeBuildDir="out/build/$buildType"

    polyfillsStdFileSystem='OFF'
    if [ "$IsWindows" = false ]; then
        polyfillsStdFileSystem='ON'
    fi

    defineVersion=''
    if [ -n "$Version" ]; then
        defineVersion="-DFBX_GLTF_CONV_CLI_VERSION=$Version"
    fi

    echo "fbx home is $fbxSdkHome"
    cmake_cmd="cmake -DCMAKE_BUILD_TYPE=\"${buildType}\" \
            -DCMAKE_INSTALL_PREFIX=\"${cmakeInstallPrefix}/${buildType}\" \
            -DFbxSdkHome:STRING=\"${fbxSdkHome}\" \
            -DPOLYFILLS_STD_FILESYSTEM=\"${polyfillsStdFileSystem}\" \
            \"${defineVersion}\" \
            -S. -B\"${cmakeBuildDir}\""

    if [ "$IsMacOS" = true ]; then
        cmake_cmd="$cmake_cmd -DCMAKE_OSX_ARCHITECTURES=\"x86_64;arm64\""
    fi
    eval $cmake_cmd

    cmake --build $cmakeBuildDir --config $buildType

    if [ "$IsWindows" = true ]; then
        cmake --build $cmakeBuildDir --config $buildType --target install
    else
        cmake --install $cmakeBuildDir
    fi
}

build() {
    cmakeBuildTypes=('Release')
    if [ "$IncludeDebug" = true ]; then
        cmakeBuildTypes+=('Debug')
    fi

    for buildType in "${cmakeBuildTypes[@]}"; do
        runCMake "$buildType"
    done

    if [ ! -d "$cmakeInstallPrefix" ] || [ ! -e "$cmakeInstallPrefix" ]; then
        echo 'Installation failed.'
        exit -1
    fi
    
    if [ -n "$ArtifactPath" ]; then
        tar -czvf $ArtifactPath -C $cmakeInstallPrefix .
    fi
}

parseArgs "$@"
printEnvironments
installFbxSdk
installDependencies
build
