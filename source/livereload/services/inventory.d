module livereload.services.inventory;
import livereload.config.defs;
import vibe.core.file;

/**
 * When a change has occured to the filesystem, decide what should be recompiled
 */
void changesOccured(DirectoryChange[] changes, LiveReloadConfig config) {
	// TODO:

	// foreach file
	//  is it under deps dir?
	//  if it is get all code units recompile them all.
	//  return;

	// foreach file
	//  if is code unit
	//   handleCodeUnitRecompile(name, config);

	//  else
	//   foreach outputDependencies
	//    is this file a member of this?
	//    if it is then next file

	//   which directories depend on it?
	//   string[] dirs = handleDirectoryDependency(name, config);
	//   foreach dir in dirs
	//    if is code unit
	//     handleCodeUnitRecompile(name, config);
	//    else
	//     foreach file in dir recursive
	//      if is code unit
	//       handleCodeUnitRecompile(name, config);
}

/**
 * The node runner, has received some output from the process
 * 
 * Params:
 * 		name	=	The name of the node (file path)
 * 		line	=	The line received of syntax #{NAME, VALUE}#
 */
void gotAnOutputLine(string name, string line) {
	// TODO:
}

private {
	/**
	 * Handles the nitty gritty for running, compiling and killing old nodes for a code unit
	 * 
	 * Params:
	 * 		name	=	The name of the file (includes path)
	 * 		config	=	The configuration that compilation is occuring on
	 */
	void handleCodeUnitRecompile(string name, LiveReloadConfig config) {
		// TODO:

		// if node already exists
		//  kill it

		// if name exists
		//  recompile
		//  run node
	}

	/**
	 * Very naive implementation that simply checks for every sub dir inside the dependency directories for a given file and returns the dirs that it has changed for
	 * 
	 * Params:
	 * 		name	=	The name of the file (includes path)
	 * 		config	=	The configuration that compilation is occuring on
	 * 
	 * Returns:
	 * 		The directories 
	 */
	string[] handleDirectoryDependency(string name, LiveReloadConfig config) {
		// TODO:

		// foreach dir dependencies
		//  foreach dirDep
		//   if name matches in dirDep
		//    ret ~= dir;

		assert(0);
	}

	/**
	 * 
	 */
	bool isCodeUnit(string name, LiveReloadConfig config) {
		// TODO:

		//   foreach code unit
		//    if the code unit has a * in it (its regex do that)
		//     create regex matcher
		//     matchAll name
		//     return does it have matches?
		//    other wise, start of file name == code unit name (then yes it is a code unit)
		//     return start of file name == code unit name

		assert(0);
	}
}