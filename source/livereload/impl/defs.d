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