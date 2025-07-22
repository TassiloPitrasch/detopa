# Parameters
param(
    # Path to the resources to be examined
    [Parameter(Mandatory)]
    [string]$TargetPath,

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
    [switch]$IgnoreEmptyBuild
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

# Enable debug output without script halting
echo $Debug
if ($PSBoundParameters.ContainsKey('Debug')) {
    $DebugPreference = 'Continue'
}

# Retrieve the target files				 
$files = Get-ChildItem -Path $TargetPath

# Create a temporary file path for XML output
$temporaryOutputPath = New-TemporaryFile

try {
    Remove-Item -Path $temporaryOutputPath -ErrorAction Stop
} catch [System.Management.Automation.ItemNotFoundException] {
    # File does not exist — no action needed
}

# Define the final output path
$finalOutputPath = Join-Path -Path (Get-Location) -ChildPath 'packages.config'

# Create an XmlWriter for the packages.config output
$xmlWriter = New-Object System.Xml.XmlTextWriter($temporaryOutputPath, $null)
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 2
$xmlWriter.IndentChar = " "
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement('packages')

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

    # Write package entry to XML
    Write-Debug ("Writing package '{0}/{1}' to output." -f $packageName, $finalPackageVersion)
    $xmlWriter.WriteStartElement('package')
    $xmlWriter.WriteAttributeString('id', $packageName)
    $xmlWriter.WriteAttributeString('version', $finalPackageVersion)
    $xmlWriter.WriteEndElement()
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

# SIG # Begin signature block
# MIIIkQYJKoZIhvcNAQcCoIIIgjCCCH4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUI16Ej7t95n7aUbECGVTmzEDn
# j1mgggUgMIIFHDCCAwSgAwIBAgIQZV3hw2UslqpHEPQ9zVxk1jANBgkqhkiG9w0B
# AQsFADAmMSQwIgYDVQQDDBtwb3dlcnNoZWxsLnNpZ25pbmcud29iZWVjb24wHhcN
# MjUwNzIxMjA0MDUyWhcNMzUwNzIxMjA1MDUyWjAmMSQwIgYDVQQDDBtwb3dlcnNo
# ZWxsLnNpZ25pbmcud29iZWVjb24wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQDInsuSBnNYpeuL8TQ9AYblnXA+GLtO2Sdw9Fh5GTqKTikoBpULWXkOzS1a
# pZN+Kvk/dm8bjKYR36ow2CEvC7/m6ozWyUVjSvIajzqt1rj2kZDBE80Dtu8m8VHb
# sfDxD5FccTkmrRjz7zDs/nkbEQ0A1RxuQSFM+0knYi64OHoaPRmtDuevMhS/UuF8
# RGLgIov0SdAFiUmhXBJ3HM7kewwUg2U8+FDJPTN5Wn4kZR1hQo0n9qqtKkHE+m8O
# jTinzOkkZcoa+is64xXrSAaJ0rtlwrm0UgFpNB+u1ccwZseFX0+MSgE/78Z/qxKa
# K171QBijWZ2+oCLZ8oa3UXMcF3xZHvrF+/zps7JWJsi4UvB7l1/NEVrXTyMVZjYK
# Q4GIN3rZl+Ndh/Xcd+9+G2Ipe0sqpfCiiRlL7y/3Ro8hEUu/fJ/5jlx+j5iVhYll
# 2W7flqhMKLTwUK88my1Z3c3WRhjbiH9I1091ADg5zhbhB/I3knIouN+OnAeJ47j4
# N9IRNWi+2D/DNYyMuqIYh/yCejYIs6g3vWeX5RbpoaGcq2qsNC5jB17x9b7BwhUw
# QPOmH7AQzajFqPs0iJeFT/x+dcYvykQEbu4biBLFDspmvfCLFCEeOc/ESCcMuK9g
# TLrmTP0UF7N1zD1P37BMqVLxMK60gYeA7h0q0hmArfINLPU2JQIDAQABo0YwRDAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFNnH
# oT4r4TaGGCUghcxWA/a4B5dNMA0GCSqGSIb3DQEBCwUAA4ICAQArONIC4MIbKsHj
# valMPGI8SJiMex4Kz3adiCAS37WXpzBVJnGjMpNtDAzogwE7i3JTGS5LE/Bwjo/R
# CmWykjpBhJhQTMUJkO4QxN1S21UXnG1nC6S07NkuWP/bClC3umk7ypCU/mA7jjcA
# ksKyf7YY23kt4Dq8jC9vKUJiB9jhCa1kxJ7zW/ym+rBKq6rX2NUWqzUIGTGhLlq7
# CiKHAiA+WzHF7y3bLJU+tB+qNM2FMfAAB3ING68sZF6wxtXfdoipur9Oq7180HCP
# FzcOjSiz9S3T6ab8B9rxwAFPnmAvNYeapEo1W+PhMbjcUYSf58i5kChc07Fjj+2U
# NZ8Orh3UqOx4k72RysFT1f3jGsfC+BhP9AI0wyVUsh3I5NPHcZCJzivXb9TGeaPY
# hr/CGiNLqNIj6mASYyGOKNQ4sdphW71/RSojN2LmzKVGVhHpo6WER0CYOJU06PpH
# SmJ/3hL9yUsKuHS6EKD+uxD32Nh8BrieTbNJ75uJZbVAoBG/edyt5ANSbrK0FeT5
# djsOqxfVB5sKGK5CW/B0Kz62z43Nv7Wm0wJL702HCjHs/CsoR+YKPhAJew6wRn3A
# pY1EEE9Wp3MaeXLHYJGs6DC6GuuiyUZP1TzK3VV/cKPEogUUblklF1HRyPL1dFTZ
# zkV5ikxn5F+P0kUS30ohghnPD614RDGCAtswggLXAgEBMDowJjEkMCIGA1UEAwwb
# cG93ZXJzaGVsbC5zaWduaW5nLndvYmVlY29uAhBlXeHDZSyWqkcQ9D3NXGTWMAkG
# BSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMG
# CSqGSIb3DQEJBDEWBBTAi4Y+jbV0uZy6Z/AQ0oqP/8uEtDANBgkqhkiG9w0BAQEF
# AASCAgA2SetLcjIGcNXxq6j05OAHiSjV7juJrWSvQLFkCViDtuA4CytfIXrfu9Gl
# HbhpzqKHWDhXqyZhirWEHtuFuiz18KLVS0KHJsxWieio3It91dqkZbWDBmg9xWBB
# vQsGIvW91txzkDmarWHRtTlhHh8uePMmOH0PV0DCoetSvuk6Tti5Xi9b4MgYi5rr
# FGZbmpYZ+/vuY+I76kXDYFGokVdklARfiNWh0LJwFmi4slzpHIHw4UsvwCRqzYik
# McENXnHHsD9UvjORjzRnfxls6tsAMa0z66FEoJsL0QkThyAo42y/jOL+6mB7jKpS
# 1hzSRwF8vLN/gEVJyhS/oLM3Tb0l4IyZ8nHziZIR3xivXZPrhQstAnUXytsl4TG2
# si+eT8hujmv9jvNbFdNoWYAcrMawyHO2inCaSnOJJNdf0BFReMDtLLovo1rVnOdu
# 6e+flYmH+z6moOLFSL/XBBKK/7RuKTcJnu3gVCPtnuiylwyZRRtMEdBUcoEApbDt
# V999VOimFyyVghT0t4BM4KBiziowkFm4r9+wUv0Q3AC6FG9eGJXFTZZTmwgXHJsl
# NoF/erGu+Uy8PBq3V4M3I0InCNzdXrXmMjNkb9ZQiGY+FC/LmumNKZ66hbXqgSip
# PxQuJMtgm99lIjA+Hr/3ECyzi56b1WOmu+zKpakTZ6E0IznouA==
# SIG # End signature block
