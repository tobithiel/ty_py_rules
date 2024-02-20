import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

assert len(sys.argv) == 3
requirement_file = pathlib.Path(sys.argv[1])
assert requirement_file.exists()
assert requirement_file.is_file()
src_distribution_file = pathlib.Path(sys.argv[2])
assert not(src_distribution_file.exists())
assert src_distribution_file.parent.exists()
assert src_distribution_file.parent.is_dir()

with tempfile.TemporaryDirectory() as tmpdir:
	tmp_wheel_dir = pathlib.Path(tmpdir)
	assert tmp_wheel_dir.exists()
	assert tmp_wheel_dir.is_dir()
	subprocess.run([
		sys.executable,
		'-B',
	    '-E',
	    '-s',
	    # '-P', # does not exist?
	    '-I',
	    '-m',
	    'pip',
	    'download',
	    '--quiet',
	    '--disable-pip-version-check',
	    '--isolated',
	    '--no-cache-dir',
	    '--no-input',
	    '--no-deps',
	    '--no-binary',
	    ':all:',
	    '--require-hashes',
	    '--dest',
	    str(tmp_wheel_dir),
	    '--requirement',
	    str(requirement_file),
	], check=True)
	downloaded_distributions = list(tmp_wheel_dir.iterdir())
	assert len(downloaded_distributions) == 1
	shutil.move(downloaded_distributions[0], src_distribution_file)