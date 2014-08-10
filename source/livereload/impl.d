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
    private {
        import dub.package_;
        import dub.dub;
        import dub.compilers.compiler;
        import dub.generators.generator;

        PackageInfo[string] packageToCodeUnit;
        Package[string] ofPackageToCodeUnit;
        Dub[string] dubToCodeUnit;
        BuildPlatform buildPlatform;
        Compiler dubCompiler;
    }

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
        import dub.project;
        import dub.packagesupplier;

		synchronized
			isCompiling_ = true;

        foreach(str, dub; dubToCodeUnit) {
            dub.shutdown();
        }

        packageToCodeUnit = typeof(packageToCodeUnit).init;
        ofPackageToCodeUnit = typeof(ofPackageToCodeUnit).init;
        dubToCodeUnit = typeof(dubToCodeUnit).init;

        BuildSettings bs;
        string[] debugVersions;
        
        dubCompiler = getCompiler(compilerPath_);
        buildPlatform = dubCompiler.determinePlatform(bs, compilerPath_);
        bs.addDebugVersions(debugVersions);

        foreach(subpName; codeUnitNames) {
            Dub vdub = new Dub();
            vdub.loadPackageFromCwd();

            Package usePackage = vdub.packageManager.getFirstPackage(vdub.projectName ~ ":" ~ subpName);
            if (usePackage is null) {
                usePackage = vdub.packageManager.getFirstPackage(vdub.projectName ~ ":base");
                if (usePackage is null)
                    usePackage = vdub.packageManager.getFirstPackage(vdub.projectName);
            }

            if (usePackage !is null) {
                packageToCodeUnit[subpName] = PackageInfo();
                packageToCodeUnit[subpName].parseJson(usePackage.info.toJson(), vdub.projectName);
                ofPackageToCodeUnit[subpName] = usePackage;

                vdub.loadPackage(usePackage);
                dubToCodeUnit[subpName] = vdub;

                vdub.upgrade(UpgradeOptions.select);
                vdub.upgrade(UpgradeOptions.upgrade|UpgradeOptions.printUpgradesOnly|UpgradeOptions.useCachedResult);
                vdub.project.validate();
            }
        }

		synchronized
			isCompiling_ = false;
	}

    bool dubCompile(string cu, string ofile, string[] srcFiles, string[] strImports) {
        import std.string : join;
        import std.path : dirName, baseName;

        logInfo("Told to compile %s %s [%s] [%s]", cu, ofile, srcFiles.join(", "), strImports.join(", "));

        if (cu !in dubToCodeUnit)
            cu = "base";

        version(Windows) {
            if (ofile[$-4 .. $] == ".exe")
                ofile.length -= 4;
        }

        bool compiledSuccessfully;

        //

        ofPackageToCodeUnit[cu].info.buildSettings.sourceFiles[""] ~= srcFiles;
        ofPackageToCodeUnit[cu].info.buildSettings.stringImportPaths[""] ~= strImports;
        ofPackageToCodeUnit[cu].info.buildSettings.targetName = baseName(ofile);
        ofPackageToCodeUnit[cu].info.buildSettings.targetPath = dirName(buildPath(config_.outputDir, ofile));

        GeneratorSettings gensettings;
        gensettings.platform = buildPlatform;
        gensettings.config = dubToCodeUnit[cu].project.getDefaultConfiguration(buildPlatform);
        gensettings.compiler = dubCompiler;
        gensettings.buildType = "debug";
        gensettings.linkCallback = (int ret, string output) {
            if (ret == 0)
                compiledSuccessfully = true;
        };
        
        dubToCodeUnit[cu].generateProject("build", gensettings);

        // restore backups of values

        ofPackageToCodeUnit[cu].info.buildSettings.sourceFiles = packageToCodeUnit[cu].buildSettings.sourceFiles.dup;
        ofPackageToCodeUnit[cu].info.buildSettings.stringImportPaths = packageToCodeUnit[cu].buildSettings.stringImportPaths.dup;

        return compiledSuccessfully;
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
        import std.path : dirName;
		import ofile = std.file;

		with(cast()this_) {
			alias name = name_; // Error: with symbol vibe.data.serialization.name is shadowing local symbol livereload.impl.executeCodeUnit_.name
			alias file = file_;

			string useName = name ~ (file is null ? "" : "");
            string file2 = buildPath(config.outputDir, lastNameOfPath(name, file));
			
            logInfo("running file %s", file2);

			if (file2 in pidFiles)
				stopCodeUnit(name, file);
			
			try {
				auto pipes = pipeProcess(file2);
				synchronized
					pidFiles[useName] = cast(shared)pipes.pid;
				
				string logFile = buildPath(dirName(file2), "stdout.log");

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
                logInfo(e.toString());
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
        import livereload.util : replace;
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

				string relPath = change.path.relativeTo(Path(pathOfFiles)).toNativeString().replace("\\", "/");
                string[] dependentDirectories = dependedUponDirectories(relPath);

		         foreach(unit; config.codeUnits) {
					if (isCodeUnitADirectory(globCodeUnitName(unit))) {
						if (globMatch(relPath, unit)) {
							codeUnitFilesThatChanged[unit] = (bool[string]).init;
						}
					} else {
						foreach(depDir; dependentDirectories) {
                            if (depDir == unit) {
                                // good thats what I expect
                                foreach(cue; dirEntries(pathOfFiles, SpanMode.depth)) {
                                    string cueRel = Path(cue).relativeTo(Path(pathOfFiles)).toNativeString();
                                    if (globMatch(cueRel, depDir)) {
                                        codeUnitFilesThatChanged[globCodeUnitName(unit)][cueRel] = true;
                                    }
                                }
                            }
						}
					}
				}
			} else {
				stopCodeUnit(codeUnitNameForFile(change.path.toString()), change.path.toString());
			}
		}

		if (dubDirChanged) {
			rerunDubDependencies();

            foreach(unit; config.codeUnits) {
                if (isCodeUnitADirectory(globCodeUnitName(unit))) {
                    handleRecompilationRerun(unit, null);
                } else {
                    foreach(cue; dirEntries(pathOfFiles, SpanMode.depth)) {
                        string cueRel = Path(cue).relativeTo(Path(pathOfFiles)).toNativeString();
                        if (globMatch(cueRel, unit)) {
                            handleRecompilationRerun(globCodeUnitName(unit), cueRel);
                        }
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
    private shared {
        string[string] namesOfCodeUnitsBins;
    }

	bool compileCodeUnit(string name, string file) {
		import std.path : dirName, globMatch;
		import std.string : indexOf;
		import std.file : dirEntries, SpanMode;
		import ofile = std.file;
		import std.datetime : Clock;

        string[] files;
        string[] strImports;
        string[] binInfoCU;

        void discoverFiles() {
            if (isCodeUnitADirectory(name)) {
    			file = codeUnitGlob(name);
    			foreach(entry; dirEntries(buildPath(pathOfFiles, file), "*.{d,di}", SpanMode.depth)) {
    				if (ofile.exists(entry.name) && ofile.isFile(entry.name)) {
    					files ~= entry.name;
                        binInfoCU ~= entry.name;
    				}
    			}
    		} else {
    			if (ofile.exists(file) && ofile.isFile(file))
    				files ~= (Path(pathOfFiles) ~ Path(file)).toNativeString();
                binInfoCU ~= file;
    		}
        }

        void discoverDependencyFiles() {
            // determine dependency files
            bool[string] tfiles;

            foreach(file2; files) {
                file2 = Path(file2).relativeTo(Path(pathOfFiles)).toString();

                foreach(r, globs; config.dirDependencies) {
                    if (globMatch(file2, r)) {
                        foreach(glob; globs) {
                            foreach(entry; dirEntries(pathOfFiles, "*.{d,di}", SpanMode.depth)) {
                                if (globMatch(entry.name, buildPath(pathOfFiles, glob))) {
                                    tfiles[entry.name] = true;
                                }
                            }
                        }
                    }
                }
            }

            files ~= tfiles.keys;
            tfiles.clear();
        }

        void discoverStrImports() {
            // determine dependency string imports
            bool[string] tfiles;
            
            foreach(file2; files) {
                file2 = Path(file2).relativeTo(Path(pathOfFiles)).toString();

                foreach(r, globs; config.dirDependencies) {
                    if (globMatch(file2, r)) {
                        foreach(glob; globs) {
                            foreach(entry; dirEntries(pathOfFiles, SpanMode.depth)) {
                                if (!globMatch(entry.name, "*.{d,di}") && globMatch(entry.name, buildPath(pathOfFiles, glob))) {
                                    tfiles[dirName(entry.name)] = true;
                                }
                            }
                        }
                    }
                }
            }
            
            strImports ~= tfiles.keys;
            tfiles.clear();
        }

        void outputBinInfo() {
            string ofilePath = (Path(pathOfFiles) ~ Path(config.outputDir) ~ Path("bininfo.d")).toNativeString();
            string ret = "module livereload.bininfo;\r\n";

            ret ~= "enum string[] CODE_UNITS = [";
            foreach(cu; binInfoCU) {
                string modul = getModuleFromFile(cu);
                if (modul !is null)
                    ret ~= "\"" ~ modul ~ "\",";
            }
            ret ~= "];\r\n";

            ret ~= "enum string[] DFILES = [";
            foreach(filez; files) {
                string modul = getModuleFromFile(filez);
                if (modul !is null)
                    ret ~= "\"" ~ modul ~ "\",";
            }
            ret ~= "];\r\n";

            files ~= ofilePath;
            ofile.write(ofilePath, ret);
        }

        isCompiling_ = true;
        scope(exit) isCompiling_ = false;

        discoverFiles();
        discoverDependencyFiles();
        discoverStrImports();
        outputBinInfo();

        string binFile = codeUnitBinaryPath(name, file);
        return dubCompile(name, lastNameOfPath(name, file), files, strImports);
	}

	void handleRecompilationRerun(string name, string file) {
		stopCodeUnit(name, file);
		if (compileCodeUnit(name, file)) {
			// TODO: log this?
			executeCodeUnit(name, file);
		}
	}

	string codeUnitBinaryPath(string name, string file) {
		import std.path : dirName, baseName, buildPath;
		import std.datetime : Clock;
        import std.file : mkdirRecurse;
		string useName = name ~ (file is null ? "" : "");

		string ret = name ~ "_" ~ baseName(file) ~ "_" ~ to!string(Path(dirName(file)).length) ~ "_" ~ to!string(Clock.currTime().toUnixTime());
        mkdirRecurse(buildPath(config_.outputDir, ret));
        ret = buildPath(ret, "out");

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