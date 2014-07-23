﻿module livereload.defs;
import livereload.config.defs;

/**
 * Interfaces
 */

interface ILiveReload {
	/**
	 * Creates and runs threads
	 */
	void start();
	void start_monitoring();

	/**
	 * Destroys, stops threads and any running executables
	 */
	void stop();

	@property {
		string pathOfFiles();
		string compilerPath();
		string configFilePath();
		LiveReloadConfig config();
		
		/**
		 * Lists all code unit names
		 * 
		 * Returns:
		 * 		The names of all code units
		 */
		string[] codeUnitNames();

		bool isCompiling();
	}
	
	/**
	 * Gets the code units name based upon a path
	 * 
	 * Params:
	 * 		path	=	The path of the file/directory to check against
	 * 
	 * Returns:
	 * 		The name of the code unit
	 */
	string codeUnitNameForFile(string path);

	/**
	 * Gets all main files for a code unit
	 * 
	 * Params:
	 * 		name	=	Code unit name
	 * 
	 * Returns:
	 * 		An array of main executable files
	 */
	string[] codeUnitsForName(string name);
	
	bool checkToolchain();
	void executeCodeUnit(string name, string file);
	void stopCodeUnit(string name, string file);
	bool isCodeUnitADirectory(string name);
	string codeUnitGlob(string name);

	/**
	 * Compiles a code unit
	 * 
	 * See_Also:
	 * 		codeUnitsForName
	 * 
	 * Params:
	 * 		name	=	The name of the code unit
	 * 		file	=	The main executable file (from e.g. codeUnitsForName)
	 * 
	 * Returns:
	 * 		If the compilation is successful
	 */
	bool compileCodeUnit(string name, string file);

	/**
	 * Handles recompilationg and rerun of a code unit main source file
	 * 
	 * See_Also:
	 * 		codeUnitsForName
	 * 
	 * Params:
	 * 		name	=	The name of the code unit
	 * 		file	=	The main executable file (from e.g. codeUnitsForName)
	 */
	void handleRecompilationRerun(string name, string file);

	/**
	 * What is the path and name of the executable to be created from this code unit?
	 */
	string codeUnitBinaryPath(string name, string file);
	string lastNameOfPath(string name, string file);
}

interface ICompilationHandler {
	bool compileExecutable(ILiveReload reload, string binFile, string[] files, string[] versions, string[] dependencyDirs, string[] strImports);
	bool canHandle(string compiler);
}

/**
 * InternalAPI
 */

private shared {
	ICompilationHandler[] compilationHelpers;
}

void registerCompilationHandler(ICompilationHandler handler) {
	compilationHelpers ~= cast(shared)handler;
}

/**
 * Base impl
 */

class LiveReload : ILiveReload {
	private shared {
		import livereload.impl;
		import vibe.d;
		import std.file : exists, isDir, isFile, readText;
		import std.path : buildPath;
		import std.algorithm : canFind;

		string pathOfFiles_;
		string compilerPath_;
		string configFilePath_;
		LiveReloadConfig config_;
		ICompilationHandler compileHandler_;

		Task[] tasksToKill;

		bool isCompiling_;
	}

	this(string path, string compilerPath=null, string configFilePath = null) {
		assert(exists(path) && isDir(path), "LiveReloading directory does not exist.");
	
		if (configFilePath is null)
			configFilePath = buildPath(path, "livereload.txt");

		pathOfFiles_ = cast(shared)path;
		compilerPath_ = cast(shared)compilerPath;
		configFilePath_ = cast(shared)configFilePath;
		config_ = cast(shared)loadConfig(path);

		foreach(handler; cast(ICompilationHandler[])compilationHelpers) {
			if (handler.canHandle(compilerPath)) {
				compileHandler_ = cast(shared)handler;
				break;
			}
		}

		start();
	}

	void start() {
		assert(checkToolchain(), "Toolchain is not ok, check your PATH variable");

		foreach(name; codeUnitNames) {
			foreach(file; codeUnitsForName(name)) {
				compileCodeUnit(name, file);
			}
		}
	}

	void stop() {
		foreach(task; cast(Task[])tasksToKill) {
			if (task.running)
				task.terminate();
		}
		tasksToKill.length = 0;
	}

	@property {
		string pathOfFiles() { synchronized return cast()pathOfFiles_; }
		string compilerPath() { synchronized return cast()compilerPath_; }
		string configFilePath() { synchronized return cast()configFilePath_; }
		LiveReloadConfig config() { synchronized return cast()config_; }
		bool isCompiling() { synchronized return cast()isCompiling_; }
	}

	mixin CodeUnits; // util for code units
	mixin ToolChain; // confirm we can compile
	mixin MonitorService; // tell us when changes occur in file system
	mixin ChangeHandling;
	mixin Compilation;
	mixin NodeRunner;
}