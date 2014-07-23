module livereload.services.monitor;
import livereload.services.inventory : changesOccured;
import livereload.services.compiler : isCompiling;
import livereload.config.defs;
import vibe.d;
import std.path : dirName, baseName;
import ifile = std.file;

void monitorService(string pathToFiles, string configFile) {
	shared LiveReloadConfig config;
	string configDirName = dirName(configFile);
	string configFileName = baseName(configFile);

	if (configDirName == pathToFiles) {
		// optimize for single directory that contains both configuration file and the general files

		runTask({
			DirectoryWatcher watcher = watchDirectory(pathToFiles);
			
			while(true) {
				DirectoryChange[] changes;
				DirectoryChange[] changes2;
				
				if (watcher.readChanges(changes)) {
					foreach(change; changes) {
						if (change.path.head == configFileName) {
							if (change.type == DirectoryChangeType.added || change.type == DirectoryChangeType.modified) {
								// reload config
								synchronized
									config = cast(shared)loadConfig(cast(string)ifile.read(configFile));
							} else {
								changes2 ~= change;
							}
						}
					}
					
					while(isCompiling())
						sleep(500.msecs);
					synchronized
						changesOccured(changes2, cast()config);
				}
				
				sleep(1.seconds);
			}
		});
	} else {
		// optimize for seperate directories for the configuration file and the general files

		runTask({
			DirectoryWatcher watcher = watchDirectory(pathToFiles);
			DirectoryWatcher watcher2 = watchDirectory(configDirName, false);

			while(true) {
				DirectoryChange[] changes;

				// pathToFiles
				if (watcher.readChanges(changes)) {
					while(isCompiling())
						sleep(500.msecs);
					synchronized
						changesOccured(changes, cast()config);
				}

				// configFile
				if (watcher2.readChanges(changes)) {
					foreach(change; changes) {
						if (change.path.head == configFileName) {
							
							if (change.type == DirectoryChangeType.added || change.type == DirectoryChangeType.modified) {
								// reload config
								synchronized
									config = cast(shared)loadConfig(cast(string)ifile.read(configFile));
							}
							
							break;
						}
					}
				}
				
				sleep(1.seconds);
			}
		});
	}
}