import os
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile

import build

print(f'sys.argv: {sys.argv}')
print(f'sys.path: {sys.path}')

assert len(sys.argv) >= 5
src_dist_file = pathlib.Path(sys.argv[1])
assert src_dist_file.exists()
assert src_dist_file.is_file()
wheel_file = pathlib.Path(sys.argv[2])
assert not(wheel_file.exists())
assert wheel_file.parent.exists()
assert wheel_file.parent.is_dir()
wheel_file_name = pathlib.Path(sys.argv[3])
assert not(wheel_file_name.exists())
assert wheel_file_name.parent.exists()
assert wheel_file_name.parent.is_dir()
build_wheel_dependencies = pathlib.Path(sys.argv[4]).resolve() # needs to be absolute
assert build_wheel_dependencies.exists()
assert build_wheel_dependencies.is_dir()
src_dist_patch = None
if len(sys.argv) > 5:
	src_dist_patch = pathlib.Path(sys.argv[5])
	assert src_dist_patch.exists()
	assert src_dist_patch.is_file()

# add build dependencies to PYTHONPATH
pythonpath = os.environ['PYTHONPATH']
os.environ['PYTHONPATH'] = f'{build_wheel_dependencies}:{pythonpath}'

with tempfile.TemporaryDirectory() as tmpdir:
	tmp_src_dist_dir = pathlib.Path(tmpdir)
	with tarfile.TarFile.open(src_dist_file) as src_dist_tar:
		src_dist_tar.extractall(tmp_src_dist_dir)
	src_dist_dir_top_level_contents = list(tmp_src_dist_dir.iterdir())
	assert len(src_dist_dir_top_level_contents) == 1
	tmp_src_dist_dir = tmp_src_dist_dir / src_dist_dir_top_level_contents[0]

	if src_dist_patch is not None:
		print(f'patch cwd: {os.getcwd()}')
		subprocess.check_call(['patch', '-p1', '-d', str(tmp_src_dist_dir), '-i', str(src_dist_patch.resolve())])

	with tempfile.TemporaryDirectory() as tmpdir2:
		tmp_wheel_dir = pathlib.Path(tmpdir2)

		builder = build.ProjectBuilder(tmp_src_dist_dir)
		builder.build(distribution='wheel', output_directory=tmp_wheel_dir)

		downloaded_wheels = list(tmp_wheel_dir.iterdir())
		assert len(downloaded_wheels) == 1
		wheel = downloaded_wheels[0]
		with open(wheel_file_name, 'w') as f:
			f.write(wheel.name)
		shutil.move(downloaded_wheels[0], wheel_file)