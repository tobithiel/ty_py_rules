import difflib
import hashlib
import os
import pathlib
import subprocess
import sys
import tempfile

from piptools.scripts.compile import cli

assert len(sys.argv) == 3
requirements_in = pathlib.Path(sys.argv[1])
assert requirements_in.exists()
assert requirements_in.is_file()
requirements_txt = pathlib.Path(sys.argv[2])
assert requirements_txt.exists()
assert requirements_txt.is_file()

def calc_hash_for_file(path):
    sha1 = hashlib.sha1()
    with open(path, 'rb') as f:
        sha1.update(f.read())
    return sha1.hexdigest()

updated_requirements_txt = pathlib.Path(os.environ['TEST_UNDECLARED_OUTPUTS_DIR']) / 'requirements.txt'
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
    str(updated_requirements_txt),
    str(requirements_in),
])

existing_file_hash = calc_hash_for_file(requirements_txt)
updated_file_hash = calc_hash_for_file(updated_requirements_txt)
if existing_file_hash != updated_file_hash:
    print('requirements file outdated', file=sys.stderr)
    with open(requirements_txt, 'r') as f:
        requirements_txt_lines = f.readlines()
    with open(updated_requirements_txt, 'r') as f:
        updated_requirements_txt_lines = f.readlines()
    print(requirements_txt_lines)
    for line in difflib.unified_diff(requirements_txt_lines, updated_requirements_txt_lines, fromfile=str(requirements_txt), tofile=str(updated_requirements_txt)):
        print(line)
    sys.exit(1)
else:
    print('requirements file up-to-date', file=sys.stderr)
    sys.exit(0)
