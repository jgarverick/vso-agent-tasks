﻿param (
    [string]$mavenPOMFile,
    [string]$options,
    [string]$goals,
    [string]$publishJUnitResults,   
    [string]$testResultsFiles, 
    [string]$codeCoverageTool,
    [string]$classfilesDirectory,
    [string]$classFilter,
    [string]$jdkVersion,
    [string]$jdkArchitecture
)

Write-Verbose 'Entering Maven.ps1' 
Write-Verbose "mavenPOMFile = $mavenPOMFile"
Write-Verbose "options = $options"
Write-Verbose "goals = $goals"
Write-Verbose "publishJUnitResults = $publishJUnitResults"
Write-Verbose "testResultsFiles = $testResultsFiles"
Write-Verbose "codeCoverageTool = $codeCoverageTool"
Write-Verbose "classfilesDirectory = $classfilesDirectory"
Write-Verbose "classFilter = $classFilter"
Write-Verbose "jdkVersion = $jdkVersion"
Write-Verbose "jdkArchitecture = $jdkArchitecture"


#Verify Maven POM file is specified
if(!$mavenPOMFile)
{
    throw "Maven POM file is not specified"
}

# Import the Task.Internal dll that has all the cmdlets we need for Build
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.TestResults"

if($jdkVersion -and $jdkVersion -ne "default")
{
    $jdkPath = Get-JavaDevelopmentKitPath -Version $jdkVersion -Arch $jdkArchitecture
    if (!$jdkPath) 
    {
        throw "Could not find JDK $jdkVersion $jdkArchitecture, please make sure the selected JDK is installed properly"
    }

    Write-Host "Setting JAVA_HOME to $jdkPath"
    $env:JAVA_HOME = $jdkPath
    Write-Verbose "JAVA_HOME set to $env:JAVA_HOME"
}

$buildRootPath = Split-Path $mavenPOMFile -Parent
$summaryFile = Join-Path $buildRootPath "CodeCoverage\summary.xml"
$reportDirectory = Join-Path $buildRootPath "CodeCoverage"

# check if code coverage has been enabled
if($codeCoverageTool)
{
   # Enable code coverage in build file
   Enable-CodeCoverage -BuildTool 'Maven' -BuildFile $mavenPOMFile -CodeCoverageTool $codeCoverageTool -ClassFilter $classFilter -ClassFilesDirectory $classFilesDirectory -SummaryFile $summaryFile -ReportDirectory $reportDirectory
}

Invoke-Maven -MavenPomFile $mavenPOMFile -Options $options -Goals $goals

# Publish test results files
$publishJUnitResultsFromAntBuild = Convert-String $publishJUnitResults Boolean
if($publishJUnitResultsFromAntBuild)
{
   # check for JUnit test result files
    $matchingTestResultsFiles = Find-Files -SearchPattern $testResultsFiles
    if (!$matchingTestResultsFiles)
    {
        Write-Host "No JUnit test results files were found matching pattern '$testResultsFiles', so publishing JUnit test results is being skipped."
    }
    else
    {
        Write-Verbose "Calling Publish-TestResults"
        Publish-TestResults -TestRunner "JUnit" -TestResultsFiles $matchingTestResultsFiles -Context $distributedTaskContext
    }    
}
else
{
    Write-Verbose "Option to publish JUnit Test results produced by Maven build was not selected and is being skipped."
}


if($codeCoverageTool)
{
   Publish-CodeCoverage -CodeCoverageTool $codeCoverageTool -SummaryFileLocation $summaryFileLocation -ReportDirectory $reportDirectory -Context $distributedTaskContext    
}
else
{
    Write-Verbose "Option to publish CodeCoverage results produced by Maven build was not selected and is being skipped."
}


Write-Verbose "Leaving script Maven.ps1"




