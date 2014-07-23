module livereload.util;
import std.string : indexOf, toLower;
import vibe.core.file;

pure string[] split(string text, string delimater) {
	string[] ret;
	ptrdiff_t i;
	while((i = text.indexOf(delimater)) >= 0) {
		ret ~= text[0 .. i];
		text = text[i + delimater.length .. $];
	}
	if (text.length > 0) {
		ret ~= text;	
	}
	return ret;
}

unittest {
	string test = "abcd|efgh|ijkl";
	assert(test.split("|") == ["abcd", "efgh", "ijkl"]);
	string test2 = "abcd||efgh||ijkl";
	assert(test2.split("||") == ["abcd", "efgh", "ijkl"]);
}

pure string replace(string text, string oldText, string newText, bool caseSensitive = true, bool first = false) {
	string ret;
	string tempData;
	bool stop;
	foreach(char c; text) {
		if (tempData.length > oldText.length && !stop) {
			ret ~= tempData;
			tempData = "";
		}
		if (((oldText[0 .. tempData.length] != tempData && caseSensitive) || (oldText[0 .. tempData.length].toLower() != tempData.toLower() && !caseSensitive)) && !stop) {
			ret ~= tempData;
			tempData = "";
		}
		tempData ~= c;
		if (((tempData == oldText && caseSensitive) || (tempData.toLower() == oldText.toLower() && !caseSensitive)) && !stop) {
			ret ~= newText;
			tempData = "";
			stop = first;
		}
	}
	if (tempData != "") {
		ret ~= tempData;	
	}
	return ret;
}

DirectoryWatcher watchDirectory2(string path_, bool recursive=true) {
	import std.file;
	import std.datetime;
	import core.time : Duration, dur;

	class FakeDirectoryWatcher : DirectoryWatcher {
		private {
			SysTime[string] fileLastModified;
		}

		@property Path path() const {
			return Path(path_);
		}

		@property bool recursive() const {
			return recursive;
		}

		bool readChanges(ref DirectoryChange[] dst, Duration timeout = dur!"seconds"(-1)) {
			if (!(exists(path_) && isDir(path_)))
				return false;
				
			SysTime[string] fileLastModified2;

			foreach(entry; dirEntries(path_, SpanMode.depth)) {
				fileLastModified2[entry.name] = entry.timeLastModified;
			}

			foreach(k, v; fileLastModified) {
				if (k in fileLastModified2) {
					if (v != fileLastModified2[k])
						dst ~= DirectoryChange(DirectoryChangeType.modified, Path(k));
				} else {
					dst ~= DirectoryChange(DirectoryChangeType.removed, Path(k));
				}
			}

			foreach(k, v; fileLastModified2) {
				if (k !in fileLastModified) {
					dst ~= DirectoryChange(DirectoryChangeType.added, Path(k));
				}
			}

			fileLastModified = fileLastModified2;

			return true;
		}
	}

	return new FakeDirectoryWatcher;
}