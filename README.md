livereload
==========

Manages live reloading capabilities for e.g. Cmsed

Example configuration file
```
# live reload config

dub_dependency_dir: deps

# code_unit: is a glob
code_unit: dynamic/routes/*.d
code_unit: static
output_dir: bin

dir_dependencies:
	# is a glob
	dynamic/routes/*.d
		# is a regex
		dynamic/caches/*.d
		dynamic/templates/*
		dynamic/models/*.d
		dynamic/config/*
		static/caches/*.d
		static/templates/*
		static/models/*.d
		static/config/*

grab_dependency_from_output:
	# is a regex
	template = dynamic/templates/*
	datamodel = dynamic/models/*.d
	template = static/templates/*
	datamodel = static/models/*.d

# is a regex
dir_with_version: LiveReloadDynamicLoad dynamic/*
dir_with_version: LiveReloadStaticLoad static/*
```
Please note the first line is required.<br/>
For dub dependencies, auto regeneration is currently disabled.<br/>
You are required to manually do it at this stage.<br/>

**Dub dependency directory structure:**
* deps/imports/code_unit_name/*.di
* deps/bin/code_unit_name_[x86|x86_64].lib<br/>
Where code_unit_name is automatically generated from the code unit path aka the first directory under the project root directory.


TODO:
-------
Inventory service has not been written. So that is first thing to be worked on.

* Shared library support
* GDC/LDC
* More customisation for dub dependency<br/>
  Currently only supports imports/code_unit_name and bin/code_unit_name.lib for lookup.
* Better documentation
