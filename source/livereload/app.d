/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 Richard Andrew Cattermole
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module livereload.app;
import livereload.impl;

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