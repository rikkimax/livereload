livereload
==========

Manages live reloading capabilities for e.g. Cmsed

Example configuration file
```
# live reload config

# code_unit: is a glob
code_unit: dynamic/routes/*.d
code_unit: static
output_dir: bin

dir_dependencies:
	# is a glob
	dynamic/routes/*.d
		# is a glob
		dynamic/caches/*.d
		dynamic/templates/*
		dynamic/models/*.d
		dynamic/config/*
	static/*
		static/templates/*
		static/config/*

grab_dependency_from_output:
	# is a glob
	template = dynamic/templates/*
	datamodel = dynamic/models/*.d
	template = static/templates/*
	datamodel = static/models/*.d
```
Please note the first line is required.<br/>
Stdout is stored as: bin/OUTPUTDIRNAME/stdout.log<br/>
Note OUTPUTDIRNAME is generated based on e.g. time and file.

Currently Dub does not like to include itself.<br/>
Work around:<br/>
In some directory aka your projects directory (non local to livereload)<br/>
$ git clone https://github.com/D-Programming-Language/dub.git
$ git checkout 0.9.22
$ dub add-local .

TODO:
-----
* Release builds
