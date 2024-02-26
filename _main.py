import pathlib
import os
import sys

assert len(sys.argv) > 1
# before python 3.11, -P (PYTHONSAFEPATH) does not exist,
# so we're faking it with these extra entrypoint. We're
# sanitizing sys.path
actual_entrypoint_filename = sys.argv[1]

# remove our custom entrypoint from argv
del sys.argv[0]
# remove extra path from sys.path
our_path = pathlib.Path(__file__)
our_resolved_path = our_path.resolve()
# we're expecting `our_path` to be a symlink
# to `our_resolved_path`. Bazel might change this
# in the future
assert our_path != our_resolved_path
for idx, p in enumerate(sys.path):
	if pathlib.Path(p) == our_resolved_path.parent:
		del sys.path[idx]
		break
else:
	raise ValueError('Could not find resolved file on sys.path')

# now we can actually execute the code we want to
with open(actual_entrypoint_filename, 'r') as f:
	code = compile(f.read(), actual_entrypoint_filename, 'exec')
exec(code)
