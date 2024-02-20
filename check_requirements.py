import hashlib
import os
import pathlib
import subprocess
import sys
import tempfile

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
subprocess.run([
	sys.executable,
	'-B',
    # '-E',
    '-s',
    '-S',
    # '-P', # does not exist?
    # '-I',
    '-m',
    'piptools',
    'compile',
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
    str(updated_requirements_txt.parent),
	'--output-file',
    str(updated_requirements_txt),
    str(requirements_in),
], check=True)

existing_file_hash = calc_hash_for_file(requirements_txt)
updated_file_hash = calc_hash_for_file(updated_requirements_txt)
if existing_file_hash != updated_file_hash:
    print('requirements file outdated', file=sys.stderr)
    sys.exit(1)
else:
    print('requirements file up-to-date', file=sys.stderr)
    sys.exit(0)
