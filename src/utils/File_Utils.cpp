/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "File_Utils.hpp"

#include <fstream>
#include <set>
#include <string>
#include <vector>

#include <stdint.h>
#include <stdio.h>

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#endif

#include "FBX2glTF.h"
#include "String_Utils.hpp"

namespace FileUtils {

std::vector<std::string> ListFolderFiles(
    std::string folder,
    const std::set<std::string>& matchExtensions) {
  std::vector<std::string> fileList;
  if (folder.empty()) {
    folder = ".";
  }
  for (const auto& entry : std::filesystem::directory_iterator(folder)) {
    const auto& suffix = FileUtils::GetFileSuffix(entry.path().string());
    if (suffix.has_value()) {
      const auto& suffix_str = StringUtils::ToLower(suffix.value());
      if (matchExtensions.find(suffix_str) != matchExtensions.end()) {
        fileList.push_back(entry.path().filename().string());
      }
    }
  }
  return fileList;
}

bool CreatePath(const std::string path) {
  const auto& parent = std::filesystem::path(path).parent_path();
  if (parent.empty()) {
    // this is either CWD or boost::filesystem root; either way it exists
    return true;
  }
  if (std::filesystem::exists(parent)) {
    return std::filesystem::is_directory(parent);
  }
  return std::filesystem::create_directory(parent);
}

bool CopyFile(const std::string& srcFilename, const std::string& dstFilename, bool createPath) {
  std::ifstream srcFile(srcFilename, std::ios::binary);
  if (!srcFile) {
    fmt::printf("Warning: Couldn't open file %s for reading.\n", srcFilename);
    return false;
  }
  // find source file length
  srcFile.seekg(0, std::ios::end);
  std::streamsize srcSize = srcFile.tellg();
  srcFile.seekg(0, std::ios::beg);

  if (createPath && !CreatePath(dstFilename.c_str())) {
    fmt::printf("Warning: Couldn't create directory %s.\n", dstFilename);
    return false;
  }

  std::ofstream dstFile(dstFilename, std::ios::binary | std::ios::trunc);
  if (!dstFile) {
    fmt::printf("Warning: Couldn't open file %s for writing.\n", dstFilename);
    return false;
  }
  dstFile << srcFile.rdbuf();
  std::streamsize dstSize = dstFile.tellp();
  if (srcSize == dstSize) {
    return true;
  }
  fmt::printf(
      "Warning: Only copied %lu bytes to %s, when %s is %lu bytes long.\n",
      dstSize,
      dstFilename,
      srcFilename,
      srcSize);
  return false;
}

std::filesystem::path ConvertToPlatformPath(const std::string& path) {
    std::string normalizedPath = NormalizePath(path);

#ifdef _WIN32
    // Step 1: Convert UTF-8 (std::string) to UTF-16 (std::wstring)
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, normalizedPath.c_str(), -1, nullptr, 0);
    if (size_needed == 0) return {};

    std::wstring wPath(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, normalizedPath.c_str(), -1, &wPath[0], size_needed);

    // Step 2: Convert std::wstring to std::filesystem::path
    return std::filesystem::path(wPath);
#else
    // Linux/macOS use UTF-8 directly
    return std::filesystem::path(normalizedPath);
#endif
}

} // namespace FileUtils
