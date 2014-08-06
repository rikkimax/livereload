/*
 * Module to be refactored later
 *
 * Reads output from `dub describe` and returns organized list of package data
*/
module livereload.describe;
import std.process, std.stdio;
import vibe.data.json;

struct DubDescribe {
	string[] copyFiles, libs, importPaths, files, versions;
}

/**
 * Parses output from dub for dependency management
 * 
 * Params:
 *      dubDescription  =   The output from dub describe
 * 
 * Returns:
 *      A set of values representing the dependency
 * 
 * See_Also:
 *      DubDescribe
 */
DubDescribe[] getDependencyData(string dubDescription) {
    DubDescribe[] dependencies;
	Json json = parseJsonString(dubDescription);

	json = json["packages"];

	foreach (size_t index, Json value; json) {
        DubDescribe d;
		d.versions = getArrayContents(value, "versions");
		d.libs = getArrayContents(value, "libs");

		if (value["targetType"].get!string != "sourceLibrary") {
			d.importPaths = getArrayContents(value, "importPaths");
		} else {
			foreach (size_t i, Json v; value["files"]) {
				d.files ~= v["path"].get!string;
			}
		}

		d.copyFiles = getArrayContents(value, "copyFiles");
		dependencies ~= d;
	}

	return dependencies;
}

unittest {
	// example source library
    DubDescribe[] dependencies = getDependencyData(
		"{
			\"mainPackage\": \"example\",
			\"packages\": [
				{
					\"workingDirectory\": \"\",
					\"copyright\": \"\",
					\"versions\": [
						\"example\"
					],
					\"targetFileName\": \"\",
					\"dependencies\": [],
					\"version\": \"~master\",
					\"debugVersions\": [],
					\"postGenerateCommands\": [],
					\"libs\": [
						\"example\",
						\"real\"
					],
					\"targetName\": \"example\",
					\"lflags\": [],
					\"name\": \"example\",
					\"importPaths\": [
						\"source/\"
					],
					\"homepage\": \"https://example.com\",
					\"authors\": [
						\"\"
					],
					\"preGenerateCommands\": [],
					\"buildRequirements\": [],
					\"postBuildCommands\": [],
					\"targetType\": \"sourceLibrary\",
					\"mainSourceFile\": \"\",
					\"copyFiles\": [
						\"file\",
						\"anotherFile\"
					],
					\"preBuildCommands\": [],
					\"targetPath\": \"\",
					\"dflags\": [],
					\"license\": \"public domain\",
					\"path\": \"/home/example/projects/example\",
					\"description\": \"A fantastic example program\",
					\"options\": [],
					\"stringImportPaths\": [],
					\"files\": [
						{
							\"path\": \"source/example/example.d\",
							\"type\": \"source\"
						}
					]
				}
			],
			\"configuration\": \"library\",
			\"compiler\": \"dmd\",
			\"architecture\": [
				\"x86_64\"
			],
			\"platform\": [
				\"linux\",
				\"posix\"
			]
		}
	");

	// Expected output to test: Dependency(["file", "anotherFile"], ["example", "real"], [], ["source/example/example.d"], ["example"]);
	assert(dependencies[0].copyFiles.length == 2);
	assert(dependencies[0].copyFiles[0] == "file");
	assert(dependencies[0].copyFiles[1] == "anotherFile");

	assert(dependencies[0].libs.length == 2);
	assert(dependencies[0].libs[0] == "example");
	assert(dependencies[0].libs[1] == "real");

	assert(dependencies[0].importPaths.length == 0);

	assert(dependencies[0].files.length == 1);
	assert(dependencies[0].files[0] == "source/example/example.d");

	assert(dependencies[0].versions.length == 1);
	assert(dependencies[0].versions[0] == "example");
}

unittest {
	// non source library
    DubDescribe[] nonSourceDependencies = getDependencyData(
		"{
			\"mainPackage\": \"example\",
			\"packages\": [
				{
					\"workingDirectory\": \"\",
					\"copyright\": \"\",
					\"versions\": [
						\"example\"
					],
					\"targetFileName\": \"\",
					\"dependencies\": [],
					\"version\": \"~master\",
					\"debugVersions\": [],
					\"postGenerateCommands\": [],
					\"libs\": [
						\"example\",
						\"real\"
					],
					\"targetName\": \"example\",
					\"lflags\": [],
					\"name\": \"example\",
					\"importPaths\": [
						\"source/\"
					],
					\"homepage\": \"https://example.com\",
					\"authors\": [
						\"\"
					],
					\"preGenerateCommands\": [],
					\"buildRequirements\": [],
					\"postBuildCommands\": [],
					\"targetType\": \"library\",
					\"mainSourceFile\": \"\",
					\"copyFiles\": [
						\"file\",
						\"anotherFile\"
					],
					\"preBuildCommands\": [],
					\"targetPath\": \"\",
					\"dflags\": [],
					\"license\": \"public domain\",
					\"path\": \"/home/example/projects/example\",
					\"description\": \"A fantastic example program\",
					\"options\": [],
					\"stringImportPaths\": [],
					\"files\": [
						{
							\"path\": \"source/example/example.d\",
							\"type\": \"source\"
						}
					]
				}
			],
			\"configuration\": \"library\",
			\"compiler\": \"dmd\",
			\"architecture\": [
				\"x86_64\"
			],
			\"platform\": [
				\"linux\",
				\"posix\"
			]
		}
	");

	// Expected output to be: Dependency(["file", "anotherFile"], ["example", "real"], ["source/"], [], ["example"]);
	assert(nonSourceDependencies[0].copyFiles.length == 2);
	assert(nonSourceDependencies[0].copyFiles[0] == "file");
	assert(nonSourceDependencies[0].copyFiles[1] == "anotherFile");

	assert(nonSourceDependencies[0].libs.length == 2);
	assert(nonSourceDependencies[0].libs[0] == "example");
	assert(nonSourceDependencies[0].libs[1] == "real");
	assert(nonSourceDependencies[0].importPaths.length == 1);

	assert(nonSourceDependencies[0].importPaths[0] == "source/");

	assert(nonSourceDependencies[0].files.length == 0);
	
	assert(nonSourceDependencies[0].versions.length == 1);
	assert(nonSourceDependencies[0].versions[0] == "example");
}

/**
 * Gets an array of values from a Json value
 * 
 * Params:
 *      json    =   The json set to get from
 *      value   =   The name of the array of values
 * 
 * Returns:
 *      A string array based upon the name within the json set.
 * 
 * See_Also:
 *      Json
 */
string[] getArrayContents(Json json, string value) {
	string[] contents;

    if (json.length > 0 && json.type == Json.Type.object) {
    	foreach (size_t i, Json v; json[value]) {
		    contents ~= v.get!string;
	    }
    }

	return contents;
}