﻿function Set-PSFConfig
{
<#
	.SYNOPSIS
		Sets configuration entries.
	
	.DESCRIPTION
		This function creates or changes configuration values.
		These can be used to provide dynamic configuration information outside the PowerShell variable system.
	
	.PARAMETER FullName
		The full name of a configuration element. Must be namespaced <Module>.<Name>.
		The name can have any number of sub-segments, in order to better group configurations thematically.
	
	.PARAMETER Name
		Name of the configuration entry. If an entry of exactly this non-casesensitive name already exists, its value will be overwritten.
		Duplicate names across different modules are possible and will be treated separately.
		If a name contains namespace notation and no module is set, the first namespace element will be used as module instead of name. Example:
		-Name "Nordwind.Server"
		Is Equivalent to
		-Name "Server" -Module "Nordwind"
	
	.PARAMETER Module
		This allows grouping configuration elements into groups based on the module/component they serve.
		If this parameter is not set, the configuration element must have a module name in the name parameter (the first segment will be taken, irrespective of whether that makes sense).
	
	.PARAMETER Value
		The value to assign to the named configuration element.
	
	.PARAMETER Description
		Using this, the configuration setting is given a description, making it easier for a user to comprehend, what a specific setting is for.
	
	.PARAMETER Validation
		The name of the validation script used for input validation.
		These can be used to validate make sure that input is of the proper data type.
		New validation scripts can be registered using Register-PSFConfigValidation
	
	.PARAMETER Handler
		A scriptblock that is executed when a value is being set.
		Is only executed if the validation was successful (assuming there was a validation, of course)
	
	.PARAMETER Hidden
		Setting this parameter hides the configuration from casual discovery. Configurations with this set will only be returned by Get-Config, if the parameter "-Force" is used.
		This should be set for all system settings a user should have no business changing (e.g. for Infrastructure related settings such as mail server).
	
	.PARAMETER Default
		Setting this parameter causes the system to treat this configuration as a default setting. If the configuration already exists, no changes will be performed.
		Useful in scenarios where for some reason it is not practical to automatically set defaults before loading userprofiles.
	
	.PARAMETER Initialize
		Use this when setting configurations as part of module import.
		When initializing a configuration, it will only do a thing if the configuration hasn't already been initialized (So if you load the module multiple times or in multiple runspaces, it won't make a difference)
		Also, if there already was a non-initialized setting set for a given configuration, it will then try to set the old value again.
		This value will be processed by handlers, if any are set.
	
	.PARAMETER DisableValidation
		This parameters disables the input validation - if any - when processing a setting.
		Normally this shouldn't be circumvented, but just in case, it can be disabled.
	
	.PARAMETER DisableHandler
		This parameter disables the configuration handlers.
		Configuration handlers are designed to automatically process input set to a config value, in addition to writing the value.
		In many cases, this is used to improve performance, by forking the value location also to a static C#-field, which is then used, rather than searching a Hashtable.
		Normally these shouldn't be circumvented, but just in case, it can be disabled.
	
	.PARAMETER EnableException
		Replaces user friendly yellow warnings with bloody red exceptions of doom!
		Use this if you want the function to throw terminating errors you want to catch.
	
	.EXAMPLE
		PS C:\> Set-PSFConfig -FullName 'MyModule.User' -Value "Friedrich" -Description "The user under which the show must go on."
		
		Creates a configuration entry under the module "MyModule" named "User" with the value "Friedrich"
	
	.EXAMPLE
		PS C:\> Set-PSFConfig -Name 'mymodule.User' -Value "Friedrich" -Description "The user under which the show must go on." -Handler $scriptBlock -Initialize -Validation String
		
		Creates a configuration entry ...
		- Named "mymodule.user"
		- With the value "Friedrich"
		- It adds a description as noted
		- It registers the scriptblock stored in $scriptBlock as handler
		- It initializes the script. This block only executes the first time a it is run like this. Subsequent calls will be ignored.
		- It registers the basic string input type validator
		This is the default example for modules using the configuration system.
		Note: While the -Handler parameter is optional, it is important to add it at the initial initialize call, if you are planning to add it.
		Only then will the system validate previous settings (such as what a user might have placed in his user profile)
	
	.EXAMPLE
		PS C:\> Set-PSFConfig 'Company' 'ConfigLink' 'https://www.example.com/config.xml' -Hidden
		
		Creates a configuration entry named "ConfigLink" in the "Company" module with the value 'https://www.example.com/config.xml'.
		This entry is hidden from casual discovery using Get-PSFConfig.
	
	.EXAMPLE
		PS C:\> Set-PSFConfig 'Network.Firewall' '10.0.0.2' -Default
		
		Creates a configuration entry named "Firewall" in the "Network" module with the value '10.0.0.2'
		This is only set, if the setting does not exist yet. If it does, this command will apply no changes.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(DefaultParameterSetName = "FullName")]
	Param (
		[Parameter(ParameterSetName = "FullName", Position = 0, Mandatory = $true)]
		[string]
		$FullName,
		
		[Parameter(ParameterSetName = "Module", Position = 1, Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(ParameterSetName = "Module", Position = 0)]
		[string]
		$Module,
		
		[Parameter(ParameterSetName = "FullName", Position = 1)]
		[Parameter(ParameterSetName = "Module", Position = 2)]
		[AllowNull()]
		[AllowEmptyCollection()]
		[AllowEmptyString()]
		$Value,
		
		[string]
		$Description,
		
		[string]
		$Validation,
		
		[System.Management.Automation.ScriptBlock]
		$Handler,
		
		[switch]
		$Hidden,
		
		[switch]
		$Default,
		
		[switch]
		$Initialize,
		
		[switch]
		$DisableValidation,
		
		[switch]
		$DisableHandler,
		
		[switch]
		$EnableException
	)
	
	#region Prepare Names
	if ($PSCmdlet.ParameterSetName -eq "FullName")
	{
		if (-not $FullName.Trim(".").Contains("."))
		{
			Stop-PSFFunction -Message "Invalid Name: $FullName ! At least one '.' is required, to separate module from name" -EnableException $EnableException -Category InvalidArgument
			return
		}
		
		$Module = $FullName.Split(".")[0].ToLower().Trim(".")
		$Name = $FullName.Substring(($Module.Length + 1)).ToLower().Trim(".")
		$internalFullName = $FullName.ToLower().Trim(".")
	}
	else
	{
		$Name = $Name.ToLower().Trim(".")
		if ($Module) { $Module = $Module.ToLower().Trim(".") }
		
		if ((Test-PSFParameterBinding -ParameterName "Module" -Not) -and ($Name -match ".+\..+"))
		{
			$r = $Name | select-string "^(.+?)\..+" -AllMatches
			$Module = $r.Matches[0].Groups[1].Value
			$Name = $Name.Substring($Module.Length + 1)
		}
		elseif ((Test-PSFParameterBinding -ParameterName "Module" -Not) -and ($Name -notmatch ".+\..+"))
		{
			Stop-PSFFunction -Message "Invalid Name: $Name ! At least one '.' is required when not explicitly specifying a module name, to separate module from name" -EnableException $EnableException -Category InvalidArgument
			return
		}
		
		If ($Module) { $internalFullName = $Module, $Name -join "." }
		else { $internalFullName = $Name }
	}
	#endregion Prepare Names
	
	#region Prepare runtime and kill execution as needed
	if ([PSFramework.Configuration.ConfigurationHost]::Configurations.ContainsKey($internalFullName))
	{
		$itExists = $true
		$itIsInitialized = [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Initialized
		$itIsEnforced = [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].PolicyEnforced
	}
	else
	{
		$itExists = $false
		$itIsInitialized = $false
		$itIsEnforced = $false
	}
	
	if ($itExists -and $Default) { return }
	if ($itIsInitialized -and $Initialize) { return }
	if ($itIsEnforced -and (-not $Initialize))
	{
		Stop-PSFFunction -Message "Could not update configuration due to policy settings: $internalFullName" -EnableException $EnableException -Category PermissionDenied
		return
	}
	
	if (Test-PSFParameterBinding -ParameterName "Validation")
	{
		if (-not ([PSFramework.Configuration.ConfigurationHost]::Validation.Keys -contains $Validation.ToLower()))
		{
			Stop-PSFFunction -Message "Invalid validation name: $Validation. Supported validations: $([PSFramework.Configuration.ConfigurationHost]::Validation.Keys -join ", ")" -Category InvalidArgument -Target $Name
			return
		}
	}
	#endregion Prepare runtime and kill execution as needed
	
	#region Initializing a configuration
	if ($Initialize)
	{
		if ($itExists)
		{
			$oldValue = [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Value
			$cfg = [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName]
		}
		else { $cfg = New-Object PSFramework.Configuration.Config }
		$cfg.Name = $Name
		$cfg.Module = $Module
		$cfg.Description = $Description
		$cfg.Value = $Value
		$cfg.Handler = $Handler
		if ($Validation) { $cfg.Validation = [PSFramework.Configuration.ConfigurationHost]::Validation[$Validation.ToLower()] }
		$cfg.Hidden = $Hidden
		$cfg.Initialized = $true
		[PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName] = $cfg
		
		if ($itExists) { Set-PSFConfig -Name $internalFullName -Value $oldValue }
	}
	#endregion Initializing a configuration
	
	#region Regular configuration update
	else
	{
		if (-not $itExists)
		{
			$cfg = New-Object PSFramework.Configuration.Config
			$cfg.Name = $Name
			$cfg.Module = $Module
			$cfg.Description = $Description
			$cfg.Handler = $Handler
			if ($Validation) { $cfg.Validation = [PSFramework.Configuration.ConfigurationHost]::Validation[$Validation.ToLower()] }
			$cfg.Hidden = $Hidden
			[PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName] = $cfg
			
			Set-PSFConfig -Name $internalFullName -Value $Value
			return
		}
		
		else
		{
			[PSFramework.Configuration.Config]$cfg = [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName]
			if ((-not $DisableValidation) -and ($cfg.Validation) -and (Test-PSFParameterBinding -ParameterName "Value"))
			{
				$validationScript = [System.Management.Automation.ScriptBlock]::Create($cfg.Validation)
				$tempValue = $value
				if (($null -ne $tempValue) -and ($tempValue.GetType().ImplementedInterfaces.Name -contains "ICollection"))
				{
					$tempValue = @($tempValue, $null)
				}
				
				$testResult = $validationScript.Invoke($tempValue)
				if (-not $TestResult.Success)
				{
					Stop-PSFFunction -Message "Could not update configuration $internalFullName | Failed validation: $($testResult.Message)" -EnableException $EnableException -Category InvalidResult -Target $internalFullName
					return
				}
				$Value = $testResult.Value
			}
			if ((-not $DisableHandler) -and ($cfg.Handler) -and (Test-PSFParameterBinding -ParameterName "Value"))
			{
				$handlerScript = [System.Management.Automation.ScriptBlock]::Create($cfg.Handler)
				
				$tempValue = $value
				if (($null -ne $tempValue) -and ($tempValue.GetType().ImplementedInterfaces.Name -contains "ICollection"))
				{
					$tempValue = @($tempValue, $null)
				}
				
				try { $handlerScript.Invoke($tempValue) }
				catch
				{
					Stop-PSFFunction -Message "Could not update configuration $internalFullName | Failed handling $_" -EnableException $EnableException -Category InvalidResult -Target $internalFullName
					return
				}
			}
			
			if (Test-PSFParameterBinding -ParameterName "Hidden") { [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Hidden = $Hidden }
			if (Test-PSFParameterBinding -ParameterName "Value") { [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Value = $Value }
			if (Test-PSFParameterBinding -ParameterName "Description") { [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Description = $Description }
			if (Test-PSFParameterBinding -ParameterName "Handler") { [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Handler = $Handler }
			if (Test-PSFParameterBinding -ParameterName "Validation") { [PSFramework.Configuration.ConfigurationHost]::Configurations[$internalFullName].Validation = [PSFramework.Configuration.ConfigurationHost]::Validation[$Validation.ToLower()] }
		}
	}
	#endregion Regular configuration update
}
