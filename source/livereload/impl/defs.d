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
module livereload.impl.defs;
import livereload.defs;
import livereload.config.defs;

import livereload.impl.codeUnits;
import livereload.impl.toolchain;
import livereload.impl.monitor;
import livereload.impl.changeHandler;
import livereload.impl.compilation;
import livereload.impl.noderunner;

class LiveReload : ILiveReload {
    private shared {
        import vibe.d;
        import std.file : exists, isDir, isFile, readText;
        import std.path : buildPath;
        import std.algorithm : canFind;
        
        string pathOfFiles_;
        string compilerPath_;
        string configFilePath_;
        string archToCompile_;
        LiveReloadConfig config_;
        
        Task[] tasksToKill;
        
        bool isCompiling_;
    }
    
    this(string path, string compilerPath=null, string archToCompile=null, string configFilePath = null) {
        assert(exists(path) && isDir(path), "LiveReloading directory does not exist.");
        
        if (configFilePath is null)
            configFilePath = buildPath(path, "livereload.txt");
        
        pathOfFiles_ = cast(shared)path;
        compilerPath_ = cast(shared)compilerPath;
        configFilePath_ = cast(shared)configFilePath;
        config_ = cast(shared)loadConfig(readText(configFilePath));
        archToCompile_ = cast(shared)archToCompile;
        
        start();
    }
    
    void start() {
        assert(checkToolchain(), "Toolchain is not ok, check your PATH variable");
        
        rerunDubDependencies();
        start_monitoring();
    }
    
    void stop() {
        foreach(task; cast(Task[])tasksToKill) {
            if (task.running)
                task.terminate();
        }
        tasksToKill.length = 0;
    }
    
    @property {
        string pathOfFiles() { synchronized return cast()pathOfFiles_; }
        string compilerPath() { synchronized return cast()compilerPath_; }
        string configFilePath() { synchronized return cast()configFilePath_; }
        LiveReloadConfig config() { synchronized return cast()config_; }
        bool isCompiling() { return cast()isCompiling_; }
    }
    
    mixin CodeUnits; // util for code units
    mixin ToolChain; // confirm we can compile
    mixin MonitorService; // tell us when changes occur in file system
    mixin ChangeHandling; // transforms the changes that occured into code unit names and main files for compilation/running
    mixin Compilation; // compiles code
    mixin NodeRunner; // runs code unit files
}