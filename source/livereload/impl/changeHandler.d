module livereload.impl.changeHandler;
import livereload.defs;

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
                        if (Path(relPath).startsWith(Path(unit)) || globMatch(relPath, unit)) {
                            codeUnitFilesThatChanged[globCodeUnitName(unit)] = (bool[string]).init;
                        }
                    } else if (globMatch(relPath, unit)) {
                        codeUnitFilesThatChanged[globCodeUnitName(unit)][relPath] = true;
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