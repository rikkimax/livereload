module livereload.impl;
import livereload.defs;
import vibe.inet.path;
import vibe.core.file;

mixin template CodeUnits() {
	@property {
		string[] codeUnitNames() {
			string[] ret;
			string depPath = buildPath(pathOfFiles, config.dependencyDir, "package.json");

			if (exists(depPath) && isFile(depPath)) {
				Json json = parseJsonString(readText(depPath));
				foreach(subPackage; json["subPackages"]) {
					ret ~= subPackage["name"].get!string;
				}
			}

			return ret;
		}
	}

	string codeUnitNameForFile(string file) {
		foreach(value; [Path(file).relativeTo(Path(pathOfFiles))[0].toString(), "base"]) {
			if (canFind(codeUnitNames(), value))
				return value;
		}
		return null;
	}

	string[] codeUnitsForName(string name) {
		import livereload.util : replace;
		import std.path : globMatch;
		import std.file : dirEntries, SpanMode;
		import std.string : indexOf;

		string glob = codeUnitGlob(name);
		if (glob !is null) {
			if (!isCodeUnitADirectory(glob)) {
				version(Windows) {
					glob = glob.replace("/", "\\");
				} else version(Posix) {
					glob = glob.replace("\\", "/");
				}

				string[] ret;
				foreach(entry; dirEntries(pathOfFiles, SpanMode.depth)) {
					if (globMatch(entry.name, buildPath(pathOfFiles, glob))) {
						ret ~= entry.name;
					}
				}

				return ret;
			}
		}

		return null;
	}

	bool isCodeUnitADirectory(string name) {
		string glob = codeUnitGlob(name);
		if (glob !is null)
			return glob.indexOf("*") < 0;

		return false;
	}

	string codeUnitGlob(string name) {
		foreach(cu; config.codeUnits) {
			if (cu.length >= name.length) {
				if (cu[0 .. name.length] == name) {
					return cu;
				}
			}
		}
		return null;
	}
}

mixin template ToolChain() {
	bool checkToolchain() {
		import std.process : execute, thisProcessID;
		import std.file : tempDir, mkdirRecurse, rmdirRecurse;
		import std.conv : to;

		string testTmp = buildPath(tempDir(), to!string(thisProcessID));
		if (!exists(testTmp))
			mkdirRecurse(testTmp);
		scope(exit) rmdirRecurse(testTmp);

		execute(["dub", "init", testTmp]);
		if (compilerPath is null)
			return execute(["dub", "run"]).status != 0;
		else
			return execute(["dub", "run", "--compiler=" ~ compilerPath]).status != 0;
	}
}

mixin template NodeRunner() {
	private shared {
		import std.process;
		Pid[string] pidFiles;
	}

	void executeCodeUnit(string name, string file) {
		import std.string : indexOf;

		string useName = name ~ file;
		string file2 = lastNameOfPath(name, file);

		synchronized
			if (file2 in pidFiles)
				stopCodeUnit(name, file);

		auto pipe = pipe();
		auto pid = spawnProcess(file2, std.stdio.stdin, pipe.writeEnd);
		synchronized
			pidFiles[useName] = cast(shared)pid;
			
		tasksToKill ~= runTask({
			auto reader = pipe.readEnd;

			while(useName in pidFiles && reader.isOpen) {
				string line = reader.readln();
				if (line.length > 5) {
					if (line[0 .. 2] == "#{" && line[$-2 .. $] == "}#") {
						if (line.indexOf(",") > 2) {
							gotAnOutputLine(name, file, line);
						}
					}
				}
			}
		
			synchronized
				pidFiles.remove(useName);
		});
	}

	void stopCodeUnit(string name, string file) {
		string useName = name ~ file;
		if (useName in pidFiles) {
			kill(cast()pidFiles[useName]);
			// the task that handles the PID will remove it
		}
	}
}

mixin template MonitorService() {
	void start_monitoring() {
		import std.path : dirName, baseName;
		import ifile = std.file;

		string configDirName = dirName(configFilePath);
		string configFileName = baseName(configFilePath);
		
		if (configDirName == pathOfFiles) {
			// optimize for single directory that contains both configuration file and the general files
			
			tasksToKill ~= cast(shared)runTask({
				version(none) {
					// TODO: implement a DirectoryWatcher instead of using watchDirectory temporarily.
					DirectoryWatcher watcher = watchDirectory(pathOfFiles);
					
					while(true) {
						DirectoryChange[] changes;
						DirectoryChange[] changes2;
						
						if (watcher.readChanges(changes)) {
							foreach(change; changes) {
								if (change.path.head == configFileName) {
									if (change.type == DirectoryChangeType.added || change.type == DirectoryChangeType.modified) {
										// reload config
										synchronized
											config_ = cast(shared)loadConfig(cast(string)ifile.read(configFilePath));
									} else {
										changes2 ~= change;
									}
								}
							}
							
							while(isCompiling())
								sleep(500.msecs);
							synchronized
								changesOccured(changes2);
						}
						
						sleep(1.seconds);
					}
				}
			});
		} else {
			// optimize for seperate directories for the configuration file and the general files
			
			tasksToKill ~= cast(shared)runTask({
				DirectoryWatcher watcher = watchDirectory(pathOfFiles);
				DirectoryWatcher watcher2 = watchDirectory(configDirName, false);
				
				while(true) {
					DirectoryChange[] changes;
					
					// pathToFiles
					if (watcher.readChanges(changes)) {
						while(isCompiling())
							sleep(500.msecs);
						synchronized
							changesOccured(changes);
					}
					
					// configFile
					if (watcher2.readChanges(changes)) {
						foreach(change; changes) {
							if (change.path.head == configFileName) {
								
								if (change.type == DirectoryChangeType.added || change.type == DirectoryChangeType.modified) {
									// reload config
									synchronized
										config_ = cast(shared)loadConfig(cast(string)ifile.read(configFilePath));
								}
								
								break;
							}
						}
					}
					
					sleep(1.seconds);
				}
			});
		}
	}
}

// TODO:
mixin template ChangeHandling() {
	private shared {
		string[][string][string] onFileDependencies; 
	}

	void changesOccured(DirectoryChange[] changes) {
		import std.file : dirEntries, SpanMode;
		import std.path : globMatch;

		foreach(change; changes) {
			if (change.type == DirectoryChangeType.added || change.type == DirectoryChangeType.modified) {
				bool[string] unitsToChange;

				foreach(dept1d, dept1dv; config.dirDependencies) {
					foreach(dept2d; dept1dv) {
						foreach(dept2; dirEntries(pathOfFiles, dept2d, SpanMode.depth)) {
							if (Path(dept2) == change.path) {
								unitsToChange[dept1d] = true;
							}
						}
					}
				}

				foreach(unit; config.codeUnits) {
					foreach(cue; dirEntries(pathOfFiles, unit, SpanMode.depth)) {
						foreach(utc; unitsToChange.keys) {
							if (globMatch(cue, utc)) {
								string name = codeUnitNameForFile(cue);
								onFileDependencies[name][cue] = [];
								handleRecompilationRerun(name, cue);
							}
						}
					}
				}

				foreach(name, files; onFileDependencies) {
					foreach(file, deps; files) {
						bool isHandled = false;
						foreach(unit; unitsToChange.keys) {
							if (Path(file) == Path(unit)) {
								isHandled = true;
								break;
							}
						}

						if (!isHandled) {
							foreach(dep; deps) {
								onFileDependencies[name][file] = [];
								handleRecompilationRerun(name, file);
							}
						}
					}
				}
			} else {
				stopCodeUnit(codeUnitNameForFile(change.path.toString()), change.path.toString());
			}
		}
	}

	void gotAnOutputLine(string name, string file, string line) {
		//TODO: injects dependencies for this code unit main source file
		import std.string : toLower, strip;

		if (line.length > "#{dependency, ".length) {
			if (line[2 .."dependency,".length].toLower == "dependency,") {
				string temp = line["#{dependency,".length .. $-2].strip();
				onFileDependencies[name][file] ~= temp;
			}
		}
	}
}

mixin template Compilation() {
	bool compileCodeUnit(string name, string file) {
		import std.regex : regex, matchAll;
		import std.path : dirName;
		import std.string : indexOf;
		import std.file : dirEntries, SpanMode;

		// determine dependency files
		string[] files;
		bool[string] tfiles;
	FN1: foreach(r, globs; config.dirDependencies) {
			auto reg = regex(r);
			foreach(match; matchAll(file, reg)) {
				foreach(glob; globs) {
					foreach(entry; dirEntries(pathOfFiles, glob, SpanMode.depth)) {
						tfiles[entry.name] = true;
					}
				}
				continue FN1;
			}
		}
		files = tfiles.keys;
		files ~= file;
		tfiles.clear();

		// determines' versions
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

		// Dependency dirs to -I
		bool[string] dependencyDirs;
		// String import directories to -J
		bool[string] strImports;

		bool[string] codeDependencies; // dir_dependencies tier 2 glob values on each file, if the tier 1 value is a string import
	F2: foreach(r, values; config.dirDependencies) {
			auto reg = regex(r);

			foreach(file2; files) {
				foreach(match; matchAll(file2, reg)) {
					foreach(value; values) {
						codeDependencies[value] = (r.length > 3 && r[$-3 .. $] == "\\.d") || (r.length > 4 && r[$-4 .. $] == "\\.di");
					}
					continue F2;
				}
			}
		}
		foreach(glob, isCode; codeDependencies) {
			if (isCode) {
				foreach(entry; dirEntries(pathOfFiles, glob, SpanMode.depth)) {
					dependencyDirs[dirName(entry.name)] = true;
				}
			} else if (glob.indexOf("*") > 0) {
				foreach(entry; dirEntries(pathOfFiles, glob, SpanMode.depth)) {
					strImports[dirName(entry.name)] = true;
				}
			} else
				strImports[glob] = true;
		}


		isCompiling_ = true;
		scope(exit) isCompiling_ = false;

		string binFile = codeUnitBinaryPath(name, file);
		// TODO: assuming executable, perhaps shared libraries should be supported?
		return (cast()compileHandler_).compileExecutable(this, binFile, files, usingVersions.keys, dependencyDirs.keys, strImports.keys, name);
	}

	void handleRecompilationRerun(string name, string file) {
		stopCodeUnit(name, file);
		if (compileCodeUnit(name, file)) {
			// TODO: log this?
			executeCodeUnit(name, file);
		}
	}

	private shared {
		string[string] namesOfCodeUnitsBins;
	}

	string codeUnitBinaryPath(string name, string file) {
		import std.path : dirName, baseName;
		import std.datetime : Clock;
		string useName = name ~ file;

		string ret = buildPath(pathOfFiles, config.outputDir, baseName(file) ~ "_" ~ to!string(Path(dirName(file)).length) ~ "_" ~ to!string(Clock.currTime().toUnixTime()));

		// TODO: are other extensions required?
		version(Windows) {
			ret ~= ".exe";
		}

		synchronized
			namesOfCodeUnitsBins[useName] = cast(shared)ret;
		return ret;
	}

	string lastNameOfPath(string name, string file) {
		string useName = name ~ file;
		synchronized
			return cast()namesOfCodeUnitsBins[useName];
	}
}