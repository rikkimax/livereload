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
module livereload.impl.toolchain;
import livereload.defs;

mixin template ToolChain() {
    private {
        import dub.package_;
        import dub.dub;
        import dub.compilers.compiler;
        import dub.generators.generator;

        Package[string] ofPackageToCodeUnit;
        Dub[string] dubToCodeUnit;
        BuildPlatform buildPlatform;
        Compiler dubCompiler;
        string buildConfig;
    }
    
    bool checkToolchain() {
        import std.process : execute, thisProcessID;
        import std.file : tempDir, mkdirRecurse, rmdirRecurse;
        import std.conv : to;
        
        string testTmp = buildPath(tempDir(), to!string(thisProcessID));
        if (!exists(testTmp))
            mkdirRecurse(testTmp);
        scope(exit) rmdirRecurse(testTmp);
        
        execute(["dub", "init", testTmp]);
        if (compilerPath is null)
            return execute(["dub", "run"]).status != 0;
        else
            return execute(["dub", "run", "--compiler=" ~ compilerPath]).status != 0;
    }
    
    void rerunDubDependencies() {
        import dub.project;
        import dub.packagesupplier;
        
        synchronized
            isCompiling_ = true;

        ofPackageToCodeUnit = typeof(ofPackageToCodeUnit).init;
        dubToCodeUnit = typeof(dubToCodeUnit).init;
        
        BuildSettings bs;
        string[] debugVersions;
        
        dubCompiler = getCompiler(compilerPath_);
        buildPlatform = dubCompiler.determinePlatform(bs, compilerPath_, archToCompile_);
        bs.addDebugVersions(debugVersions);
        
        foreach(subpName; codeUnitNames) {
            Dub vdub = new Dub();
            vdub.loadPackageFromCwd();
            
            Package usePackage = vdub.packageManager.getFirstPackage(vdub.projectName ~ ":" ~ subpName);
            if (usePackage is null) {
                usePackage = vdub.packageManager.getFirstPackage(vdub.projectName ~ ":base");
                if (usePackage is null)
                    usePackage = vdub.packageManager.getFirstPackage(vdub.projectName);
            }
            
            if (usePackage !is null) {
                usePackage.info.buildSettings.versions[""] ~= "LiveReload_Built";

                ofPackageToCodeUnit[subpName] = usePackage;
                
                vdub.loadPackage(usePackage);
                dubToCodeUnit[subpName] = vdub;
                
                vdub.upgrade(UpgradeOptions.select);
                //vdub.upgrade(UpgradeOptions.upgrade|UpgradeOptions.printUpgradesOnly);
                vdub.project.validate();

                buildConfig = vdub.project.getDefaultConfiguration(buildPlatform);
            }
        }
        
        synchronized
            isCompiling_ = false;
    }
    
    bool dubCompile(string cu, string ofile, string[] srcFiles, string[] strImports) {
        import std.string : join;
        import std.path : dirName, baseName;
        
        logInfo("Told to compile %s %s [%s] [%s]", cu, ofile, srcFiles.join(", "), strImports.join(", "));
        
        if (cu !in dubToCodeUnit)
            cu = "base";
        
        version(Windows) {
            if (ofile[$-4 .. $] == ".exe")
                ofile.length -= 4;
        }
        
        bool compiledSuccessfully;

        //
        try {

            ofPackageToCodeUnit[cu].info.buildSettings.sourceFiles[""] = srcFiles;
            ofPackageToCodeUnit[cu].info.buildSettings.stringImportPaths[""] = strImports;
            ofPackageToCodeUnit[cu].info.buildSettings.targetName = baseName(ofile);
            ofPackageToCodeUnit[cu].info.buildSettings.targetPath = dirName(buildPath(config_.outputDir, ofile));
            
            GeneratorSettings gensettings;
            gensettings.platform = buildPlatform;
            gensettings.config = buildConfig;
            gensettings.compiler = dubCompiler;
            gensettings.buildType = "debug";
            gensettings.buildMode = BuildMode.separate;

            gensettings.linkCallback = (int ret, string output) {
                if (ret == 0)
                    compiledSuccessfully = true;
            };
            
            dubToCodeUnit[cu].generateProject("build", gensettings);
            
            return compiledSuccessfully;
        } catch (Exception e) {
            logError(e.toString());
            return false;
        }
    }
}