load("//:defs.bzl", "compile_requirements", "my_py_binary", "my_py_binary_no_deps", "my_py_library", "my_py_test", "my_py_toolchain")

# Internal

exports_files(["download_binary_wheel.py"])
toolchain_type(name = "toolchain_type")
compile_requirements(
    name = "internal_reqs",
    requirements_in = "//:internal_requirements.in",
)

my_py_binary_no_deps(
  name = "install_wheels",
  main = "install_wheels.py",
)


# Usage

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

# my_py_bin_wheel(
# 	name = "requests",
# 	requirement = "requests",
# tags = ['block-network'],
# )

# my_py_bin_wheel(
# 	name = "click",
# 	requirement = "click",
# )

# my_py_wheel(
# 	name = "pyscard",
# 	requirement = "pyscard",
# 	version = "2.0.7",
# 	python = "cp311",
# 	abi = "cp311",
# 	platform = "linux_x86_64",
# )

my_py_library(
  name = "lib",
  srcs = ["lib.py"],
  deps = ["//mypkg:greeting"],
)

my_py_binary(
  name = "main",
  main = "main.py",
  # deps = ["@reqs//requests"],
  deps = ["@reqs//requests", ":lib"],
  # deps = ["@reqs//requests", "@reqs//pyscard", ":lib"],
  # deps = [":requests", ":click", ":pyscard", ":lib"],
)

my_py_test(
    name = "test",
    main = "test.py",
)

my_py_test(
    name = "test_fail",
    main = "test_fail.py",
)