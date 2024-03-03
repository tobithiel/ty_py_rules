load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

TOOLCHAIN_TYPE_TARGET = "//:toolchain_type"

MyPythonToolchainInfo = provider(
    "Info needed to run python code.",
    fields={
        "interpreter_path": "path to interpreter.",
        "interpreter_args": "arguments to interpreter.",
        "extra_internal_interpreter_args": "extra arguments to interpreter for internal strict usage.",
    })

MyPythonInfo = provider(
    "Info needed to run python code.",
    fields={
        "transitive_sources": "transitive_sources",
        "transitive_data": "transitive_data",
        "transitive_wheels": "transitive_wheels",
    })


def _get_transitive_srcs(srcs, deps):
    return depset(
        direct = srcs,
        transitive = [dep[MyPythonInfo].transitive_sources for dep in deps],
    )


def _get_transitive_data(data, deps):
    return depset(
        direct = data,
        transitive = [dep[MyPythonInfo].transitive_data for dep in deps],
    )


def _get_transitive_whls(deps):
    return depset(
        transitive = [dep[MyPythonInfo].transitive_wheels for dep in deps],
    )


def _my_py_toolchain_info_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        my_py_info = MyPythonToolchainInfo(
            interpreter_path = ctx.file.interpreter_path,
            interpreter_args = ctx.attr.interpreter_args,
            extra_internal_interpreter_args = ctx.attr.extra_internal_interpreter_args,
        ),
    )
    return [toolchain_info]

my_py_toolchain_info = rule(
    implementation = _my_py_toolchain_info_impl,
    attrs = {
        "interpreter_path": attr.label(mandatory=True, allow_single_file=True),
        "interpreter_args": attr.string_list(
            default=['-B', '-s', '-S'], # , '-P' doesn't exist? (new in 3.11)
        ),
        "extra_internal_interpreter_args": attr.string_list(
            default = ['-E', '-I'],
        ),
    },
)

def my_py_toolchain(
    name,
    interpreter_path,
    exec_compatible_with,
    target_compatible_with,
    interpreter_args = None,
    extra_internal_interpreter_args = None,
):
    toolchain_info_name = name + '_toolchain_info'
    
    my_py_toolchain_info(
        name = toolchain_info_name,
        interpreter_path = interpreter_path,
        interpreter_args = interpreter_args,
        extra_internal_interpreter_args = extra_internal_interpreter_args,
    )
    native.toolchain(
        name = name,
        toolchain = ':' + toolchain_info_name,
        toolchain_type = TOOLCHAIN_TYPE_TARGET,
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )


def my_py_indygreg_standalone(
    name,
    sha256,
    url,
):
    EXPECTED_URL_PREFIX = 'https://github.com/indygreg/python-build-standalone/releases/download/'
    if not url.startswith(EXPECTED_URL_PREFIX):
        fail('Unsupported URL, expected prefix: ' + EXPECTED_URL_PREFIX)
    http_archive(
        name = name,
        url = url,
        sha256 = sha256,
        strip_prefix = 'python/install/',
        build_file_content = 'exports_files(["bin/python3"])',
    )


def _my_py_system_python_impl(rctx):
    full_path = rctx.which(rctx.attr.interpreter_path)
    if not full_path:
        fail('Could not find python installation with path: '+ rctx.attr.interpreter_path)
    rctx.symlink(full_path, 'python')
    rctx.file('BUILD.bazel', 'exports_files(["python"])')
    
my_py_system_python = repository_rule(
    implementation = _my_py_system_python_impl,
    attrs = {
        "interpreter_path": attr.string(mandatory=True),
    },
)


# TODO separate into example workspace and the rules workspace


def compile_requirements(
    name,
    requirements_in,
):
    my_py_binary(
        name = name + '.update',
        main = 'compile_requirements.py',
        deps = [
            '@internal_reqs//pip-tools',
        ],
        data = [
            requirements_in,
        ],
        args = [
            '$(location ' + requirements_in + ')',
        ],
    )
    my_py_bare_test(
        name = name + '.test',
        main = 'check_requirements.py',
        deps = [
            '@internal_reqs//pip-tools',
        ],
        data = [
            requirements_in,
            requirements_in + '.txt',
        ],
        args = [
            '$(location ' + requirements_in + ')',
            '$(location ' + requirements_in + '.txt)',
        ],
        tags = [
            'requires-network',
        ],
    )


def _fold_newlines(txt):
    lines = txt.splitlines()
    folded_lines = []
    line_buffer = ''
    for line in lines:
        is_end_of_folded_line = not line.endswith('\\')
        if is_end_of_folded_line:
            line_buffer += line
        else:
            line_buffer += line[:-1]
        if is_end_of_folded_line:
            folded_lines.append(line_buffer)
            line_buffer = ''
    return '\n'.join(folded_lines)


def _fold_dep_comments(txt):
    lines = txt.splitlines()
    processed_lines = []
    saw_req = False
    in_dep_comment = False
    has_first_dep = False
    req_buffer = ''
    for line in lines:
        comment_start_pos = line.find('#')
        dep_comment_start_pos = line.find('# via')
        if len(line.strip()) == 0:
            # empty line resets state
            processed_lines.append(req_buffer)
            saw_req = False
            in_dep_comment = False
            has_first_dep = False
            req_buffer = ''

        if not(saw_req) and comment_start_pos < 0:
            # start of requirement
            saw_req = True
            in_dep_comment = False
            req_buffer = ''
            req_buffer += line
        elif not(saw_req) and comment_start_pos == 0:
            # regular comment line
            saw_req = False
            in_dep_comment = False
            processed_lines.append(line)
        elif not(saw_req) and comment_start_pos > 0:
            fail('unexpected comment')
        elif saw_req and dep_comment_start_pos >= 0 and not(in_dep_comment):
            # start of dep comment
            comment_content = line[dep_comment_start_pos + 5:].strip()
            if comment_content.startswith('-r'):
                req_buffer += ' # via'
                has_first_dep = False
            else:
                req_buffer += ' '
                req_buffer += line.strip()
                has_first_dep = True
            in_dep_comment = True
        elif saw_req and comment_start_pos >= 0 and in_dep_comment:
            # continuation of dep comment
            comment_content = line[comment_start_pos + 1:].strip()
            if not comment_content.startswith('-r'):
                if has_first_dep:
                    req_buffer += ','
                req_buffer += comment_content
                has_first_dep = True
        elif saw_req and comment_start_pos < 0:
            # start of next requirement
            processed_lines.append(req_buffer)
            saw_req = True
            in_dep_comment = False
            req_buffer = ''
            req_buffer += line
        elif saw_req and comment_start_pos >= 0 and dep_comment_start_pos < 0:
            # just regular comment
            processed_lines.append(req_buffer)
            saw_req = False
            in_dep_comment = False
            req_buffer = ''
            req_buffer += line
            processed_lines.append(line)
        else:
            fail('unexpected state')
    
    processed_lines.append(req_buffer)
    return '\n'.join(processed_lines)


def _skip_comments(txt):
    lines = txt.splitlines()
    processed_lines = []
    in_dep_comment = False
    for line in lines:
        command_start_pos = line.find('#')
        if command_start_pos == 0:
            continue
        elif command_start_pos == -1:
            processed_lines.append(line)
        else:
            if line[command_start_pos:].startswith('# via'):
                # keep dependency comments
                processed_lines.append(line.strip())
            else:
                processed_lines.append(line[:command_start_pos])

    return '\n'.join(processed_lines)

def _my_py_requirements_parser(txt):
    txt = _skip_comments(_fold_dep_comments(_fold_newlines(txt)))
    lines = txt.splitlines()
    requirements_dict = {}
    deps = {}
    for requirement_line in lines:
        if len(requirement_line.strip()) == 0:
            continue
        if requirement_line.strip().startswith('-'):
            fail('not supporting options right now')
        end_distribution_name_pos = requirement_line.find('=')
        if end_distribution_name_pos <= 0:
            fail('Could not find end of distribution name')
        distribution_name = requirement_line[:end_distribution_name_pos].strip()
        dep_comment_start_pos = requirement_line.find('# via')
        rev_deps = []
        if dep_comment_start_pos > 0:
            requirement = requirement_line[:dep_comment_start_pos].strip()
            rev_deps = requirement_line[dep_comment_start_pos + 5:].split(',')
        else:
            requirement = requirement_line
        requirements_dict[distribution_name] = requirement
        for rev_dep in rev_deps:
            rev_dep = rev_dep.strip()
            if len(rev_dep) == 0:
                continue
            if rev_dep not in deps:
                deps[rev_dep] = []
            deps[rev_dep].append(distribution_name)

    requirements = []
    for distribution_name, requirement in requirements_dict.items():
        if distribution_name not in deps:
            deps[distribution_name] = []
        requirements.append((distribution_name, requirement, deps[distribution_name]))
    return requirements

def _req_target_name(req_name, distribution_name):
    return req_name + '_' + distribution_name

def _format_repr_list(l):
    return '[{}]'.format(', '.join([repr(e) for e in l]))

def _format_string_list_dict(sld):
    return '{{ {} }}'.format(', '.join(['{}: {}'.format(repr(k), _format_repr_list(vs)) for k, vs in sld.items()]))

def _my_py_pip_repository_impl(rctx):
    txt = rctx.read(rctx.attr.requirements)
    requirements = _my_py_requirements_parser(txt)
    requirements_with_name = []
    for (distribution_name, requirement, deps) in requirements:
        name = _req_target_name(rctx.attr.name, distribution_name)
        deps_named = ['@' + _req_target_name(rctx.attr.name, dep) for dep in deps]
        requirements_with_name.append((
            name,
            distribution_name,
            requirement,
            deps_named,
        ))
    rctx.file('BUILD.bazel', '')

    bin_wheels = []
    src_dists = []
    for req_with_name in requirements_with_name:
        force_wheel = req_with_name[1] in rctx.attr.always_wheel
        force_src_dist = req_with_name[1] in rctx.attr.always_src_dist
        if force_wheel and force_src_dist:
            fail("Can't force " + req_with_name[0] + " to wheel and src distribution")
        if force_wheel:
            bin_wheels.append(req_with_name)
        elif force_src_dist:
            src_dists.append(req_with_name)
        elif rctx.attr.prefer_wheels:
            bin_wheels.append(req_with_name)
        else:
            src_dists.append(req_with_name)

    build_deps_named = {}
    for distribution_name, build_deps in rctx.attr.wheel_build_deps.items():
        build_deps_named[_req_target_name(rctx.attr.name, distribution_name)] = [
            '@' + _req_target_name(rctx.attr.name, build_dep)
            for build_dep in build_deps
        ]
    extra_deps_named = {}
    for distribution_name, extra_deps in rctx.attr.extra_deps.items():
        extra_deps_named[_req_target_name(rctx.attr.name, distribution_name)] = [
            '@' + _req_target_name(rctx.attr.name, extra_dep)
            for extra_dep in extra_deps
        ]
    rctx.template(
        'requirements.bzl',
        rctx.attr._template,
        substitutions = {
            '{{INTERPRETER}}': repr(rctx.attr.interpreter),
            '{{BIN_WHEELS}}': _format_repr_list(bin_wheels),
            '{{SRC_DISTS}}': _format_repr_list(src_dists),
            '{{EXTRA_DEPS}}': _format_string_list_dict(extra_deps_named),
            '{{SRC_DISTS_BUILD_DEPS}}': _format_string_list_dict(build_deps_named),
        },
    )
    for (name, distribution_name, _, _) in requirements_with_name:
        rctx.file(distribution_name + '/BUILD.bazel', "alias(name='" + distribution_name + "', actual='@" + name + "', visibility = ['//visibility:public'])")


my_py_pip_repository = repository_rule(
    implementation = _my_py_pip_repository_impl,
    attrs = {
        "requirements": attr.label(allow_single_file=True, mandatory=True),
        "interpreter": attr.label(mandatory=True),
        "prefer_wheels": attr.bool(default=False),
        "always_src_dist": attr.string_list(),
        "always_wheel": attr.string_list(),
        "extra_deps": attr.string_list_dict(),
        "wheel_build_deps": attr.string_list_dict(),
        "_template": attr.label(allow_single_file=True, default='_deps.bzl.tmpl'),
    },
)





def _my_py_bin_wheel_downloader_impl(rctx):
    wheel_requirement_file = rctx.attr.name + '_requirement.txt'
    rctx.file(wheel_requirement_file, rctx.attr.requirement)
    wheel_file = rctx.attr.name + '.whl'
    wheel_name_file = rctx.attr.name + '.whl.name'
    rctx.execute(
        [rctx.path(rctx.attr.interpreter).realpath] + [
            rctx.path(rctx.attr._binary_wheel_downloader).realpath,
            wheel_requirement_file,
            wheel_file,
            wheel_name_file,
        ],
    )
    rctx.file('BUILD.bazel', """load('@//:defs.bzl', 'my_py_bin_wheel')

my_py_bin_wheel(
    name = '""" + rctx.attr.name + """',
    wheel = '//:""" + wheel_file + """',
    wheel_name = '//:""" + wheel_name_file + """',
    deps = [""" + ', '.join(["'" + str(dep) + "'" for dep in rctx.attr.deps]) + """],
    visibility = ['//visibility:public'],
)""")


my_py_bin_wheel_downloader = repository_rule(
  implementation = _my_py_bin_wheel_downloader_impl,
  attrs = {
    "requirement": attr.string(mandatory=True),
    "deps": attr.string_list(),
    "interpreter": attr.label(mandatory=True),
    "_binary_wheel_downloader": attr.label(
        allow_single_file = [".py"],
        # can't be a tool due to repository rule
        default = "download_binary_wheel.py",
    ),
  },
)

def _my_py_bin_wheel_impl(ctx):
    transitive_wheels = _get_transitive_whls(ctx.attr.deps)
    return [
        DefaultInfo(files=depset([ctx.file.wheel, ctx.file.wheel_name])),
        MyPythonInfo(
            transitive_sources = depset([]),
            transitive_data = depset([]),
            transitive_wheels = depset(
                direct = [
                    struct(wheel_file=ctx.file.wheel, name_file=ctx.file.wheel_name),
                ],
                transitive = [transitive_wheels],
            ),
        ),
    ]


my_py_bin_wheel = rule(
  implementation = _my_py_bin_wheel_impl,
  attrs = {
    "wheel": attr.label(allow_single_file = [".whl"], mandatory=True),
    "wheel_name": attr.label(allow_single_file = [".whl.name"], mandatory=True),
    "deps": attr.label_list(providers = [MyPythonInfo]),
  },
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = False,
  test = False,
)



def _my_py_src_dist_downloader_impl(rctx):
    wheel_requirement_file = rctx.attr.name + '_requirement.txt'
    rctx.file(wheel_requirement_file, rctx.attr.requirement)
    src_dist_file = rctx.attr.name + '.tar.gz'
    rctx.execute(
        [rctx.path(rctx.attr.interpreter).realpath] + [
            rctx.path(rctx.attr._src_dist_downloader).realpath,
            wheel_requirement_file,
            src_dist_file,
        ],
    )
    rctx.file('BUILD.bazel', """load('@//:defs.bzl', 'my_py_bin_wheel_from_src_dist')

my_py_bin_wheel_from_src_dist(
    name = '""" + rctx.attr.name + """',
    src_dist = '//:""" + src_dist_file + """',
    deps = [""" + ', '.join(["'" + str(dep) + "'" for dep in rctx.attr.deps]) + """],
    build_deps = [""" + ', '.join(["'" + str(build_dep) + "'" for build_dep in rctx.attr.build_deps]) + """],
    visibility = ['//visibility:public'],
)""")


my_py_src_dist_downloader = repository_rule(
  implementation = _my_py_src_dist_downloader_impl,
  attrs = {
    "requirement": attr.string(mandatory=True),
    "deps": attr.string_list(),
    "build_deps": attr.string_list(),
    "interpreter": attr.label(mandatory=True),
    "_src_dist_downloader": attr.label(
        allow_single_file = [".py"],
        # can't be a tool due to repository rule
        default = "download_source_distribution.py",
    ),
  },
)

def _my_py_bin_wheel_from_src_dist_impl(ctx):
    transitive_wheels = _get_transitive_whls(ctx.attr.deps)

    wheel_file = ctx.actions.declare_file(ctx.label.name + '.whl')
    wheel_name_file = ctx.actions.declare_file(ctx.label.name + '.whl.name')
    transitive_build_whls = _get_transitive_whls(ctx.attr.build_deps)
    build_wheels_dir = _install_wheels(ctx, transitive_build_whls.to_list(), '.build')
    ctx.actions.run(
        mnemonic = "BuildWheel",
        executable = ctx.file._wheel_builder,
        arguments = [
            ctx.file.src_dist.path,
            wheel_file.path,
            wheel_name_file.path,
            build_wheels_dir.path,
        ],
        tools = ctx.attr._wheel_builder.files,
        inputs = [ctx.file.src_dist, build_wheels_dir],
        outputs = [wheel_file, wheel_name_file],
    )

    return [
        DefaultInfo(files=depset([wheel_file, wheel_name_file])),
        MyPythonInfo(
            transitive_sources = depset([]),
            transitive_data = depset([]),
            transitive_wheels = depset(
                direct = [
                    struct(wheel_file=wheel_file, name_file=wheel_name_file),
                ],
                transitive = [transitive_wheels],
            ),
        ),
    ]

my_py_bin_wheel_from_src_dist = rule(
  implementation = _my_py_bin_wheel_from_src_dist_impl,
  attrs = {
    "src_dist": attr.label(allow_single_file = True, mandatory=True),
    "deps": attr.label_list(providers = [MyPythonInfo]),
    "build_deps": attr.label_list(providers = [MyPythonInfo]),
    "_wheel_builder": attr.label(
        default = "//:wheel_builder",
        executable = True,
        cfg = "exec",
        allow_single_file = True,
    ),
    "_wheels_installer": attr.label(
        default = "//:install_wheels",
        executable = True,
        cfg = "exec",
        allow_single_file = True,
    ),
  },
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = False,
  test = False,
)


def _my_py_library_impl(ctx):
    info = ctx.toolchains[TOOLCHAIN_TYPE_TARGET].my_py_info

    transitive_sources = _get_transitive_srcs(ctx.files.srcs, ctx.attr.deps)
    transitive_data = _get_transitive_srcs(ctx.files.srcs, ctx.attr.data)
    transitive_wheels = _get_transitive_whls(ctx.attr.deps)

    return [
        DefaultInfo(
            files = transitive_sources,
        ),
        MyPythonInfo(
            transitive_sources = transitive_sources,
            transitive_data = transitive_data,
            transitive_wheels = transitive_wheels,
        ),
    ]


my_py_library = rule(
  implementation = _my_py_library_impl,
  attrs = {
    "srcs": attr.label_list(allow_files = [".py"], mandatory=True),
    "deps": attr.label_list(providers = [MyPythonInfo]),
    "data": attr.label_list(allow_files = True),
  },
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = False,
  test = False,
)


def _install_wheels(ctx, wheels, suffix):
    wheels_manifest = ctx.actions.declare_file(ctx.label.name + suffix + '.wheels.txt')
    ctx.actions.write(
        output = wheels_manifest,
        content = '\n'.join([wheel.wheel_file.path + ',' + wheel.name_file.path for wheel in wheels]),
    )
    wheels_dir = ctx.actions.declare_directory(ctx.label.name + suffix + '.wheels')
    ctx.actions.run(
        mnemonic = "InstallWheels",
        executable = ctx.file._wheels_installer,
        arguments = [
            wheels_manifest.path,
            wheels_dir.path,
        ],
        tools = ctx.attr._wheels_installer.files,
        inputs = [wheels_manifest] + [whl.wheel_file for whl in wheels] + [whl.name_file for whl in wheels],
        outputs = [wheels_dir],
    )
    return wheels_dir


_common_exec_attrs = {
    "main": attr.label(allow_single_file = [".py"], mandatory=True),
    "data": attr.label_list(allow_files = True),
    "_template": attr.label(
        allow_single_file = True,
        default = "_main.sh.tpl",
    ),
    "_entrypoint": attr.label(
        allow_single_file = True,
        default = "_main.py",
    ),
}
_common_exec_deps_attrs = {
    "deps": attr.label_list(providers = [MyPythonInfo]),
    "_wheels_installer": attr.label(
        default = "//:install_wheels",
        executable = True,
        cfg = "exec",
        allow_single_file = True,
    ),
}
_common_exec_with_deps_attrs = dict(**_common_exec_attrs)
_common_exec_with_deps_attrs.update(**_common_exec_deps_attrs)

def _my_py_binary_or_test(
    ctx,
    extra_deps,
    entrypoint_override,
):
    info = ctx.toolchains[TOOLCHAIN_TYPE_TARGET].my_py_info

    transitive_srcs = depset()
    transitive_data = depset()
    transitive_whls = depset()
    if hasattr(ctx.attr, 'deps'):
        transitive_srcs = _get_transitive_srcs(ctx.files.main, ctx.attr.deps + extra_deps)
        transitive_data = _get_transitive_data(ctx.files.data, ctx.attr.deps + extra_deps)
        transitive_whls = _get_transitive_whls(ctx.attr.deps + extra_deps)

    all_wheels = transitive_whls.to_list()
    wheels_dir = None
    if len(all_wheels) > 0:
        wheels_dir = _install_wheels(ctx, all_wheels, '')
    
    executable = ctx.actions.declare_file(ctx.label.name)
    actual_entrypoint = ctx.file.main.path
    if entrypoint_override:
        if wheels_dir == None:
            fail('entrypoint_override requires wheel depedencies')
        actual_entrypoint = wheels_dir.short_path + '/' + entrypoint_override + ' ' + ctx.file.main.path
    ctx.actions.expand_template(
        output = executable,
        template = ctx.file._template,
        substitutions = {
            "{{INTERPRETER_PATH}}": info.interpreter_path.path,
            "{{INTERPRETER_ARGS}}": ' '.join(info.interpreter_args),
            "{{WORKSPACE_NAME}}": ctx.workspace_name,
            "{{WHEELS_DIR}}": wheels_dir.short_path if wheels_dir else '',
            "{{ENTRYPOINT}}": ctx.file._entrypoint.path,
            "{{ACTUAL_ENTRYPOINT}}": actual_entrypoint,
        },
    )
    wheels_deps = []
    if wheels_dir:
        wheels_deps.append(wheels_dir)

    return [
        DefaultInfo(
            executable=executable,
            runfiles=ctx.runfiles(
                files=[info.interpreter_path, ctx.file._entrypoint, ctx.file.main] + wheels_deps,
                transitive_files=depset(transitive=[transitive_srcs, transitive_data]),
            ),
        ),
    ]


def _my_py_binary_impl(ctx):
    return _my_py_binary_or_test(ctx, [], None)


my_py_binary = rule(
  implementation = _my_py_binary_impl,
  attrs = _common_exec_with_deps_attrs,
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = True,
  test = False,
)


def _my_py_binary_no_deps_impl(ctx):
    return _my_py_binary_or_test(ctx, [], None)


my_py_binary_no_deps = rule(
  implementation = _my_py_binary_no_deps_impl,
  attrs = _common_exec_attrs,
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = True,
  test = False,
)


def _my_py_test_impl(ctx):
    return _my_py_binary_or_test(ctx, ctx.attr._extra_deps, ctx.attr._entrypoint_override)

my_py_test = rule(
  implementation = _my_py_test_impl,
  attrs = dict(
    {
        '_extra_deps': attr.label_list(providers = [MyPythonInfo], default=['@internal_reqs//pytest']),
        '_entrypoint_override': attr.string(default='pytest/__main__.py'),
    },
    **_common_exec_with_deps_attrs),
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = True,
  test = True,
)


def _my_py_bare_test_impl(ctx):
    return _my_py_binary_or_test(ctx, [], None)

my_py_bare_test = rule(
  implementation = _my_py_bare_test_impl,
  attrs = _common_exec_with_deps_attrs,
  toolchains = [
    config_common.toolchain_type(TOOLCHAIN_TYPE_TARGET, mandatory=True),
  ],
  executable = True,
  test = True,
)