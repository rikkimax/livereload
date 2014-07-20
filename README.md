livereload
==========

Manages live reloading capabilities for e.g. Cmsed

Example configuration file
```
# live reload config

dub_dependency_dir: deps
code_unit: dynamic/routes/.*\.d
code_unit: static
output_dir: bin

dir_dependencies:
	dynamic/routes/.*\.d
		dynamic/caches/*.d
		dynamic/templates/*
		dynamic/models/*.d
		dynamic/config/*
		static/caches/*.d
		static/templates/*
		static/models/*.d
		static/config/*

grab_dependency_from_output:
	template = dynamic/templates/.*
	datamodel = dynamic/models/.*\.d
	template = static/templates/.*
	datamodel = static/models/.*\.d
	
dir_with_version: LiveReloadDynamicLoad dynamic/.*
dir_with_version: LiveReloadStaticLoad static/.*
```
Please note the first line is required.<br/>
Within dir_dependencies the second tier is globs, not regex.

TODO:
-------
Inventory service has not been written. So that is first thing to be worked on.

* Shared library support
* GDC/LDC
* Code unit names?
* More customisation for dub dependency
* Better documentation
