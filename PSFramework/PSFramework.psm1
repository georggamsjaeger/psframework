﻿$script:PSModuleRoot = $PSScriptRoot
$script:PSModuleVersion = "0.9.14.37"

function Import-ModuleFile
{
	[CmdletBinding()]
	Param (
		[string]
		$Path
	)
	
	if ($doDotSource) { . $Path }
	else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null) }
}

# Detect whether at some level dotsourcing was enforced
$script:doDotSource = $false
if ($psframework_dotsourcemodule) { $script:doDotSource = $true }
if (($PSVersionTable.PSVersion.Major -lt 6) -or ($PSVersionTable.OS -like "*Windows*"))
{
	if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\System" -Name "DoDotSource" -ErrorAction Ignore).DoDotSource) { $script:doDotSource = $true }
	if ((Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\System" -Name "DoDotSource" -ErrorAction Ignore).DoDotSource) { $script:doDotSource = $true }
}

# Execute Preimport actions
. Import-ModuleFile -Path "$PSModuleRoot\internal\scripts\preimport.ps1"

# Import all internal functions
foreach ($function in (Get-ChildItem "$PSModuleRoot\internal\functions\*\*.ps1"))
{
	. Import-ModuleFile -Path $function.FullName
}

# Import all public functions
foreach ($function in (Get-ChildItem "$PSModuleRoot\functions\*\*.ps1"))
{
	. Import-ModuleFile -Path $function.FullName
}


# Execute Postimport actions
. Import-ModuleFile -Path "$PSModuleRoot\internal\scripts\postimport.ps1"

if ($PSCommandPath -like "*psframework.psm1*")
{
	Import-Module "$PSModuleRoot\bin\PSFramework.dll"
}