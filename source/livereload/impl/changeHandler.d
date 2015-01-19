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
                if (change.path == (Path(buildPath(pathOfFiles, "dub.json")))) {
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