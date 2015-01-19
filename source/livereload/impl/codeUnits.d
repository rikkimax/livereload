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
module livereload.impl.codeUnits;
import livereload.defs;

mixin template CodeUnits() {
    @property {
        string[] codeUnitNames() {
            string[] ret;
            string depPath = buildPath(pathOfFiles, "dub.json");
            
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