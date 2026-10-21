#include <iostream>
#include <string>
#include <thread>

#include "toolchains/cc/example/lib/hello-time.h"
#include "toolchains/cc/example/main/hello-greet.h"

int main(int argc, char** argv) {
  std::string who = "world";
  if (argc > 1) {
    who = argv[1];
  }
  std::jthread t([&] {
    std::cout << get_greet(who) << std::endl;
    print_localtime();
  });
  return 0;
}
