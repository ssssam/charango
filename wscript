# Charango is nested within Calliope during development

test_execution_order = \
  ["utils-1",
   "context-1",
   "entity-1"]

import os
import subprocess
from waflib import Logs
from waflib import Options

def build_library (bld, **kws):
	#if True:
	if False:
		bld (features  = 'c cshlib', **kws)

	if True:
		bld (features  = 'c cstlib', **kws)

def build(bld):
	charango_uselib = 'RAPTOR REDLAND'
	charango_packages = 'redland'
	charango_vapi_dirs = '. vapi'

	# Build libraries
	#
	src_dir = bld.path.find_dir ('charango')
	build_library (bld,
	               source = src_dir.ant_glob('*.vala', src=True, dir=False),
	               target = 'charango',
	               uselib = charango_uselib,
	               packages = charango_packages,
	               # FIXME: For our custom vapi, they need merging to Vala
	               vapi_dirs = charango_vapi_dirs)

	kws = {
		'features': 'c cprogram',
		'packages': 'charango',
		'use': 'charango',
		'includes': ['.', './charango'],
		'vapi_dirs': charango_vapi_dirs,
		'install_path': None
	}

	# Build examples
	#
	examples_dir = bld.path.find_dir ('examples')

	for file in examples_dir.ant_glob('*.vala', src=True, dir=False):
		example = bld (source = file,
		               target = file.change_ext('').get_bld(),
		               **kws)

	if bld.env['HAVE_GTK'] == 1:
		examples_gtk_dir = examples_dir.find_dir ('gtk+')
		for file in examples_gtk_dir.ant_glob('*.vala', src=True, dir=False):
			kws_gtk = kws
			kws_gtk['uselib'] = 'GTK'
			kws_gtk['packages'] += ' gtk+-3.0'
			example = bld (source = file,
			               target = file.change_ext('').get_bld(),
			               **kws_gtk)

	# Build tests
	#
	tests_dir = bld.path.find_dir ('tests')
	for file in tests_dir.ant_glob('*.vala', src=True, dir=False):
		test = bld (source = file,
		            target = file.change_ext('').get_bld(),
		            **kws)

		# Set unit_test flag selectively so user can call:
		#   ./waf check --target=tests/foo-test
		# to just run one test
		if not Options.options.targets or (test.target.name in Options.options.targets.split(",")):
			test.unit_test = 1

def check (bld):
	# Make sure the tests are up to date, run 'check' after the build
	build (bld)
	bld.add_post_fun (check_action)

def check_action (bld):
	# Run tests through gtester
	#
	test_nodes = []
	for test in test_execution_order:
		test_obj = bld.get_tgen_by_name (test)

		if not hasattr (test_obj,'unit_test') or not getattr(test_obj, 'unit_test'):
			continue

		file_node = test_obj.target.abspath()
		test_nodes.append (file_node)

	gtester_run (bld, test_nodes)

from waflib.Build import BuildContext
class check_context(BuildContext):
	cmd = 'check'
	fun = 'check'

def gtester_run (bld, test_nodes):
	if not test_nodes:
		return

	gtester_params = [bld.env['GTESTER']]
	gtester_params.append ('--verbose');

	# A little black magic to make the tests run
	gtester_env = os.environ
	gtester_env['LD_LIBRARY_PATH'] = gtester_env.get('LD_LIBRARY_PATH', '') + \
	                                   ':' + bld.path.get_bld().abspath()

	for test in test_nodes:
		gtester_params.append (test)

	if Logs.verbose > 1:
		print gtester_params
	pp = subprocess.Popen (gtester_params,
	                       env = gtester_env)
	result = pp.wait ()
