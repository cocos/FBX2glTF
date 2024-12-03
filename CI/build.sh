#!/bin/bash

set -e

IsWindows=false
IsMacOS=false
IsLinux=false
is64BitOperatingSystem=false
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

if [ "$(uname -m)" == "x86_64" ]; then
    is64BitOperatingSystem=true
fi

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
IsLinux: $IsLinux
Is64BitOperatingSystem: $is64BitOperatingSystem
Current working directory: $(pwd)
ArtifactPath: $ArtifactPath
IncludeDebug: $IncludeDebug
Version: $Version
EOF
}

installVcpkg() {
    vcpkgUrl='https://github.com/microsoft/vcpkg.git'
    git clone "$vcpkgUrl"
    
    if [ "$IsWindows" = true ]; then
        ./vcpkg/bootstrap-vcpkg.bat
    elif [ "$IsMacOS" = true ] || [ "$IsLinux" = true ]; then
        ./vcpkg/bootstrap-vcpkg.sh
        if [ "$IsMacOS" = true ]; then
            # xcode-select --install
            :
        fi
    else
        echo 'vcpkg is not available on target platform.'
        exit 1
    fi
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

fbxSdkHome=$(pwd)/fbxsdk/Home

installFbxSdk() {
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
    elif [ "$IsLinux" = true ]; then
        fbxSdkUrl='https://www.autodesk.com/content/dam/autodesk/www/adn/fbx/2020-2-1/fbx202021_fbxsdk_linux.tar.gz'
        fbxSdkTarball=fbxsdk/fbxsdk.tar.gz

        echo "Downloading FBX SDK tar ball from $fbxSdkUrl ..."
        downloadFile "$fbxSdkUrl" "$fbxSdkTarball"
        tar -zxvf "$fbxSdkTarball" -C fbxsdk

        fbxSdkInstallationProgram=fbxsdk/fbx202021_fbxsdk_linux
        chmod ugo+x "$fbxSdkInstallationProgram"

        fbxSdkHomeLocation="$HOME/fbxsdk/install"
        echo "Installing from $fbxSdkInstallationProgram..."
        mkdir -p "$fbxSdkHomeLocation"

        # This is really a HACK way after many tries...
        yes yes | "$fbxSdkInstallationProgram" "$fbxSdkHomeLocation"
        echo ''

        echo "Installation finished($fbxSdkHomeLocation)."
    else
        echo 'FBXSDK is not available on target platform.'
        exit 1
    fi

    echo "$fbxSdkHome"
}

installDependenciesForMacOS() {
    # Download both x86-64 and arm-64 libs and merge them into a uniform binary.
    # https://www.f-ax.de/dev/2022/11/09/how-to-use-vcpkg-with-universal-binaries-on-macos/
    dependencies=('fmt')
    for libName in "${dependencies[@]}"; do
        ./vcpkg/vcpkg install --triplet=x64-osx "$libName"
        ./vcpkg/vcpkg install --triplet=arm64-osx "$libName"
    done

    python3 ./CI/lipo-dir-merge.py ./vcpkg/installed/arm64-osx ./vcpkg/installed/x64-osx ./vcpkg/installed/uni-osx
}

installDependenciesForWindows() {
    dependencies=('libxml2[core]' 'zlib' 'fmt')
    for libName in "${dependencies[@]}"; do
        ./vcpkg/vcpkg install "$libName" --triplet x64-windows-static
    done
}

installDependencies() {
    if [ "$IsMacOS" = true ]; then
        installDependenciesForMacOS
    elif [ "$IsWindows" = true ]; then
        installDependenciesForWindows
    fi
}

runCMake() {
    buildType="${1}"
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

    if [ "$IsMacOS" = true ]; then
        cpu_core_count=$(sysctl -n hw.logicalcpu)
    else
        cpu_core_count=$(nproc)
    fi
    echo "cpu core count is $cpu_core_count"
    echo "fbx home is $fbxSdkHome"
    if [ "$IsMacOS" = true ]; then
        cmake -DCMAKE_TOOLCHAIN_FILE="vcpkg/scripts/buildsystems/vcpkg.cmake" \
            -DCMAKE_PREFIX_PATH="./vcpkg/installed/uni-osx" \
            -DVCPKG_TARGET_TRIPLET="uni-osx" \
            -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
            -DCMAKE_BUILD_TYPE="${buildType}" \
            -DCMAKE_INSTALL_PREFIX="${cmakeInstallPrefix}/${buildType}" \
            -DFbxSdkHome:STRING="${fbxSdkHome}" \
            -DPOLYFILLS_STD_FILESYSTEM="${polyfillsStdFileSystem}" \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
            "${defineVersion}" \
            -S. -B"${cmakeBuildDir}"
    elif [ "$IsWindows" = true ]; then
        cmake -DCMAKE_TOOLCHAIN_FILE="vcpkg/scripts/buildsystems/vcpkg.cmake" \
            -DCMAKE_PREFIX_PATH="./vcpkg/installed/x64-windows-static" \
            -DVCPKG_TARGET_TRIPLET="x64-windows-static" \
            -DCMAKE_BUILD_TYPE="${buildType}" \
            -DCMAKE_INSTALL_PREFIX="${cmakeInstallPrefix}/${buildType}" \
            -DFbxSdkHome:STRING="${fbxSdkHome}" \
            -DPOLYFILLS_STD_FILESYSTEM="${polyfillsStdFileSystem}" \
            -DFBX_STATIC_RTL=1 \
            -A x64 \
            "${defineVersion}" \
            -S. -B"${cmakeBuildDir}" 
    else
        cmake -DCMAKE_TOOLCHAIN_FILE="vcpkg/scripts/buildsystems/vcpkg.cmake" \
            -DCMAKE_BUILD_TYPE="${buildType}" \
            -DCMAKE_INSTALL_PREFIX="${cmakeInstallPrefix}/${buildType}" \
            -DFbxSdkHome:STRING="${fbxSdkHome}" \
            -DPOLYFILLS_STD_FILESYSTEM="${polyfillsStdFileSystem}" \
            "${defineVersion}" \
            -S. -B"${cmakeBuildDir}"
    fi

    cmake --build $cmakeBuildDir --config $buildType -j${cpu_core_count} --verbose

    if [ "$IsWindows" = true ]; then
        cmake --build $cmakeBuildDir --config $buildType -j${cpu_core_count} --target install --verbose
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
        exit 1
    fi
    
    if [ -n "$ArtifactPath" ]; then
        # Remove all .lib and .a files
        find $cmakeInstallPrefix -type f \( -name '*.lib' -o -name '*.a' \) -delete
        # Pack the installation directory
        tar -czvf $ArtifactPath -C $cmakeInstallPrefix .
    fi
}

parseArgs "$@"
printEnvironments
installFbxSdk
installVcpkg
installDependencies
build