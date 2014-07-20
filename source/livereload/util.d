module livereload.util;
import std.string : indexOf, toLower;

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