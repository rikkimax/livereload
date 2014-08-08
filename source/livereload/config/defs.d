module livereload.config.defs;
public import livereload.config.loader : loadConfig;
public import livereload.config.compileinfo : compileInfoBasedOn;

struct LiveReloadConfig {
	string outputDir;
	string[] codeUnits;
	string[][string] dirDependencies;
	string[][string] outputDependencies;
}

struct ProgramCompilationDependencies {
	bool readOutputForDependencies;
	string[] dirs;
}