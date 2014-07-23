module livereload.app;
import livereload.defs;

import vibe.d;
import std.file : getcwd, exists, isFile, read;
import std.process : execute;
import std.path : buildPath;

shared {
	string pathToFiles;
}

void main(string[] args) {
	pathToFiles = getcwd();

	getOption("path", cast(string*)&pathToFiles, "Path of the files to operate on");
	string compiler = "dmd";
	getOption("compiler", &compiler, "Compiler to use. Default: dmd");
	string configFile;
	getOption("config", &configFile, "Configuration file to use. Default: ${--path}/livereload.txt");

	finalizeCommandLineOptions();

	// this should equalize things a little bit
	pathToFiles = buildPath(pathToFiles);

	if (testFor(compiler)) {
	} else if (testFor("gdc")) {
		compiler = "gdc";
	} else if (testFor("ldc")) {
		compiler = "ldc";
	} else {
		logError("No compiler on PATH variable");
		return;
	}

	logInfo("Using compiler %s", compiler);

	if (!testFor("dub"))
		logError("Dub is not on the PATH variable");

	if (configFile is null)
		configFile = buildPath(pathToFiles, "livereload.txt");

	if (!(exists(configFile) && isFile(configFile))) {
		logError("No valid configuration file found. Assumed %s", configFile);
		return;
	}

	new LiveReload(pathToFiles, compiler, configFile);
}

bool testFor(string app) {
	try {
		auto ret = execute(app);
		return true;
	} catch(Exception e) {
		return false;
	}
}