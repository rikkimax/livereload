module livereload.impl.monitor;
import livereload.defs;
import vibe.inet.path;
import vibe.core.file;

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