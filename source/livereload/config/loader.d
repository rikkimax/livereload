module livereload.config.loader;
import livereload.config.defs;
import livereload.util;

enum LiveReloadConfigHeaderLine = "# live reload config";

LiveReloadConfig loadConfig(string text) {
	import std.string : toLower, splitLines;

	assert(text.length >= LiveReloadConfigHeaderLine.length, "Config file is not the correct syntax");
	assert(text[0 .. LiveReloadConfigHeaderLine.length].toLower == LiveReloadConfigHeaderLine.toLower, "Config file is not a config file.");

    LiveReloadConfig ret = LiveReloadConfig();
	parseLines(text.splitLines, ret);
	return ret;
}

unittest {
	auto t = loadConfig("""
# live reload config
"""[1 .. $-1]);

	assert(true);
}

unittest {
	auto t = loadConfig("""
# live reload config
code_unit: dynamic/routes/.*\\.d
code_unit: static/
output_dir: bins
"""[1 .. $-1]);

	assert(t.outputDir == "bins");

	assert(t.codeUnits.length == 2);
	assert(t.codeUnits[0] == "dynamic/routes/.*\\.d");
	assert(t.codeUnits[1] == "static/");
}

unittest {
	auto t = loadConfig("""
# live reload config
dir_dependencies:
	dynamic/routes/.*\\.d
		dynamic/caches/.*
		dynamic/templates/.*
		dynamic/public/.*
		dynamic/models/.*
		dynamic/config/.*
"""[1 .. $-1]);

	assert(t.dirDependencies.keys.length == 1);
	assert(t.dirDependencies.keys[0] == "dynamic/routes/.*\\.d");

	assert(t.dirDependencies.values[0].length == 5);
	assert(t.dirDependencies.values[0][0] == "dynamic/caches/.*");
	assert(t.dirDependencies.values[0][1] == "dynamic/templates/.*");
	assert(t.dirDependencies.values[0][2] == "dynamic/public/.*");
	assert(t.dirDependencies.values[0][3] == "dynamic/models/.*");
	assert(t.dirDependencies.values[0][4] == "dynamic/config/.*");
}

unittest {
	auto t = loadConfig("""
# live reload config
grab_dependency_from_output:
	template = dynamic/templates/.*
	datamodel = dynamic/models/.*
"""[1 .. $-1]);

	assert("template" in t.outputDependencies);
	assert(t.outputDependencies["template"].length == 1);
	assert(t.outputDependencies["template"][0] == "dynamic/templates/.*");

	assert("datamodel" in t.outputDependencies);
	assert(t.outputDependencies["datamodel"].length == 1);
	assert(t.outputDependencies["datamodel"][0] == "dynamic/models/.*");
}

void parseLines(string[] lines, ref LiveReloadConfig config) {
	import std.string : toLower, stripLeft, stripRight, indexOf;

	bool isDirDependencies;
	bool isDirDependencyOutput;
	string dirLocation;

	foreach(line; lines) {
		string stripped = line.stripLeft();
		size_t sizeDifStripped = line.length - stripped.length;
		stripped = stripped.stripRight;

		if (stripped == "")
			continue; // blank line
		else if (stripped[0] == '#')
			continue; // comment

		string[] lineA = stripped.split(" ");

		if (isDirDependencies) {
			if (sizeDifStripped == 0)
				isDirDependencies = false;

			if (lineA.length == 1) {
				if (sizeDifStripped == 1)
					dirLocation = stripped;
				else if (sizeDifStripped == 2)
					config.dirDependencies[dirLocation] ~= stripped;
			}
		}

		if (isDirDependencyOutput) {
			if (sizeDifStripped == 0)
				isDirDependencyOutput = false;
			else {
				ptrdiff_t equalI = stripped.indexOf("=");
				if (equalI > 0)
					config.outputDependencies[stripped[0 .. equalI].stripRight()] ~= stripped[equalI + 1 .. $].stripLeft();
			}
		}

		if (lineA.length > 0) {
			if (lineA[0].toLower == "dir_dependencies:") {
				isDirDependencies = true;
			} else if (lineA[0].toLower == "grab_dependency_from_output:") {
				isDirDependencyOutput = true;
			}
		}

		if (lineA.length > 1 && !isDirDependencies) {
			if (lineA[0].toLower == "code_unit:") {
				config.codeUnits ~= stripped[lineA[0].length + 1 .. $];
			} else if (lineA[0].toLower == "output_dir:") {
				config.outputDir = stripped[lineA[0].length + 1 .. $];
			}
		}
	}
}