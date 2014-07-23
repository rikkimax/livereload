﻿module livereload.services.compiler_dmd;
import livereload.services.compiler;
import livereload.config.defs;
import livereload.util : replace, split;
import livereload.app;
import std.regex : regex, matchAll;
import std.file : dirEntries, SpanMode;
import std.process : execute;

/**
 * Compiles a node, given the files that should be included
 * 
 * TODO:
 * 		Currently is assuming dmd for arguments
 * 
 * Params:
 * 		name 	=	The output file to create
 * 		files	=	The files to compile into a node
 * 		config	=	The configuration for the project
 * 
 * Returns:
 * 		If the compilation was successful
 */
bool compileUnit(string file, string[] files, LiveReloadConfig config, string codeUnitName) {
	synchronized
		isCompiling_ = true;
	
	string cmd = dmdCompileCommand(file, files, config, codeUnitName);
	auto ret = execute(cmd.split(" "));
	
	synchronized
		isCompiling_ = false;
	
	return ret.status != 0;
}

string dmdCompileCommand(string file, string[] files, LiveReloadConfig config, string codeUnitName) {
	string cmd;
	
	cmd ~= compilerPath;
	cmd ~= " -of" ~ buildPath(pathToFiles, config.outputDir, file);
	
	cmd ~= " -m";
	version(x86_64)
		cmd ~= "64";
	else
		cmd ~= "32";
	
	bool[string] usingVersions;
F1: foreach(path, versions; config.versionDirs) {
		auto reg = regex(path);
		
		foreach(file2; files) {
			foreach(match; matchAll(file2, reg)) {
				foreach(ver; versions) {
					usingVersions[ver] = true;
				}
				continue F1;
			}
		}
	}
	foreach(ver; usingVersions.keys) {
		cmd ~= " -version=" ~ ver;
	}
	
	cmd ~= " -I" ~ buildPath(pathToFiles, "deps", "imports", codeUnitName);
	
	bool[string] codeDependencies;
F2: foreach(r, values; config.dirDependencies) {
		auto reg = regex(r);
		
		foreach(file2; files) {
			foreach(match; matchAll(file2, reg)) {
				foreach(value; values) {
					codeDependencies[value] = true;
				}
				continue F2;
			}
		}
	}
	foreach(name; codeDependencies.keys) {
		foreach(d; dirEntries(pathToFiles, name, SpanMode.depth)) {
			cmd ~= " -I" ~ d.name ~ " -J" ~ d.name;
		}
	}
	
	cmd ~= " " ~ buildPath(pathToFiles, config.dependencyDir, "bin",  codeUnitName ~ ".lib");
	
	foreach(file2; files) {
		cmd ~= " " ~ buildPath(pathToFiles, file2);
	}
	
	if (dirSeparator == "/")
		cmd = cmd.replace("\\", "/");
	else if (dirSeparator == "\\")
		cmd = cmd.replace("/", "\\");
	
	return cmd;
}

unittest {
	compilerService("testdir", "dmd");
	string cmd = dmdCompileCommand("test.exe", ["dir/file.d"], LiveReloadConfig("bin"), "my_code_unit");
	
	version(Windows) {
		version(x86_64) {
			assert(cmd == "dmd -oftestdir\\bin\\test.exe -m64 -Itestdir\\deps\\imports\\my_code_unit testdir\\bin\\my_code_unit.lib testdir\\dir\\file.d");
		} else {
			assert(cmd == "dmd -oftestdir\\bin\\test.exe -m32 -Itestdir\\deps\\imports\\my_code_unit testdir\\bin\\my_code_unit.lib testdir\\dir\\file.d");
		}
	} else version(Posix) {
		version(x86_64) {
			assert(cmd == "dmd -oftestdir/bin/test.exe -m64 -Itestdir/deps/imports/my_code_unit testdir/bin/my_code_unit.lib testdir/dir/file.d");
		} else {
			assert(cmd == "dmd -oftestdir/bin/test.exe -m32 -Itestdir/deps/imports/my_code_unit testdir/bin/my_code_unit.lib testdir/dir/file.d");
		}
	}
}