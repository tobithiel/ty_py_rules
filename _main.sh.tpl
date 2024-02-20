#!/bin/sh -eux

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_DIR="$(dirname "${0}")"

INT_PATH="{{INTERPRETER_PATH}}"
INT_ARGS="{{INTERPRETER_ARGS}}"
WORKSPACE_NAME="{{WORKSPACE_NAME}}"
WHEELS_DIR="{{WHEELS_DIR}}"
ENTRYPOINT="{{ENTRYPOINT}}"
ARGS="{{ARGS}}"

if [ -z "${RUNFILES_DIR:-}" ]; then
	# RUNFILES_DIR is not set by bazel for binaries, calculate it
    RUNFILES_DIR="${SCRIPT_DIR}/${SCRIPT_NAME}.runfiles/${WORKSPACE_NAME}"
else 
    # RUNFILES_DIR is already set by bazel for tests, just append workspace name
    RUNFILES_DIR="${RUNFILES_DIR}/${WORKSPACE_NAME}"
fi
INT_FULL_PATH="${RUNFILES_DIR}/${INT_PATH}"

unset PYTHONHOME
unset PYTHONPATH
unset PYTHONPLATLIBDIR
unset PYTHONSTARTUP
unset PYTHONUSERBASE
unset PYTHONEXECUTABLE
unset LD_LIBRARY_PATH

# TODO does not work with standalone built? (doesn't exist until python 3.11)
# use ast.compile + exec() with manual sys.path modification as workaround
export PYTHONSAFEPATH="1"
export PYTHONPATH="${RUNFILES_DIR}:${RUNFILES_DIR}/${WHEELS_DIR}"

exec "${INT_FULL_PATH}" ${INT_ARGS} ${ENTRYPOINT} $@