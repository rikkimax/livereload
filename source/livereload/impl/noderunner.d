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