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
	assert(dependencies == [Dependency(["file", "anotherFile"], ["example", "real"], [], ["source/example/example.d"], ["example"])]);
}
string[] getArrayContents(Json json, string value) {
	string[] contents;
	foreach (size_t i, Json v; json[value]) {
		contents ~= v.get!string;
	}
	return contents;
}