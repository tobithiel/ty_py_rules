workspace(name = "tobi_hermpy")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//:defs.bzl", "my_py_indygreg_standalone", "my_py_system_python", "my_py_pip_repository")

my_py_system_python(
    name = "system_python",
    interpreter_path = "python",
)

my_py_indygreg_standalone(
    name = "indygreg_py_3_10_13",
    sha256 = "60e7ca89d37dd8a630a5525bda6143a66a3949c4f03c8319295ddb1d1023b425",
    url = "https://github.com/indygreg/python-build-standalone/releases/download/20240107/cpython-3.10.13+20240107-x86_64-unknown-linux-gnu-pgo+lto-full.tar.zst",
)
