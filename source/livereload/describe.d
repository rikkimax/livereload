/*
 * Module to be refactored later
 *
 * Reads output from `dub describe` and returns organized list of package data
*/
module livereload.describe;
import std.process, std.stdio;
import vibe.data.json;
struct Dependency {
	string[] copyFiles, libs, importPaths, files, versions;
}
Dependency[] getDependencyData(string dubDescription) {
	Dependency[] dependencies;
	Json json = parseJsonString(dubDescription);

	json = json["packages"];

	foreach (size_t index, Json value; json) {
		Dependency d;
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
	Dependency[] dependencies = getDependencyData(
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
	Dependency test = Dependency(["file", "anotherFile"], ["example", "real"], [], ["source/example/example.d"], ["example"]);
	assert(dependencies[0].copyFiles == test.copyFiles);
	assert(dependencies[0].libs == test.libs);
	assert(dependencies[0].importPaths == test.importPaths);
	assert(dependencies[0].files == test.files);
	assert(dependencies[0].versions == test.versions);
	// non source library
	Dependency[] nonSourceDependencies = getDependencyData(
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
	Dependency nonSourceTest = Dependency(["file", "anotherFile"], ["example", "real"], ["source/"], [], ["example"]);
	assert(nonSourceDependencies[0].copyFiles == nonSourceTest.copyFiles);
	assert(nonSourceDependencies[0].libs == nonSourceTest.libs);
	assert(nonSourceDependencies[0].importPaths == nonSourceTest.importPaths);
	assert(nonSourceDependencies[0].files == nonSourceTest.files);
	assert(nonSourceDependencies[0].versions == nonSourceTest.versions);
}
string[] getArrayContents(Json json, string value) {
	string[] contents;
	foreach (size_t i, Json v; json[value]) {
		contents ~= v.get!string;
	}
	return contents;
}