import os
import pathlib
import subprocess
import sys

from piptools.scripts.compile import cli

assert len(sys.argv) == 2
requirements_in = pathlib.Path(sys.argv[1])
assert requirements_in.exists()
assert requirements_in.is_file()
requirements_txt_filename = f'{requirements_in.name}.txt'
assert requirements_in.name != requirements_txt_filename
build_working_dir = pathlib.Path(os.getenv('BUILD_WORKING_DIRECTORY', os.getcwd()))
assert build_working_dir.exists()
assert build_working_dir.is_dir()
# break out of sandbox to write the requirements file
requirements_txt = (build_working_dir / requirements_in).parent / requirements_txt_filename

cli([
    '--quiet',
    '--allow-unsafe',
    '--no-header',
    '--annotate',
    '--generate-hashes',
    '--reuse-hashes',
    '--emit-options',
    '--emit-index-url',
    '--emit-find-links',
    '--no-strip-extras',
    '--cache-dir',
    str(requirements_in.parent),
    '--output-file',
    str(requirements_txt),
    str(requirements_in),
])