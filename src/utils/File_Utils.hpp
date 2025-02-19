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
  std::string normalizedPath = NormalizePath(filePath);
  std::filesystem::path absolutePath = std::filesystem::absolute(ConvertToPlatformPath(normalizedPath));
  return absolutePath.string();
}

inline std::string GetCurrentFolder() {
  return std::filesystem::current_path().string();
}

inline bool FileExists(const std::string& filePath) {
  std::string normalizedPath = NormalizePath(filePath);
  std::string platformPath = ConvertToPlatformPath(normalizedPath);
  return std::filesystem::exists(platformPath) && std::filesystem::is_regular_file(platformPath);
}

inline bool FolderExists(const std::string& path) {
  std::string normalizedPath = NormalizePath(path);
  std::string platformPath = ConvertToPlatformPath(normalizedPath);
  return std::filesystem::exists(platformPath) && std::filesystem::is_directory(platformPath);
}

inline std::string getFolder(const std::string& path) {
  std::string normalizedPath = NormalizePath(path);
  return std::filesystem::path(ConvertToPlatformPath(normalizedPath)).parent_path().string();
}

inline std::string GetFileName(const std::string& filePath) {
  std::string normalizedPath = NormalizePath(filePath);
  return std::filesystem::path(ConvertToPlatformPath(normalizedPath)).filename().string();
}

inline std::string GetFileBase(const std::string& filePath) {
  std::string normalizedPath = NormalizePath(filePath);
  return std::filesystem::path(ConvertToPlatformPath(normalizedPath)).stem().string();
}

inline std::optional<std::string> GetFileSuffix(const std::string& filePath) {
  std::string normalizedPath = NormalizePath(filePath);
  std::string platformPath = ConvertToPlatformPath(normalizedPath);

  const auto& extension = std::filesystem::path(platformPath).extension();
  if (extension.empty()) {
    return std::nullopt;
  }
  return extension.string().substr(1);
}

} // namespace FileUtils
