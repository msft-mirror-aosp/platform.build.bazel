// Copyright 2017 The Bazel Authors. All rights reserved.
// Modifications Copyright 2024 - The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// wrapper.cc: Pass args to the wrapped clang.
//
// This is a wrapper that passes the provided args to clang, with the following
// strings substituted:
// "{BAZEL_EXECUTION_ROOT}" -> $CWD
//
// An environment variable "WRAPPER_WRAP_BINARY" must be set when running the
// wrapper, pointing to the compiler binary to run.

#include <sched.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <ostream>
#include <string>
#include <vector>

static const char *kBinaryPathVarName = "WRAPPER_WRAP_BINARY";
static const char *kDebugFlagVarName = "__WRAPPER_LOG_ONLY";
static const char *kLtoObjPathFlag = "-Wl,--lto-obj-path=";

namespace {

// Unescape and unquote an argument read from a line of a response file.
const std::string Unescape(const std::string &arg) {
  std::string result;
  auto length = arg.size();
  for (size_t i = 0; i < length; i++) {
    auto ch = arg[i];

    // If it's a backslash, consume it and append the character that follows.
    if (ch == '\\' && i + 1 < length) {
      i++;
      result.push_back(arg[i]);
      continue;
    }

    // If it's a quote, process everything up to the matching quote, unescaping
    // backslashed characters as needed.
    if (ch == '"' || ch == '\'') {
      auto quote = ch;
      i++;
      while (i != length && arg[i] != quote) {
        if (arg[i] == '\\' && i + 1 < length) {
          i++;
        }
        result.push_back(arg[i]);
        i++;
      }
      if (i == length) {
        break;
      }
      continue;
    }

    // It's a regular character.
    result.push_back(ch);
  }

  return result;
}

// Converts an array of string arguments to char *arguments.
// Note that the lifetime of the char* arguments in the returned array
// are controlled by the lifetime of the strings in args.
std::vector<const char *> ConvertToCArgs(const std::vector<std::string> &args) {
  std::vector<const char *> c_args;
  for (int i = 0; i < args.size(); i++) {
    c_args.push_back(args[i].c_str());
  }
  c_args.push_back(nullptr);
  return c_args;
}

// Spawns a subprocess for given arguments args. The first argument is used
// for the executable path.
int RunSubProcess(const std::vector<std::string> args) {
  auto exec_argv = ConvertToCArgs(args);

  pid_t pid;
  int status = posix_spawn(&pid, args[0].c_str(), nullptr, nullptr,
                           const_cast<char **>(exec_argv.data()), nullptr);
  if (status != 0) {
    std::cerr << "Error forking process '" << args[0]
              << "': " << strerror(status) << std::endl;
    return status;
  }
  if (waitpid(pid, &status, 0) == -1) {
    perror(("Error waiting for process " + args[0]).c_str());
    return EXIT_FAILURE;
  }
  if (WIFEXITED(status)) {
    if (WEXITSTATUS(status) != 0) {
      std::cerr << "Error in child process '" << args[0]
                << "': " << strerror(WEXITSTATUS(status)) << std::endl;
    }
    return WEXITSTATUS(status);
  } else if (WIFSIGNALED(status)) {
    std::cerr << "Child process '" << args[0]
              << "' terminated by signal: " << WTERMSIG(status) << std::endl;
    return status;
  }
  return EXIT_SUCCESS;
}

// Finds and replaces all instances of oldsub with newsub, in-place on str.
void FindAndReplace(const std::string &oldsub, const std::string &newsub,
                    std::string *str) {
  int start = 0;
  while ((start = str->find(oldsub, start)) != std::string::npos) {
    str->replace(start, oldsub.length(), newsub);
    start += newsub.length();
  }
}

// Returns an environment variable in the current process
// environment. Aborts if this variable is unset.
std::string GetMandatoryEnvVar(const std::string &var_name) {
  char *env_value = getenv(var_name.c_str());
  if (env_value == nullptr) {
    std::cerr << "Error: " << var_name << " not set." << std::endl;
    exit(EXIT_FAILURE);
  }
  return env_value;
}

// An RAII temporary file.
class TempFile {
public:
  // Create a new temporary file using the given path template string (the same
  // form used by `mkstemp`). The file will automatically be deleted when the
  // object goes out of scope.
  static std::unique_ptr<TempFile> Create(const std::string &path_template) {
    const char *tmpDir = getenv("TMPDIR");
    if (!tmpDir) {
      tmpDir = "/tmp";
    }
    size_t size = strlen(tmpDir) + path_template.size() + 2;
    std::unique_ptr<char[]> path(new char[size]);
    snprintf(path.get(), size, "%s/%s", tmpDir, path_template.c_str());

    if (mkstemp(path.get()) == -1) {
      perror(("Failed to create file " + std::string(path.get())).c_str());
      return nullptr;
    }
    return std::unique_ptr<TempFile>(new TempFile(path.get()));
  }

  // Explicitly make TempFile non-copyable and movable.
  TempFile(const TempFile &) = delete;
  TempFile &operator=(const TempFile &) = delete;
  TempFile(TempFile &&) = default;
  TempFile &operator=(TempFile &&) = default;

  ~TempFile() { std::filesystem::remove(path_); }

  // Gets the path to the temporary file.
  std::filesystem::path GetPath() const { return path_; }

private:
  explicit TempFile(std::filesystem::path path) : path_(path) {}

  std::filesystem::path path_;
};

static std::unique_ptr<TempFile>
WriteResponseFile(const std::vector<std::string> &args) {
  auto response_file = TempFile::Create("wrapper_params.XXXXXX");
  std::ofstream response_file_stream(response_file->GetPath());

  for (const auto &arg : args) {
    // When Clang writes out a response file to communicate from driver to
    // frontend, they just quote every argument to be safe; we duplicate that
    // instead of trying to be "smarter" and only quoting when necessary.
    response_file_stream << '"';
    for (auto ch : arg) {
      if (ch == '"' || ch == '\\') {
        response_file_stream << '\\';
      }
      response_file_stream << ch;
    }
    response_file_stream << "\"\n";
  }

  response_file_stream.close();
  return response_file;
}

void ProcessArgument(const std::string arg, const std::string execroot,
                     std::function<void(const std::string &)> consumer);

bool ProcessResponseFile(const std::string arg, const std::string execroot,
                         std::function<void(const std::string &)> consumer) {
  auto path = arg.substr(1);
  std::ifstream original_file(path);
  // Ignore non-file args such as '@loader_path/...'
  if (!original_file.good()) {
    return false;
  }

  std::string arg_from_file;
  while (getline(original_file, arg_from_file)) {
    // Arguments in response files might be quoted/escaped, so we need to
    // unescape them ourselves.
    auto unescaped = Unescape(arg_from_file);
    // Argument can have spaces inside. We need to split to multiple args.
    char *p = strtok(unescaped.data(), " ");
    while (p != nullptr) {
      ProcessArgument(p, execroot, consumer);
      p = strtok(nullptr, " ");
    }
  }

  return true;
}

std::string GetCurrentDirectory() {
  // Passing null,0 causes getcwd to allocate the buffer of the correct size.
  char *buffer = getcwd(nullptr, 0);
  std::string cwd(buffer);
  free(buffer);
  return cwd;
}

void ProcessArgument(const std::string arg, const std::string execroot,
                     std::function<void(const std::string &)> consumer) {
  auto new_arg = arg;
  if (arg[0] == '@') {
    if (ProcessResponseFile(arg, execroot, consumer))
      return;
  }

  FindAndReplace("{BAZEL_EXECUTION_ROOT}", execroot, &new_arg);
  consumer(new_arg);
}

void CreateFile(const std::string path) {
  std::ofstream file(path);
  if (file.is_open()) {
    file.close();
  } else {
    std::cerr << "Failed to create file: " << path << std::endl;
  }
}

} // namespace

int main(int argc, char *argv[]) {
  auto tool_path = GetMandatoryEnvVar(kBinaryPathVarName);
  unsetenv(kBinaryPathVarName);
  char *debug = getenv(kDebugFlagVarName);
  unsetenv(kDebugFlagVarName);

  auto execroot = GetCurrentDirectory();

  // Golang calls the wrapper from its own sandbox so relative paths don't work.
  // rules_go rewrites the paths to absolute ones and sets "GO_CC_ROOT" to the
  // execroot path. We use that to correct the tool path and the replaced paths.
  char *go_cc_root = getenv("GO_CC_ROOT");
  if (go_cc_root != nullptr) {
    execroot = go_cc_root;
    tool_path = std::filesystem::path(go_cc_root) / tool_path;
  }

  std::vector<std::string> processed_args = {};

  auto consumer = [&](const std::string &arg) {
    processed_args.push_back(arg);
  };
  for (int i = 1; i < argc; i++) {
    ProcessArgument(argv[i], execroot, consumer);
  }

  // Create an empty LTO object file when linker flag -object_path_lto is
  // detected. This is a special hack for lld64 to work with Bazel's LTO-index
  // action, when targeting macOS. lld64 will then overwrite this file with the
  // actual object. Without this file, lld64 will create a same-named directory
  // instead. For details, see
  // https://github.com/llvm/llvm-project/commit/2b2e858e9cbb1d459804f8e393ac6b90459ccb7a.
  std::string prefix = kLtoObjPathFlag;
  for (auto &arg : processed_args) {
    if (arg.rfind(prefix, 0) == 0) {
      CreateFile(arg.substr(prefix.length()));
      arg.replace(0, prefix.length(), "-Wl,-object_path_lto,");
    }
  }

  auto response_file = WriteResponseFile(processed_args);

  // Special mode that only prints the command. Used for testing.
  if (debug) {
    std::cerr << tool_path << std::endl;
    std::ifstream f(response_file->GetPath());
    if (f.is_open())
      std::cerr << f.rdbuf();
    return EXIT_FAILURE;
  }

  auto invocation_args = {tool_path, "@" + response_file->GetPath().string()};
  return RunSubProcess(invocation_args);
}