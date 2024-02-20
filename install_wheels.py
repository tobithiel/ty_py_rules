import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

assert len(sys.argv) == 3
wheels_file = pathlib.Path(sys.argv[1])
assert wheels_file.exists()
assert wheels_file.is_file()
install_dir = pathlib.Path(sys.argv[2])
assert not(install_dir.exists()) or len(list(install_dir.iterdir())) == 0
assert install_dir.parent.exists()
assert install_dir.parent.is_dir()

with open(wheels_file, 'r') as f:
	for line in f:
		parts = line.strip().split(',')
		assert len(parts) == 2
		wheel_file, name_file = parts
		wheel_file = pathlib.Path(wheel_file)
		name_file = pathlib.Path(name_file)
		assert wheel_file.exists()
		assert wheel_file.is_file()
		assert name_file.exists()
		assert name_file.is_file()
		with open(name_file, 'r') as f:
			wheel_filename = f.read()
		with tempfile.TemporaryDirectory() as tmpdir:
			tmpdir_path = pathlib.Path(tmpdir)
			wheel_path = tmpdir_path / wheel_filename
			assert not(wheel_path.exists())
			wheel_path.symlink_to(wheel_file.resolve())
			subprocess.run([
				sys.executable,
				'-B',
			    '-E',
			    '-s',
	    		# '-P', # does not exist?
			    '-I',
			    '-m',
			    'pip',
			    'install',
			    '--quiet',
			    '--disable-pip-version-check',
			    '--isolated',
			    '--no-cache-dir',
			    '--no-input',
			    '--no-deps',
			    '--upgrade',
			    '--target',
			    str(install_dir),
			    str(wheel_path),
			], check=True)
