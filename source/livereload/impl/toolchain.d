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