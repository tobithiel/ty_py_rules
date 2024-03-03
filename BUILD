load("//:defs.bzl", "compile_requirements", "my_py_binary", "my_py_binary_no_deps")

# Internal

exports_files(["_main.sh.tpl", "_main.py", "compile_requirements.py", "check_requirements.py"])
toolchain_type(
  name = "toolchain_type",
  visibility = ['//visibility:public'],
)
compile_requirements(
    name = "internal_reqs",
    requirements_in = "//:internal_requirements.in",
)

my_py_binary_no_deps(
  name = "install_wheels",
  main = "install_wheels.py",
  visibility = ['//visibility:public'],
)

my_py_binary(
  name = "wheel_builder",
  main = "wheel_builder.py",
  visibility = ['//visibility:public'],
  deps = ["@internal_reqs//build"],
)
