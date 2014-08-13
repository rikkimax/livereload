module livereload.impl.noderunner;
import livereload.defs;
import livereload.impl.defs;

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