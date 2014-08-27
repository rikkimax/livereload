module livereload.impl.compilation;
import livereload.defs;
import vibe.inet.path;
import vibe.core.file;

mixin template Compilation() {
    import std.file : dirEntries, SpanMode;
    import std.traits : ReturnType;

    private shared {
        string[string] namesOfCodeUnitsBins;
    }

	bool compileCodeUnit(string name, string file) {
        import livereload.util;
        import std.path : dirName, globMatch;
		import std.string : indexOf;
		import ofile = std.file;
		import std.datetime : Clock;

        string[] files;
        string[] strImports;
        string[] binInfoCU;

        ReturnType!dirEntries entries;

        void discoverFiles() {
            if (isCodeUnitADirectory(name)) {
    			file = codeUnitGlob(name);

                entries = dirEntries(buildPath(pathOfFiles, file), SpanMode.depth); // cache result removes like 30ms from running time.

                foreach(entry; entries) {
                    if (isDExt(entry.name)) {
    					files ~= entry.name;
                        binInfoCU ~= entry.name;
    				}
    			}
    		} else {
                files ~= buildPath(pathOfFiles, file);
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
                            foreach(entry; entries) {
                                if (!isDExt(entry.name) && globMatch(entry.name, buildPath(pathOfFiles, glob))) {
                                    tfiles[dirName(entry.name)] = true;
                                }
                            }
                        }
                    }
                }
            }
            
            strImports ~= tfiles.keys;
        }

        void outputBinInfo() {
            string ofilePath = buildPath(pathOfFiles, config.outputDir, "bininfo.d");
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

        import std.datetime;
        import core.time;

        auto start = Clock.currTime;

		if (compileCodeUnit(name, file)) {
            logInfo("Compilation took %s", (Clock.currTime-start).toString());

			// TODO: log this?
			executeCodeUnit(name, file);
        } else {
            logInfo("Compilation took %s", (Clock.currTime-start).toString());
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