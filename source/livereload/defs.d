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
module livereload.defs;
public import livereload.config.defs : LiveReloadConfig;

/**
 * Interfaces
 */

interface ILiveReload {
	/**
	 * Creates and runs threads
	 */
	void start();
	void start_monitoring();

	/**
	 * Destroys, stops threads and any running executables
	 */
	void stop();

	@property {
		string pathOfFiles();
		string compilerPath();
		string configFilePath();
		LiveReloadConfig config();
		
		/**
		 * Lists all code unit names
		 * 
		 * Returns:
		 * 		The names of all code units
		 */
		string[] codeUnitNames();

		bool isCompiling();
	}
	
	/**
	 * Gets the code units name based upon a path
	 * 
	 * Params:
	 * 		path	=	The path of the file/directory to check against
	 * 
	 * Returns:
	 * 		The name of the code unit
	 */
	string codeUnitNameForFile(string path);

	/**
	 * Gets all main files for a code unit
	 * 
	 * Params:
	 * 		name	=	Code unit name
	 * 
	 * Returns:
	 * 		An array of main executable files
	 */
	string[] codeUnitsForName(string name);

	/**
	 * What directories does this file, depend on it?
	 * 
	 * Param:
	 * 		file	=	The file to check against
	 * 
	 * Returns:
	 * 		A list of dependent directory globs
	 */
	string[] dependedUponDirectories(string file);

	bool checkToolchain();
	void rerunDubDependencies();
    bool dubCompile(string cu, string ofile, string[] srcFiles, string[] strImports);

	void executeCodeUnit(string name, string file);
	void stopCodeUnit(string name, string file);
	bool isCodeUnitADirectory(string name);
	string codeUnitGlob(string name);
	string globCodeUnitName(string glob);

	/**
	 * Compiles a code unit
	 * 
	 * See_Also:
	 * 		codeUnitsForName
	 * 
	 * Params:
	 * 		name	=	The name of the code unit
	 * 		file	=	The main executable file (from e.g. codeUnitsForName)
	 * 
	 * Returns:
	 * 		If the compilation is successful
	 */
	bool compileCodeUnit(string name, string file);

	/**
	 * Handles recompilationg and rerun of a code unit main source file
	 * 
	 * See_Also:
	 * 		codeUnitsForName
	 * 
	 * Params:
	 * 		name	=	The name of the code unit
	 * 		file	=	The main executable file (from e.g. codeUnitsForName)
	 */
	void handleRecompilationRerun(string name, string file);

	/**
	 * What is the path and name of the executable to be created from this code unit?
	 */
	string codeUnitBinaryPath(string name, string file);
	string lastNameOfPath(string name, string file);
}