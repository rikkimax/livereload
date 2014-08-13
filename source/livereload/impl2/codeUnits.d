module livereload.impl2.codeUnits;
import livereload.defs;
//import vibe.inet.path;
//import vibe.core.file;

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