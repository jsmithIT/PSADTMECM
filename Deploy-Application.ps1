<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $false)]
	[ValidateSet('Install', 'Uninstall', 'Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory = $false)]
	[ValidateSet('Interactive', 'Silent', 'NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory = $false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory = $false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory = $false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	##* Variables: Application
	[string]$appVendor = 'Microsoft'
	[string]$appName = 'Microsoft Endpoint Configuration Manager Console'
	[string]$appVersion = '5.2207.1049.1000'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.1.2'
	[string]$appScriptDate = '2022.09.29'
	[string]$appScriptAuthor = 'JBSMITH, KTEUTON'

	##* Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = "$appName ($appVersion)"
	[string]$installTitle = "$appName ($appVersion)"

	##*===============================================
	##* ANCHOR: VARIABLES - Template
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# Template array(s)/variable(s) used within the PSADT.

	##* InstallationWelcomeCloseApps
	# Used with the PSADT 'Show-InstallationWelcome -CloseApps' function.
	# Mainly used in the Pre-Installation and Pre-Uninstallation phases.
	# This variable will tell users what needs to be closed during install/uninstall phases.
	$CloseApps = "hh=Help Window,Microsoft.ConfigurationManagement=Microsoft Enpoint Configuration Manager Console, CmRcViewer=SCCM Remote Control"

	##* Application install parameters.
	# 64-bit application
	# 64-bit application install name.
	# $64bitAppInstallName = ""
	# Application install Path.
	$64bitAppInstallPath = "$PSScriptRoot\Files\ConsoleSetup.exe"
	# Application  install parameters.
	$64bitAppInstallParam = "/q TargetDir=`"$Env:ProgramFiles\ConfigMgr Console`" DefaultSiteServerName=CONFIDENTIAL" 

	##* Secondary Application install parameters.
	# 64-bit application
	# 64-bit application install name.
	$64bitAppInstallName2 = "Report Viewer"
	# Application install Path.
	$64bitAppInstallPath2 = "$PSScriptRoot\Files\ReportViewer.exe"
	# Application install parameters.
	$64bitAppInstallParam2 = "/q"

	##* Remove Application Names 
	# Mainly used in the Pre-Installation, Pre-Uninstallation, Uninstallation and Post-Uninstallation phases.
	# These scalable Array(s)/Variable(s) are used to remove previous application(s) by name.
	# $RemoveAppNamesMSI = @("")
	$RemoveAppNamesEXE = @("Microsoft Endpoint Configuration Manager Console, Configuration Manager Console, System Center Configuration Manager,Microsoft Configuration Management,Report Viewer, Microsoft ReportViewer 2010 SP1 Redistributable (KB2549864)")

	##* Application uninstall parameters.
	# 64-bit application
	# 64-bit application uninstall name.
	# $64bitAppUninstallName = ""
	# Application uninstall path.
	$64bitAppUninstallPath = "$PSScriptRoot\Files\ConsoleSetup.exe"
	# Application uninstall parameters.
	$64bitAppUninstallParam = "/q /uninstall"

	##* Secondary Application uninstall parameters.
	# 64-bit application
	# 64-bit application uninstall name.
	# $64bitAppUninstallName2 = ""
	# Application uninstall path.
	$64bitAppUninstallPath2 = "$PSScriptRoot\Files\ReportViewer.exe"
	# Application uninstall parameters.
	$64bitAppUninstallParam2 = "/q /uninstall"

	##* Antiquated Application uninstall parameters
	# 64-bit application
	# 64-bit application uninstall name.
	$64bitAppUninstallName3 = "SCCM Remote Control"
	# Application uninstall path.
	$64bitAppUninstallPath3 = "C:\Windows\ccmsetup\ccmsetup.exe"

	##* Application Settings Directory
	# Directory where application settings reside.
	$appSettingsDir = "$Env:ProgramData\Tuolumne County\Application Settings\Microsoft Endpoint Configuration Manager Console"

	## Set variables to match script variables
	# These Variable(s) keep the spaces the PSADT script removes. These can and are used in titles, messages, logs and the PIRK information for the application being installed.
	$apVendor = $appVendor
	$apName = $appName
	$apversion = $appVersion
	$apScriptVersion = $appScriptVersion
	##*===============================================
	##* ANCHOR: VARIABLES - Author
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# If the template array(s)/variable(s) aren't enough, add more array(s)/variable(s) here.

	# Antiquated application registry key path.
	$AntiquatedKeyPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{BAD22111-E952-43E9-814C-721A0CC1E95D}"

	# Name of activesetup key for MECM.
	$SubKeyName = "MECM Console - Setting Default Server"

	# Path to the executable that sets the default server.
	$ExePath = "$PSScriptRoot\SupportFiles\Server Name.EXE"

	# Path to local copy of executable.
	$LocalExe = "$Env:Programfiles\Microsoft Endpoint Configuration Manager Console"
	
	# Default server setting executable.
	$ASExecuteable = "Server Name.EXE"

	##*===============================================
	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.3'
	[string]$deployAppScriptDate = '30/09/2020'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* ANCHOR: PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		# Check if deployment is interactive. 
		# If yes (it is interactive), show install prompt.
		If ($DeployMode -eq "Interactive") {
			$dialog = (Show-InstallationPrompt -Icon "Information" -PersistPrompt -ButtonMiddleText "OK" -Message "Changes are going to be made to your device. `n `n Please save your work and close all windows. `n `n To defer the changes, click the defer button on the next screen.")
		}

		# Check if user accepted the install prompt.
		# If yes (it was accepted), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($dialog -eq "OK") { 
			Show-InstallationWelcome -CloseApps "$CloseApps" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}

		# For each item in the array...
		# Check if previous EXE versions of application are installed.  
		# If application is installed, uninstall previous EXE versions of application and secondary application.
		# If uninstall failed, log results. Exit script. 
		# Else, log results from check.
		Foreach ($RemoveAppNameEXE in $RemoveAppNamesEXE) {
			# Check if previous EXE versions of application are installed.  
			$RemoveAppNamesEXECheck = Get-InstalledApplication -Name "$RemoveAppNameEXE"
			If ($null -eq $RemoveAppNamesEXECheck) {
				# Uninstall previous EXE versions of application(s).      
				Try {
					# Uninstalling main application.
					Execute-Process -FilePath "$64bitAppUninstallPath" -Arguments "$64bitAppUninstallParam"
					# Uninstalling secondary application.
					Execute-Process -FilePath "$64bitAppUninstallPath2" -Arguments "$64bitAppUninstallParam2"
					# Removing desktop shortcuts.
					Remove-Item -Path "${Env:PUBLIC}\Desktop\Remote Control Viewer.lnk" -Force
				}
				# If uninstall failed, log results. Exit script.
				Catch [System.Exception] {
					Write-Log -Message "Uninstalling previous EXE versions of $RemoveAppNameEXE failed with error: $_."
					Write-Log -Message "Exiting script with error."
					Exit-Script -ExitCode 1627
				}
			}
		}

		# Check if antiquated application (SCCM Console) is installed. 
		# If it is installed, uninstall the application and delete registry information.
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "$64bitAppUninstallPath3") { 
			# Remove registry key.
			Try {
				Write-Log -Message "$64bitAppUninstallName3 registry key exists. Removing..."
				Remove-Item -Path "$AntiquatedKeyPath" -Force
				Write-Log -Message "Removing $64bitAppUninstallName3 registry key complete."
			}
			# If removal failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Removing registry key failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
			# Uninstall application.
			Try {
				Write-Log -Message "Uninstalling $64bitAppUninstallName3 Viewer."
				# Removes Tuolumne County package crumbs.
				Remove-File -Path "$Env:ProgramFiles (x86)\Tuolumne County\$64bitAppUninstallName3"
				# Removes shortcuts.
				Remove-Item -Path "${Env:PUBLIC}\Desktop\SCCM Remote Control.lnk" -Force
				# Delete the activesetup key
				Set-ActiveSetup -Key "$SubKeyName" -PurgeActiveSetupKey
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Uninstalling $64bitAppUninstallName3 failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "$64bitAppUninstallName3 is not installed."  
		}

		# Check if previous versions of package information registry key (PIRK) exist. 
		# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
			# Remove previous versions of package information registry key (PIRK).
			Try {
				Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
				Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
		}

		# Update (refresh) the desktop.
		Update-Desktop

		##*===============================================
		##* ANCHOR: INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		# Show installation progress message window.
		Show-InstallationProgress -StatusMessage "Installing `n `n $apName ($apversion) `n `n Please Wait..." 

		# Install application(s).
		# If installation failed, log results. Exit script.
		# Check if previous MSI versions of application are installed.
		Try {
			Write-log -Message "Previous versions of $apName are installed. Installing $apName ($apversion)."
			#Moves the default server setter to a local location.
			Copy-Item -Path "$ExePath" -Destination "$LocalExe" -Force -Recurse
			#Installs application.
			Execute-Process -Path "$64bitAppInstallPath" -Parameters "$64bitAppInstallParam"
			Write-Log -Message "Installing $apName ($apversion) complete." 
		}
		# If install failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Installing $apName ($apversion) failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		# Install the secondary application (Report Viewer).
		# If installation failed, log results. Exit script.
		# Check if previous MSI versions of application are installed.
		Try {
			Write-log -Message "Previous versions of $64bitAppInstallName2 are installed. Installing $64bitAppInstallName2."
			Execute-Process -Path "$64bitAppInstallPath2" -Parameters "$64bitAppInstallParam2"
			Write-Log -Message "Installing $64bitAppInstallName2 complete." 
		}
		# If install failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Installing $64bitAppInstallName2 failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##* Every package should have a package information registry key (PIRK), which details what the $apversion and $apScriptVErsion are, along with any other information.
		# Create package information registry key (PIRK).
		# If creation failed, log results. Exit script.
		Try {
			Write-Log -Message "Creating package information registry key (PIRK)."
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information" -Name "Readme" -Value "These Package Information Registry Keys (PIRKs) are used for SCCM application detection. Please do not modify unless you know what you are doing." -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName" -Name "apVersion" -Value "$apversion" -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName" -Name "apScriptVersion" -Value "$apScriptVErsion" -Type String
			Write-Log -Message "Creating package information registry key (PIRK) complete." 
		}
		# If creation failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Creating package information registry key (PIRK) failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##*===============================================
		##* ANCHOR: POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		# Creates a shortcut on the desktop for Remote Control Viewer.
		# If shortcut creation failed, log the results.
		# If shortcut creation was successful, log the results.
		Try {
			Write-Log -Message "Creating Remote Control Viewer desktop shortcut..."
			New-Shortcut -Path "${Env:PUBLIC}\Desktop\Remote Control Viewer.lnk" -TargetPath "$Env:ProgramFiles (x86)\ConfigMgr Console\bin\i386\CmRcViewer.exe" -Description "Microsoft Endpoint Configuration Manager Console"
			Write-Log -Message "Creating shortcut on desktop complete."
		}
		# If shortcut creation failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Creating shortcut on desktop failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		# Copy application settings to settings directory.
		# If copy failed, log results. Exit script.
		Try {
			Write-Log -Message "Copying application settings to settings directory." 
			Copy-File -Path "$ExePath" -Destination "$appSettingsDir" -Recurse
			Write-Log -Message "Copying application settings complete."
		}
		# If copy failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Copying application settings to settings directory failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		# Setup activesetup to import application settings for all users.
		# If setting up activesetup failed, exit script. Log results.
		Try {
			Write-Log -Message "Setting up activesetup."
			Set-ActiveSetup -StubExePath "$appSettingsDir\$ASExecuteable" -Description "$SubKeyName" -Key "$SubKeyName"
			Write-Log -Message "Setting up activesetup complete."
		}
		# If setting up activesetup failed, exit script. Log results. 
		Catch [System.Exception] {
			Write-Log -Message "Setting up activesetup failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		# Update (refresh) the desktop.
		Update-Desktop

		# Show install completed prompt.
		Write-Log -Message "Showing installation completed prompt."
		Show-InstallationPrompt -Title "Install Completed"  -Icon "Information" -PersistPrompt -ButtonMiddleText "OK" -Message "Your installation of $apName ($apversion) has completed.`n `n Please close any remaining prompts/windows that may have opened.`n `n Questions or issues? `n Please contact the IT Service Desk: `n ITServiceDesk@co.tuolumne.ca.us"	

	}
	ElseIf ($deploymentType -ieq 'Uninstall') {
		##*===============================================
		##* ANCHOR: PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		# Check if deployment is interactive.
		# If yes (it is interactive), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($DeployMode -eq "Interactive") {
			Show-InstallationWelcome -CloseApps "$CloseApps" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}

		##*===============================================
		##* ANCHOR: UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# For each item in the array...
		# Check if previous EXE versions of application are installed.  
		# If application is installed, uninstall previous EXE versions of application and secondary application.
		# If uninstall failed, log results. Exit script. 
		# Else, log results from check.
		Foreach ($RemoveAppNameEXE in $RemoveAppNamesEXE) {
			# Check if previous EXE versions of application are installed.  
			$RemoveAppNamesEXECheck = Get-InstalledApplication -Name "$RemoveAppNameEXE"
			If ($null -eq $RemoveAppNamesEXECheck) {
				# Uninstall previous EXE versions of application(s).      
				Try {
					# Uninstalling main application.
					Execute-Process -FilePath "$64bitAppUninstallPath" -Arguments "$64bitAppUninstallParam"
					# Uninstalling secondary application.
					Execute-Process -FilePath "$64bitAppUninstallPath2" -Arguments "$64bitAppUninstallParam2"
					# Removing desktop shortcuts.
					Remove-Item -Path "${Env:PUBLIC}\Desktop\Remote Control Viewer.lnk" -Force
				}
				# If uninstall failed, log results. Exit script.
				Catch [System.Exception] {
					Write-Log -Message "Uninstalling previous EXE versions of $RemoveAppNameEXE failed with error: $_."
					Write-Log -Message "Exiting script with error."
					Exit-Script -ExitCode 1627
				}
			}
		}

		# Check if antiquated application (SCCM Console) is installed. 
		# If it is installed, uninstall the application and delete registry information.
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "$64bitAppUninstallPath3") { 
			# Remove registry key.
			Try {
				Write-Log -Message "$64bitAppUninstallName3 registry key exists. Removing..."
				Remove-Item -Path "$AntiquatedKeyPath" -Force
				Write-Log -Message "Removing $64bitAppUninstallName3 registry key complete."
			}
			# If removal failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Removing registry key failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
			# Uninstall application.
			Try {
				Write-Log -Message "Uninstalling $64bitAppUninstallName3 Viewer."
				# Removes Tuolumne County package crumbs.
				Remove-File -Path "$Env:ProgramFiles (x86)\Tuolumne County\$64bitAppUninstallName3" -Recurse
				# Removes shortcuts.
				Remove-Item -Path "${Env:PUBLIC}\Desktop\SCCM Remote Control.lnk" -Force
				# Delete the activesetup key
				Set-ActiveSetup -Key "$SubKeyName" -PurgeActiveSetupKey
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Uninstalling $64bitAppUninstallName3 failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "$64bitAppUninstallName3 is not installed."  
		}

		# Check if previous versions of package information registry key (PIRK) exist. 
		# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
			# Remove previous versions of package information registry key (PIRK).
			Try {
				Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
				Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
		}

		# Update (refresh) the desktop.
		Update-Desktop

		##*===============================================
		##* ANCHOR: POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

	}
	ElseIf ($deploymentType -ieq 'Repair') {
		##*===============================================
		##* ANCHOR: PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* ANCHOR: REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		
		# <Perform Repair tasks here>

		##*===============================================
		##* ANCHOR: POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>

	}
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
