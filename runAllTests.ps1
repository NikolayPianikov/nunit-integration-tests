$nunitTestingPath = "bin\nunit"

function GetNUnitVersions
{
	return Get-Content "nunitVersions.txt"
}

function GetNuget
{
	Invoke-WebRequest "http://nuget.org/nuget.exe" -OutFile nuget.exe
}

function CopyNUnitBinFromPackage
{	
	param([string] $nunitPackagePath)

	if(!(Test-Path -Path $nunitPackagePath\tools )) { return; }

	Write-Host "Copy items from $nunitPackagePath to $nunitTestingPath"		
	Copy-Item "$nunitPackagePath\tools\*" -destination $nunitTestingPath -recurse -force
}

function CopyNUnitFrameworksFromPackage
{	
	param([string] $nunitPackagePath)

	if(!(Test-Path -Path $nunitPackagePath\lib )) { return; }

	Get-ChildItem $nunitPackagePath\lib\net* | ForEach-Object { $path=$_ -replace ".+net(\d)(\d)", "net-`$1.`$2"; $path="$nunitTestingPath\$path"; Write-Host "Copy items from $_ to $path"; Copy-Item $_\*.* -destination (new-item -type directory -force $path) -recurse -force; }	
}

function GetNUnit
{
	param([string] $nunit)

	#Get NUNit engine
	$nunitOrigPathPattern = "Added package \'(.+)\' to folder \'(.+)\'"	
	
	Write-Host "Downloading NUnit $nunit"
	$nunitPackagePaths = nuget.exe install NUnit.Console -Version $nunit -OutputDirectory packages | where {$_ -match $nunitOrigPathPattern} |  ForEach-Object {$_ -replace $nunitOrigPathPattern, "`$2\`$1" }
	$nunitFrameworksPaths = nuget.exe install NUnit -Version $nunit -OutputDirectory packages | where {$_ -match $nunitOrigPathPattern} |  ForEach-Object {$_ -replace $nunitOrigPathPattern, "`$2\`$1" }
	
	Remove-Item "$nunitTestingPath\*" -recurse

	Write-Host "Copy NUnit $nunit to $nunitDestPath"
	$nunitPackagePaths | ForEach-Object { CopyNUnitBinFromPackage $_ }	
	
	Write-Host "Copy NUnit frameworks $nunit to $nunitDestPath"
	$nunitFrameworksPaths | ForEach-Object { CopyNUnitFrameworksFromPackage $_ }		
}


function RunTests
{
	param([string]$nunitVersion)

	GetNuget	
	GetNUnit $nunitVersion
	msbuild runTests.proj
}

GetNUnitVersions | ForEach-Object {	RunTests $_ }