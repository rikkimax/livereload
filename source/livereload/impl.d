module livereload.impl;
import livereload.defs;
import vibe.inet.path;
import vibe.core.file;

mixin template CodeUnits() {
	@property {
		string[] codeUnitNames() {
			string[] ret;
			string depPath = buildPath(pathOfFiles, "package.json");

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

	string globCodeUnitName(string glob) {
		foreach(cu; config.codeUnits) {
			if (cu == glob) {
				Path cuPath = Path(cu);
				if (cuPath.length > 0)
					return cuPath.nodes[0].toString();
			}
		}
		return null;
	}

	string[] dependedUponDirectories(string file) {
		import std.path : globMatch;
		
		bool[string] ret; // DependedOnFile[][DependentDirectory]
	F1: foreach(dept1d, dept1dv; config.dirDependencies) {
			foreach(dept2d; dept1dv) {
				if (globMatch(file, dept2d)) {
					ret[dept1d] = true;
					continue F1;
				}
			}
		}
		
		return ret.keys;
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

	void rerunDubDependencies() {
		synchronized
			isCompiling_ = true;

        // TODO: get dub setup and configured for each package

		synchronized
			isCompiling_ = false;
	}
}

mixin template NodeRunner() {
	package shared {
		import std.process;
		Pid[string] pidFiles;
	}

	void executeCodeUnit(string name, string file) {
		import std.concurrency : spawn;
		spawn(&executeCodeUnit_, cast(shared)this, name, file);
	}

	void stopCodeUnit(string name, string file) {
		string useName = name ~ file;
		if (useName in pidFiles) {
			kill(cast()pidFiles[useName]);
			// the task that handles the PID will remove it
		}
	}
}

package {
	void executeCodeUnit_(shared(LiveReload) this_, string name_, string file_) {
		import std.process;
		import std.string : indexOf;
		import ofile = std.file;

		with(cast()this_) {
			alias name = name_; // Error: with symbol vibe.data.serialization.name is shadowing local symbol livereload.impl.executeCodeUnit_.name
			alias file = file_;

			string useName = name ~ (file is null ? "" : "");
			string file2 = lastNameOfPath(name, file);
			
			if (file2 in pidFiles)
				stopCodeUnit(name, file);
			
			try {
				auto pipes = pipeProcess(file2);
				synchronized
					pidFiles[useName] = cast(shared)pipes.pid;
				
				string logFile = buildPath(pathOfFiles, config.outputDir, "logs", "output", name ~ ".log");
				ofile.mkdirRecurse(buildPath(pathOfFiles, config.outputDir, "logs", "output"));
				if(!ofile.exists(logFile))
					ofile.write(logFile, "");

				// Ehhh something isn't right. pipeProcess pipes are blocking the entire program
				foreach(line; pipes.stdout.byLine) {
					if (line != "") {
						ofile.append(logFile, file2 ~ ":\t" ~ line); // \r\n ext. added by process
						if (line.length > 5) {
							if (line[0 .. 2] == "#{" && line[$-2 .. $] == "}#") {
								if (line.indexOf(",") > 2) {
									(cast()this_).gotAnOutputLine(name, file, line.idup);
								}
							}
						}
					}
				}
				wait(pipes.pid);
			} catch(Exception e) {
				// don't worry about it.
				logInfo("File %s failed to run, or died during execution", file);
			}
			
			synchronized
				pidFiles.remove(useName);
		}
	}
}

mixin template MonitorService() {
	void start_monitoring() {
		import livereload.util : watchDirectory2;
		import std.path : dirName, baseName;
		import ifile = std.file;

		string configDirName = dirName(configFilePath);
		string configFileName = baseName(configFilePath);
		
		if (configDirName == pathOfFiles) {
			// optimize for single directory that contains both configuration file and the general files
			
			tasksToKill ~= cast(shared)runTask({
				// TODO: implement a DirectoryWatcher instead of using watchDirectory temporarily.
				DirectoryWatcher watcher = watchDirectory2(pathOfFiles);
				
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
								}
							} else {
								changes2 ~= change;
							}
						}
						
						while(isCompiling())
							sleep(500.msecs);
						synchronized
							changesOccured(changes2);
					}
					
					sleep(500.msecs);
				}
			});
		} else {
			// optimize for seperate directories for the configuration file and the general files
			
			tasksToKill ~= cast(shared)runTask({
				DirectoryWatcher watcher = watchDirectory2(pathOfFiles);
				DirectoryWatcher watcher2 = watchDirectory2(configDirName, false);
				
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
					
					sleep(500.msecs);
				}
			});
		}
	}
}

mixin template ChangeHandling() {
	private shared {
		string[][string][string] onFileDependencies; 
	}

	void changesOccured(DirectoryChange[] changes) {
		import std.file : dirEntries, SpanMode;
		import std.path : globMatch;

		bool[string][string] codeUnitFilesThatChanged; // -[file][code unit]
		bool dubDirChanged;

		foreach(change; changes) {
			if (change.type == DirectoryChangeType.added || change.type == DirectoryChangeType.modified) {
				if (change.path.startsWith(Path(buildPath(pathOfFiles, config.outputDir))))
					continue;
				if (change.path == (Path(buildPath(pathOfFiles, "package.json")))) {
					dubDirChanged = true;
					continue;
				}

				string relPath = change.path.relativeTo(Path(pathOfFiles)).toNativeString();
				string[] dependentDirectories = dependedUponDirectories(change.path.toNativeString());

			F1: foreach(unit; config.codeUnits) {
					if (isCodeUnitADirectory(globCodeUnitName(unit))) {
						if (Path(relPath).startsWith(Path(unit))) {
							codeUnitFilesThatChanged[unit] = (bool[string]).init;
						}
					} else {
						foreach(depDir; dependentDirectories) {
							if (globMatch(relPath, depDir)) {
								if (depDir == unit) {
									// all code unit files need to be changed.
									foreach(cue; dirEntries(pathOfFiles, unit, SpanMode.depth)) {
										if (globMatch(Path(cue).relativeTo(Path(pathOfFiles)).toNativeString(), depDir)) {
											codeUnitFilesThatChanged[globCodeUnitName(unit)][cue] = true;
										}
									}
								} else {
									foreach(cue; dirEntries(pathOfFiles, unit, SpanMode.depth)) {
										if (globMatch(Path(cue).relativeTo(Path(pathOfFiles)).toNativeString(), depDir)) {
											codeUnitFilesThatChanged[globCodeUnitName(unit)][cue] = true;
										}
									}
								}
							}
						}

						if (globMatch(relPath, unit)) {
							codeUnitFilesThatChanged[globCodeUnitName(unit)][relPath] = true;
						}
					}
				}
			} else {
				stopCodeUnit(codeUnitNameForFile(change.path.toString()), change.path.toString());
			}
		}

		if (dubDirChanged) {
			rerunDubDependencies();

			// TODO: recompile every code unit available
			foreach(unit, files; codeUnitFilesThatChanged) {
				if (isCodeUnitADirectory(globCodeUnitName(unit))) {
					handleRecompilationRerun(unit, null);
				} else {
					foreach(file; files.keys) {
						handleRecompilationRerun(unit, file);
					}
				}
			}
		} else {
			foreach(unit, files; codeUnitFilesThatChanged) {
				if (isCodeUnitADirectory(globCodeUnitName(unit))) {
					handleRecompilationRerun(unit, null);
				} else {
					foreach(file; files.keys) {
						handleRecompilationRerun(unit, file);
					}
				}
			}
		}
	}

	void gotAnOutputLine(string name, string file, string line) {
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
		import ofile = std.file;
		import std.datetime : Clock;

		string bininfopath = (Path(pathOfFiles) ~ Path(config.outputDir) ~ Path("bininfo.d")).toNativeString();
		string binOutFile = "module livereload.bininfo;\r\n";

		string[] files;
		binOutFile ~= "enum string[] CODE_UNITS = [";
		if (isCodeUnitADirectory(name)) {
			file = codeUnitGlob(name);
			foreach(entry; dirEntries(buildPath(pathOfFiles, file), "*.d", SpanMode.depth)) {
				if (ofile.exists(entry.name) && ofile.isFile(entry.name)) {
					files ~= entry.name;

					string modul = getModuleFromFile(entry.name);
					if (modul !is null)
						binOutFile ~= "\"" ~ modul ~ "\",";
				}
			}
		} else {
			if (ofile.exists(file) && ofile.isFile(file))
				files ~= file;

			string modul = getModuleFromFile(file);
			if (modul !is null)
				binOutFile ~= "\"" ~ modul ~ "\"";
		}
		binOutFile ~= "];\r\n";

		// determine dependency files
		bool[string] tfiles;
	FN1: foreach(r, globs; config.dirDependencies) {
			auto reg = regex(r);
			foreach(match; matchAll(file, reg)) {
				foreach(glob; globs) {
					foreach(entry; dirEntries(pathOfFiles, glob, SpanMode.depth)) {
						if (ofile.exists(entry.name) && ofile.isFile(entry.name))
							tfiles[entry.name] = true;
					}
				}
				continue FN1;
			}
		}
		files ~= tfiles.keys;
		tfiles.clear();

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

		binOutFile ~= "enum string[] DFILES = [";
		foreach(filez; files) {
			string modul = getModuleFromFile(filez);
			if (modul !is null)
				binOutFile ~= "\"" ~ modul ~ "\",";
		}
		binOutFile ~= "];\r\n";
		ofile.write(bininfopath, binOutFile);
		files ~= bininfopath;

        /*auto depCU = dependencyForCodeUnit(name);
        files ~= depCU.files;
        //files ~= depCU.libs;
        //TODO: files ~= depCU.libs;

        string[] versionsA = depCU.versions;
        string[] dependencyDirsA = dependencyDirs.keys ~ depCU.importPaths;
        string[] strImportsA = strImports.keys /* ~ depCU.strImportPaths*//*;

        // TODO: depCU.copyFiles

		// TODO: assuming executable, perhaps shared libraries should be supported?
        return (cast()compileHandler_).compileExecutable(this, binFile, files, versionsA, dependencyDirsA, strImportsA, name);*/
        return false;
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
		string useName = name ~ (file is null ? "" : "");

		string ret = buildPath(pathOfFiles, config.outputDir, name ~ "_" ~ baseName(file) ~ "_" ~ to!string(Path(dirName(file)).length) ~ "_" ~ to!string(Clock.currTime().toUnixTime()));

		// TODO: are other extensions required?
		version(Windows) {
			ret ~= ".exe";
		}

		synchronized
			namesOfCodeUnitsBins[useName] = cast(shared)ret;
		return ret;
	}

	string lastNameOfPath(string name, string file) {
		string useName = name ~ (file is null ? "" : "");
		synchronized
			return cast()namesOfCodeUnitsBins[useName];
	}
}

string getModuleFromFile(string file) {
	import std.regex : ctRegex, matchAll;
	import std.file : exists, isFile;

	if (exists(file) && isFile(file)){}
	else
		return null;

	string text = readFileUTF8(Path(file));
	auto reg = ctRegex!`module (?P<name>[a-zA-Z_\.0-9]+);`;
	auto matches = matchAll(text, reg);
	foreach(match; matches) {
		return match["name"];
	}
	return null;
}