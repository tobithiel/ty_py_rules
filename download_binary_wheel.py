import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

assert len(sys.argv) == 4
wheel_requirement_file = pathlib.Path(sys.argv[1])
assert wheel_requirement_file.exists()
assert wheel_requirement_file.is_file()
wheel_file = pathlib.Path(sys.argv[2])
assert not(wheel_file.exists())
assert wheel_file.parent.exists()
assert wheel_file.parent.is_dir()
wheel_file_name = pathlib.Path(sys.argv[3])
assert not(wheel_file_name.exists())
assert wheel_file_name.parent.exists()
assert wheel_file_name.parent.is_dir()

with tempfile.TemporaryDirectory() as tmpdir:
	tmp_wheel_dir = pathlib.Path(tmpdir)
	assert tmp_wheel_dir.exists()
	assert tmp_wheel_dir.is_dir()
	subprocess.run([
		sys.executable,
		'-B',
	    '-E',
	    '-s',
	    '-I',
	    '-m',
	    'pip',
	    'wheel',
	    '--quiet',
	    '--disable-pip-version-check',
	    '--isolated',
	    '--no-cache-dir',
	    '--no-input',
	    '--no-deps',
	    '--only-binary',
	    ':all:',
	    '--require-hashes',
	    '--wheel-dir',
	    str(tmp_wheel_dir),
	    '--requirement',
	    str(wheel_requirement_file),
	], check=True)
	downloaded_wheels = list(tmp_wheel_dir.iterdir())
	assert len(downloaded_wheels) == 1
	wheel = downloaded_wheels[0]
	with open(wheel_file_name, 'w') as f:
		f.write(wheel.name)
	shutil.move(downloaded_wheels[0], wheel_file)