<#
.SYNOPSIS

Detopa - DLLs to packages.config

.DESCRIPTION

see https://github.com/TassiloPitrasch/detopa/issues

.NOTES

    Author: Tassilo Pitrasch
    Version: 0.0.4
    License: MIT

#>

# Parameters
param(
    # Path(s) to the resources to be examined
    [Parameter()][String[]]$TargetPaths,

    # Output path (directory/file)
    [Parameter()]
    [string]$OutputPath = $(Get-Location),

    # Target framework, is directly written to the XML
    [Parameter()]
    [string]$TargetFramework = "",

    # Allow examination of files that do not end with "dll" (case-insensitive)
    [Parameter()]
    [switch]$AllowNonDllFiles,

    # Use a file's name as the package name as a fallback
    [Parameter()]
    [switch]$UseBasename,

    # Allow writing packages with empty version fields
    [Parameter()]
    [switch]$AllowEmptyVersions,

    # Remove non-digit components from the version string
    # Example: "1.0.0A.0+b13234" becomes "1.0.0.0"
    [Parameter()]
    [switch]$NumericVersion,

    # Ignore the build section of a version string
    # Example: "1.0.0.0+b13234" becomes "1.0.0"
    [Parameter()]
    [switch]$IgnoreBuild,

    # Ignore the build section if it's empty or consists only of zeros
    [Parameter()]
    [switch]$IgnoreEmptyBuild,

    # Removes duplicate entries from the output file
    [Parameter()]
    [switch]$RemoveDuplicates,

    # Output version info
    [Parameter()]
    [switch]$Version
)


# Function to cleanse a package's version string as specified by user preferences
function Cleanse-Version {
    param(
        [Parameter(Mandatory)]
        [string]$RawVersion
    )

    # Note: Cleansing non-numeric characters happens before removing the build section.										  
    # This means a version like "0+b1234" is fully removed if both -NumericVersion and -IgnoreEmptyBuild are set.
    $VersionParts = $RawVersion.Trim() -split '\.'

    if ($NumericVersion) {
        for ($i = 0; $i -lt $VersionParts.Length; $i++) {
            $VersionParts[$i] = $VersionParts[$i] -replace '(\d+).*', '$1'
        }
    }

    $Build = $VersionParts[3]
    if ($IgnoreBuild -or ($IgnoreEmptyBuild -and ($Build -match '^0+$'))) {
        Write-Debug "Ignoring empty or unnecessary build section."
        return $VersionParts[0..2] -join '.'
    } else {
        return $VersionParts -join '.'
    }
}


# Function to examine a target (path) - main method of the script
function Examine-Target-Path {
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    # If duplicates are not to be removed from the output file,
    # a comment is added identifying each target
    if (-not $RemoveDuplicates) {
        $xmlWriter.WriteComment($TargetPath)
    }

    # Retrieve the target files
    $files = Get-ChildItem -Path $TargetPath

    # Process files one-by-one
    foreach ($file in $files) {
        # Skip non-DLLs unless explicitly allowed
        if (-not $AllowNonDllFiles -and -not $file.Extension.Equals('.dll', 'InvariantCultureIgnoreCase')) {
            Write-Debug ("Skipping non-DLL file '{0}'." -f $file.Name)
            continue
        }

        Write-Debug ("Examining file '{0}'." -f $file.Name)

        # Extract file metadata
        $info = Get-Item -Path $file.FullName
        $versionInfo = $info.VersionInfo

        # Clean the name fields by removing the ".dll" extension
        $internalName = $versionInfo.InternalName -replace '\.dll$', ''
        $originalFileName = $versionInfo.OriginalFilename -replace '\.dll$', ''

        # Determine package name
        $packageName = if ($internalName) {
            Write-Debug "Using InternalName field."
            $internalName
        } elseif ($originalFileName) {
            Write-Debug "Using OriginalFilename field."
            $originalFileName
        } elseif ($UseBasename) {
            Write-Debug "Using file basename."
            $info.BaseName
        } else {
            Write-Debug ("Skipping '{0}' — no package name found." -f $file.Name)
            continue
        }

        # Parse and cleanse package version
        $packageVersion = $versionInfo.ProductVersion
        if ([string]::IsNullOrEmpty($packageVersion)) {
            if (-not $AllowEmptyVersions) {
                Write-Debug ("Skipping '{0}' — no version info available." -f $file.Name)
                continue
            }
            Write-Debug ("Writing package '{0}' without version." -f $packageName)
            $finalPackageVersion = ''
        } else {
            $finalPackageVersion = Cleanse-Version -RawVersion $packageVersion
        }

        # Skipping duplicates (if enabled)
        $packageIdentifier = "{0}/{1}" -f $packageName, $finalPackageVersion
        if ($examinedPackages[$packageIdentifier]) {
            continue
        } else {
            $examinedPackages[$packageIdentifier] = $RemoveDuplicates
        }

        # Write package entry to XML
        Write-Debug ("Writing package '{0}/{1}' to output." -f $packageName, $finalPackageVersion)
        $xmlWriter.WriteStartElement('package')
        $xmlWriter.WriteAttributeString('id', $packageName)
        $xmlWriter.WriteAttributeString('version', $finalPackageVersion)
        $xmlWriter.WriteAttributeString('targetFramework', $TargetFramework)
        $xmlWriter.WriteEndElement()
    }
}

# Enable debug output without script halting
if ($PSBoundParameters.ContainsKey('Debug')) {
    $DebugPreference = 'Continue'
}

if ($Version) {
    $notes = (Get-Help $MyInvocation.InvocationName).alertset | Out-String
    if ($notes -match 'Version:\s*([\d\.]+)') {
        Write-Output $matches[1]
    } else {
        Write-Output "Version could not be parsed."
    }
    exit
}

if ([string]::IsNullOrEmpty($TargetPath)) {
    throw [System.ArgumentException] "Parameter 'TargetPath' is required."
}

# Create a temporary file path for XML output
$temporaryOutputPath = New-TemporaryFile

try {
    Remove-Item -Path $temporaryOutputPath -ErrorAction Stop
} catch [System.Management.Automation.ItemNotFoundException] {
    # File does not exist — no action needed
}

# Define the final output path
$OutputObject = Get-Item $OutputPath
if ($OutputObject.PSIsContainer) {
    $finalOutputPath = Join-Path -Path $OutputObject.FullName -ChildPath 'packages.config'
} else {
      $finalOutputPath = $OutputObject.FullName
}

# Create an XmlWriter for the packages.config output
$xmlWriter = New-Object System.Xml.XmlTextWriter($temporaryOutputPath, $null)
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 2
$xmlWriter.IndentChar = " "
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement('packages')

# Hashtable containing the examined packages
$examinedPackages = @{}


# Examine each target path
foreach ($TargetPath in $TargetPaths)  {
    Write-Debug ("Examining path '{0}'." -f $TargetPath)
    Examine-Target-Path $TargetPath
}

# Finalize the XML document
Write-Debug "Finalizing XML output."
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()

# Move the temporary file to its final destination
Write-Debug ("Moving temporary file to '{0}'." -f $finalOutputPath)
Move-Item -Path $temporaryOutputPath -Destination $finalOutputPath -Force
