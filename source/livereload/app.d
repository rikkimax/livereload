module livereload.app;
import livereload.defs;

import vibe.d;

import std.file : getcwd, exists, isFile, read, chdir;
import std.process : execute, environment;
import std.path : buildPath;

shared {
	string pathToFiles;
    string configFile;
    string compiler = "dmd";
    string arch;
}

void main(string[] args) {
    cwdUpdate();
    getArgs();
    if (testForCompiler())
        return;
    if (checkFiles())
        return;

	new LiveReload(pathToFiles, compiler, arch, configFile);

	runEventLoop();
}

void cwdUpdate() {
    version(Windows) {
        if (environment.get("PWD", "") != "") {
            // most likely e.g. cygwin *grumble*
            auto value = execute(["cygpath", "-w", environment.get("PWD", "")]);
            if (value.output[$-1] == '\n')
                value.output.length--;
            chdir(environment.get("CD", value.output));
        } else {
            chdir(environment.get("CD", getcwd()));
        }
    } else {
        chdir(environment.get("PWD", environment.get("CD", getcwd())));
    }
}

void getArgs() {
    pathToFiles = getcwd();
    
    version(X86) {
        arch = "x86";
    } else version(X86_64) {
        arch = "x86_64";
    }
    
    getOption("path", cast(string*)&pathToFiles, "Path of the files to operate on");
    getOption("compiler", cast(string*)&compiler, "Compiler to use. Default: dmd");
    getOption("config", cast(string*)&configFile, "Configuration file to use. Default: ${--path}/livereload.txt");
    getOption("arch", cast(string*)&arch, "Architecture for the compiler to target. Default: x86 when built for 32bit and x86_64 for 64bit");

    finalizeCommandLineOptions();

    // this should equalize things a little bit
    pathToFiles = Path(pathToFiles).toNativeString();
}

bool testForCompiler() {
    if (testFor(compiler)) {
    } else if (testFor("gdc")) {
        compiler = "gdc";
    } else if (testFor("ldc")) {
        compiler = "ldc";
    } else {
        logError("No compiler on PATH variable");
        return true;
    }
    
    logInfo("Using compiler %s", compiler);

    if (!testFor("dub"))
        logError("Dub is not on the PATH variable");

    return false;
}

bool checkFiles() {
    if (configFile is null)
        configFile = buildPath(pathToFiles, "livereload.txt");
    
    if (!(exists(configFile) && isFile(configFile))) {
        logError("No valid configuration file found. Assumed %s", configFile);
        return true;
    }

    return false;
}

bool testFor(string app) {
	try {
		auto ret = execute(app);
		return true;
	} catch(Exception e) {
		return false;
	}
}