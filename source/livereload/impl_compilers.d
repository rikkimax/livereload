module livereload.impl_compilers;
import livereload.defs;
import livereload.config.defs;
import std.path : buildPath;
import ofile = std.file;

class DmdHandler : ICompilationHandler {
	bool compileExecutable(ILiveReload reload, string binFile, string[] files, string[] versions, string[] dependencyDirs, string[] strImports, string codeUnitName) {
		import livereload.util : split;
		import std.process;

		string logDir = buildPath(reload.pathOfFiles, reload.config.outputDir, "logs");
		if (!ofile.exists(logDir))
			ofile.mkdirRecurse(logDir);
		string logFile = buildPath(logDir, "compilation.log");
		if(!ofile.exists(logFile))
			ofile.write(logFile, "");

		string cmd = dmdCompileCommand(reload.pathOfFiles, reload.compilerPath, reload.config, binFile, files, versions, codeUnitName, dependencyDirs, strImports);
		ofile.append(logFile, "Running compiler command: " ~ cmd ~ "\r\n");

		auto ret = execute(cmd.split(" "));

		if (!ofile.exists(binFile) || ret.status != 0) {
			ofile.append(logFile, ret.output);
			return false;
		}

		return true;
	}

	bool canHandle(string compiler) {
		import std.string : indexOf;
		return compiler == "dmd" || compiler.indexOf("/dmd") >= 0 || compiler.indexOf("\\dmd") >= 0;
	}
}

shared static this() {
	registerCompilationHandler(new DmdHandler);
}

private {
	string dmdCompileCommand(string pathOfFiles, string compilerPath, LiveReloadConfig config, string binFile, string[] files, string[] versions, string unitName, string[] dependencyDirs, string[] strImports) {
		import livereload.util : replace;
		import std.file : exists;

		string cmd;
		
		cmd ~= compilerPath;
		cmd ~= " -of" ~ buildPath(pathOfFiles, config.outputDir, binFile);
		
		cmd ~= " -m";
		version(x86_64)
			cmd ~= "64";
		else
			cmd ~= "32";
		
		cmd ~= " -I" ~ buildPath(pathOfFiles, "deps", "imports", unitName);
		// TODO: will it always be a .lib?

		string libFile = buildPath(pathOfFiles, "deps", "bin", unitName ~ ".lib");
		if (exists(libFile))
			cmd ~= " " ~ libFile;

		foreach(dep; dependencyDirs) {
			cmd ~= " -I" ~ dep;
		}

		foreach(str; strImports) {
			cmd ~= " -J" ~ str;
		}

		foreach(version_; versions) {
			cmd ~= " -version=" ~ version_;
		}
		
		foreach(file; files) {
			version(Windows) {
				cmd ~= " " ~ buildPath(pathOfFiles, file.replace("/", "\\"));
			} else version(Posix) {
				cmd ~= " " ~ buildPath(pathOfFiles, file.replace("\\", "/"));
			} else {
				cmd ~= " " ~ buildPath(pathOfFiles, file);
			}
		}
		
		return cmd;
	}

	unittest {
		string cmd = dmdCompileCommand("testdir", "dmd", LiveReloadConfig("bin"), "test.exe", ["dir/file.d"], ["SomeVersion"], "my_code_unit", null, null);

		version(Windows) {
			version(x86_64) {
				assert(cmd == "dmd -oftestdir\\bin\\test.exe -m64 -Itestdir\\deps\\imports\\my_code_unit testdir\\bin\\my_code_unit.lib -version=SomeVersion testdir\\dir\\file.d");
			} else {
				assert(cmd == "dmd -oftestdir\\bin\\test.exe -m32 -Itestdir\\deps\\imports\\my_code_unit testdir\\bin\\my_code_unit.lib -version=SomeVersion testdir\\dir\\file.d");
			}
		} else version(Posix) {
			version(x86_64) {
				assert(cmd == "dmd -oftestdir/bin/test -m64 -Itestdir/deps/imports/my_code_unit testdir/bin/my_code_unit.lib -version=SomeVersion testdir/dir/file.d");
			} else {
				assert(cmd == "dmd -oftestdir/bin/test -m32 -Itestdir/deps/imports/my_code_unit testdir/bin/my_code_unit.lib -version=SomeVersion testdir/dir/file.d");
			}
		}
	}
}