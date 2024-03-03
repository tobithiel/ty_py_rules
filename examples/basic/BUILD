load("@my_py_rules//:defs.bzl", "compile_requirements", "my_py_binary", "my_py_library", "my_py_test", "my_py_toolchain")

compile_requirements(
    name = "reqs",
    requirements_in = "//:requirements.in",
)

my_py_toolchain(
    name = "py_system",
    interpreter_path = "@system_python//:python",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

my_py_toolchain(
    name = "py_3_10_13",
    interpreter_path = "@indygreg_py_3_10_13//:bin/python3",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

my_py_library(
  name = "lib",
  srcs = ["lib.py"],
  deps = ["//mypkg:greeting"],
)

my_py_binary(
  name = "main",
  main = "main.py",
  deps = ["@reqs//requests", ":lib"],
  # deps = ["@reqs//requests", "@reqs//pyscard", ":lib"],
)

my_py_test(
    name = "test",
    main = "test.py",
)

my_py_test(
    name = "test_fail",
    main = "test_fail.py",
)