module livereload.noderunner;
import livereload.services.inventory : gotAnOutputLine;

private shared {
	import std.file;
	import std.process;
	Pid[string] pidFiles;
}

/**
 * Runs a node
 * 
 * When outputGather is true, it looks for #{NAME, VALUE}# syntax within the output, on its own line. This is sent to the inventory service.
 * 
 * Params:
 * 		name			=	The nodes file (includes path)
 * 		outputGather	=	This node needs the output to be parsed and sent to inventory service
 */
void runNode(string name, bool outputGather) {
	import vibe.d : runTask;
	import std.string : indexOf;

	auto pipe = pipe();
	auto pid = spawnProcess(name, std.stdio.stdin, pipe.writeEnd);
	if (outputGather) {
		synchronized
			pidFiles[name] = cast(shared)pid;

		runTask({
			auto reader = pipe.readEnd;

			while(name in pidFiles && reader.isOpen) {
				string line = reader.readln();
				if (line.length > 5) {
					if (line[0 .. 2] == "#{" && line[$-2 .. $] == "}#") {
						if (line.indexOf(",") > 2) {
							gotAnOutputLine(name, line);
						}
					}
				}
			}

			pidFiles.remove(name);
		});
	}
}

/**
 * Kills off an external node aka a process given its file path
 * 
 * Params:
 * 		name	=	The name of the node (file path)
 */
void killNode(string name) {
	if (name in pidFiles) {
		kill(cast()pidFiles[name]);
	}
}