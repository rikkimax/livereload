module livereload.config.compileinfo;
import livereload.config.defs;

/**
 * Given a compilable file in a directory that has a config file, what directories does it need to have compiled with it?
 * And how so?
 * 
 * Params:
 * 		config	=	The configuration file's parsed value
 * 		file	=	The compilable file name
 * 
 * Returns:
 * 		The directories that the dependency modules might be in and if it needs output to be parsed
 */
ProgramCompilationDependencies compileInfoBasedOn(LiveReloadConfig config, string file) {
	import std.regex : regex, matchAll;
	ProgramCompilationDependencies ret;

	// dir_dependencies:
	bool[string] temp;

	foreach(name, values; config.dirDependencies) {
		auto reg = regex(name);
		foreach(match; matchAll(file, reg)) {
			foreach(value; values)
				temp[value] = true;
		}
	}
	ret.dirs = temp.keys;

	// grab_dependency_from_output:
F1: foreach(name, values; config.outputDependencies) {
		foreach(value; values) {
			auto reg = regex(value);

			foreach(check; ret.dirs) {
				foreach(match; matchAll(check, reg)) {
					ret.readOutputForDependencies = true;
					break F1;
				}
			}
		}
	}

	return ret;
}

unittest {
	import livereload.config.loader;
	import std.algorithm : canFind;

	auto config = loadConfig("""
# live reload config
dir_dependencies:
	dynamic/routes/.*\\.d
		dynamic/caches/.*
		dynamic/templates/.*
		dynamic/public/.*
		dynamic/models/.*
		dynamic/config/.*

grab_dependency_from_output:
	template = dynamic/templates/.*
	datamodel = dynamic/models/.*
"""[1 .. $-1]);

	auto info = config.compileInfoBasedOn("dynamic/routes/test.d");

	assert(info.dirs.length == 5);
	assert(info.dirs.canFind("dynamic/caches/.*"));
	assert(info.dirs.canFind("dynamic/templates/.*"));
	assert(info.dirs.canFind("dynamic/public/.*"));
	assert(info.dirs.canFind("dynamic/models/.*"));
	assert(info.dirs.canFind("dynamic/config/.*"));

	assert(info.readOutputForDependencies);
}