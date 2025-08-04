# DETOPA - DLLs to packages.config!
## What is detopa?
detopa is a small Powershell-script to generate a `packages.config`-file directly from DLL-files. It works by parsing file-metadata, which most of DLLs do contain.
## Why is detopa?
**TL;DR: detopa is useful to generate a first overview of the dependencies of a csharp project.**
Originally, the idea was to have an adapter to the great [cdxgen](https://github.com/CycloneDX/cdxgen), which creates SBOMs (Software Bill of Materials) for all kinds of projects, programming languages and tools. However, it struggled to produce meaningful output when supplied with just a bunch of DLLs. detopa bridges that gap by generating a `packages.config`-file, which can be picked up by cdxgen for further analysis.
## How is detopa?
Just run the script. Make sure to allow the execution of "self-signed" scripts. Alternatively, use the executable included in the assets of each release. 
See the following table for command-line options:
| Flag | Description | Default | Required |
|--|--|--|--|
| TargetPath | Path to the resources to be examined. Can be a single file or a directory. Supports standard Windows wildcards | - | True |
| OutputPath | File/directory the output is written to. | `packages.config` in the current working directory | False |
| TargetFramework | Target framework as defined in [target-frameworks](https://learn.microsoft.com/en-us/nuget/reference/target-frameworks) | "" | False |
| AllowNonDllFiles | Allows the analysis of non DLL-files, which are skipped by default. Use at own risk, might cause severe decrease of performance | False | False |
| UseBasename | Fallback option to use the local filename for a package if the actual name could not be parsed from the metadata. Risk of many incorrect entries in `packages.config` | False | False |
| AllowEmptyVersions | Allows entries without versions | False | False |
| NumericVersion | Remove non-digit components from the version. Usually increases the quality of the entries | False | False |
| IgnoreBuild |  Ignore the build section of a version. Increases the quality of the entries | False | False |
| IgnoreEmptyBuild | Ignore the build section if it's empty or consists only of zeros. Increases the quality of the affected entries | False | False |
| Version | Displays the version of the script and exits afterwards | False | False |

Examples for the last three options:
 - `1.0.0A.0+b13234` becomes `1.0.0.0` with `-NumericVersion`
 - `1.0.0.0+b13234` becomes `1.0.0` with `-IgnoreBuild`
 - `1.0.0.0+b13234` becomes `1.0.0` with combined `-NumericVersion` and `-IgnoreEmpytBuild`

Note that this README was written by a human and does therefore not contain a bunch of fancy emojis. If you really need them, feel free to pick one of these:  🚀 🛠️ 📦 ✅ 📄

