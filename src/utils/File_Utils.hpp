/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#include <set>
#include <string>
#include <vector>
#include <optional>
#include <filesystem>

namespace FileUtils {

std::string GetCurrentFolder();

bool FileExists(const std::string& folderPath);
bool FolderExists(const std::string& folderPath);

std::vector<std::string> ListFolderFiles(
    const std::string folder,
    const std::set<std::string>& matchExtensions);

bool CreatePath(std::string path);

bool CopyFile(
    const std::string& srcFilename,
    const std::string& dstFilename,
    bool createPath = false);

std::filesystem::path ConvertToPlatformPath(const std::string& path);

inline std::string NormalizePath(const std::string& path) {
#ifdef __APPLE__
    std::string normalizedPath = path;
    std::replace(normalizedPath.begin(), normalizedPath.end(), '\\', '/');
    return normalizedPath;
#else
    return path;
#endif
}

inline std::string GetAbsolutePath(const std::string& filePath) {
  std::filesystem::path path = ConvertToPlatformPath(filePath);
  std::filesystem::path absolutePath = std::filesystem::absolute(path);
  return absolutePath.string();
}

inline std::string GetCurrentFolder() {
  return std::filesystem::current_path().string();
}

inline bool FileExists(const std::string& filePath) {
  std::filesystem::path path = ConvertToPlatformPath(filePath);
  return std::filesystem::exists(path) && std::filesystem::is_regular_file(path);
}

inline bool FolderExists(const std::string& path) {
  std::filesystem::path platformPath = ConvertToPlatformPath(path);
  return std::filesystem::exists(platformPath) && std::filesystem::is_directory(platformPath);
}

inline std::string getFolder(const std::string& path) {
  return ConvertToPlatformPath(path).parent_path().string();
}

inline std::string GetFileName(const std::string& filePath) {
  return ConvertToPlatformPath(filePath).filename().string();
}

inline std::string GetFileBase(const std::string& filePath) {
  return ConvertToPlatformPath(filePath).stem().string();
}

inline std::optional<std::string> GetFileSuffix(const std::string& filePath) {
  std::filesystem::path platformPath = ConvertToPlatformPath(filePath);

  const auto& extension = platformPath.extension();
  if (extension.empty()) {
    return std::nullopt;
  }
  return extension.string().substr(1);
}

} // namespace FileUtils
