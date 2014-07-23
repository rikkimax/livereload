module livereload.services.compiler;
import livereload.config.defs;
import livereload.app;
import std.path : buildPath, dirSeparator;
import std.file : exists, isDir, mkdirRecurse, remove;

public import livereload.services.compiler_dmd : compileUnit;
public import livereload.services.compiler_dub : redubify;

shared {
	bool isCompiling_;
	string compilerPath;
	string binDir;
}

bool isCompiling() {
	synchronized {
		return isCompiling_;
	}
}

void compilerService(string compiler) {
	compilerPath = compiler;

	binDir = buildPath(pathToFiles, "bin");
	confirmBinDirExists(binDir);
}

private {
	void confirmBinDirExists(string dir) {
		if (exists(dir) && isDir(dir)){}
		else if (exists(dir)) {
			remove(dir);
			mkdirRecurse(dir);
		} else
			mkdirRecurse(dir);
	}
}