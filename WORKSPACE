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

# internal
my_py_pip_repository(
    name = "internal_reqs",
    requirements = "@//:internal_requirements.in.txt",
    # TODO should use custom python interpreter
    interpreter = "@indygreg_py_3_10_13//:bin/python3",
    prefer_wheels = True,
    extra_deps = {
        "build": ["wheel"],
    },
)
load("@internal_reqs//:requirements.bzl", internal_install_deps = "install_deps")
internal_install_deps()

# Usage

my_py_system_python(
    name = "system_python",
    interpreter_path = "python",
)

register_toolchains(
    "//:py_3_10_13",
    # "//:py_system",
)

my_py_pip_repository(
    name = "reqs",
    requirements = "@//:requirements.in.txt",
    interpreter = "@indygreg_py_3_10_13//:bin/python3",
    # prefer_wheels = True,
    # TODO can this be automatically inferred?
    wheel_build_deps = {
        "editables": ["flit-core"],
        "hatchling": ["pathspec", "pluggy", "trove-classifiers"],
        "idna": ["flit-core"],
        "packaging": ["flit-core"],
        "pathspec": ["flit-core"],
        "tomli": ["flit-core"],
        "urllib3": ["hatchling"],
    },
)
load("@reqs//:requirements.bzl", "install_deps")
install_deps()
