# -----------------------------------------------------------------------------------------------
# Component: Sophos Central Deployment for Windows
# Author: Stephen Weber
# Platform: NinjaRMM
# Purpose: Using the new Sophos Thin installer, 
#          perform default install of Sophos Central using the defined parameters
# Version 1.0
# -----------------------------------------------------------------------------------------------

#Setup Customer Parameters

param(
	[Parameter(Mandatory=$true)]
	[string] $Name,
	[Alias("c")]
	[string] $CustomerToken,
	[ValidateSet("CIXE", "CIXA", "CIXAMTR", "All", "Encrypt")]
	[Alias("p")]
	[string] $ProductSelection
)

# Define Functions

function Get-SophosInstalled {

$Global:installed = (gp HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -contains "Sophos Endpoint Agent"
$Global:mcsclient = Get-Service -name "Sophos MCS Client" -ea SilentlyContinue
$Global:mcsagent = Get-Service -name "Sophos MCS Agent" -ea SilentlyContinue
}

# Sophos Central Installation
Start-Transcript c:\temp\SophosCentralInstallLog.txt
Write-Host "Starting the Sophos Central Installation based on the variables defined in the site"
Write-Host ""
Write-Host "Checking to see if Sophos is Already Installed"

Get-SophosInstalled
if ($installed -eq "True") {
	Write-Host "--Sophos Central Endpoint Agent Installed"
	if ($mcsclient.Status -eq "Running"){	
	Write-Host "--Sophos MCS Client is Running"
	Exit 0
	}
}
else {
	Write-Host "--Sophos Central is Not Installed"
	Write-Host "Sophos MCS Client is Not Running"
	}

# Check for the Site Variables
Write-Host ""
Write-Host "Checking the Variables"

if (!$CustomerToken)
	{Write-Host "--Customer Token Not Set or Missing"
    Stop-Transcript
	Exit 1}
else
	{Write-Host "--CustomerToken = "$CustomerToken""}

#Pull Device OS Info for Workstation or Server Detection

$osInfo = Get-WmiObject -Class Win32_OperatingSystem

# Sophos Workstation Product Selection
if ($osInfo.ProductType -eq '1') {
	if (!$ProductSelection) {
		Write-Host "--Product Not Set or Missing"
		Stop-Transcript
		Exit 1
	}  
		elseif ($ProductSelection -eq 'CIXE') {
		$Products = "antivirus,intercept"
	}  
		elseif ($ProductSelection -eq 'CIXA') {
		$Products = "antivirus,intercept"
	}
		elseif ($ProductSelection -eq 'CIXAXDR') {
		$Products = "antivirus,intercept,xdr"
	}
		elseif ($ProductSelection -eq 'CIXAMTR') {
		$Products = "antivirus,intercept,mdr"
	}
		elseif ($ProductSelection -eq 'ALL') {
		$Products = "all"
	}
		elseif ($ProductSelection -eq 'Encrypt') {
		$Products = "DeviceEncryption"
	}
}
# Sophos Server Product Selection
else {
	if (!$ProductSelection) {
		Write-Host "--Product Not Set or Missing"
		Stop-Transcript
		Exit 1
	}  
		elseif ($ProductSelection -eq 'CIXE') {
		$Products = "antivirus,intercept"
	}  
		elseif ($ProductSelection -eq 'CIXA') {
		$Products = "antivirus,intercept"
	}
		elseif ($ProductSelection -eq 'CIXAXDR') {
		$Products = "antivirus,intercept,xdr"
	}
		elseif ($ProductSelection -eq 'CIXAMTR') {
		$Products = "antivirus,intercept,mdr"
	}
		elseif ($ProductSelection -eq 'ALL') {
		$Products = "all"
	}
}

# Sophos parameters are defined from the site specific variables
$arguments = "--products=""" + $Products
$arguments = $arguments + """ --quiet"

# Check to see if a previous SophosSetup Process is running
Write-Host ""
Write-Host "Checking to see if SophosSetup.exe is already running"
if ((get-process "sophossetup" -ea SilentlyContinue) -eq $Null){
        Write-Host "--SophosSetup Not Running" 
}
else {
    Write-Host "Sophos Currently Running, Will Kill the Process before Continuing"
    Stop-Process -processname "sophossetup"
 }

#Force PowerShell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Check for Existing SophosSetup Installer
if ((Test-Path c:\temp\SophosSetup.exe) -eq "True"){
		Write-Host "--Removing the existing SophosSetup Installer"
		Remove-Item -path c:\temp\SophosSetup.exe
}

# Download of the Central Customer Installer
Write-Host ""
Write-Host "Downloading Sophos Central Installer"
Invoke-WebRequest -Uri "https://central.sophos.com/api/partners/download/windows/v1/$CustomerToken/SophosSetup.exe" -OutFile c:\temp\SophosSetup.exe
if ((Test-Path c:\temp\SophosSetup.exe) -eq "True"){
		Write-Host "--Sophos Setup Installer Downloaded Successfully"
}
else {
	Write-Host "--Sophos Central Installer Did Not Download - Please check Firewall or Web Filter"
	Stop-Transcript
	Exit 1
}

# This Section starts the installer using the arguments defined above
Write-Host ""
Write-Host "Installing Sophos Central Endpoint:"
Write-Host ""
Write-Host "SophosSetup.exe "$arguments""
Write-Host ""

start-process c:\temp\SophosSetup.exe $arguments

$timeout = new-timespan -Minutes 30
$install = [diagnostics.stopwatch]::StartNew()
while ($install.elapsed -lt $timeout){
    if ((Get-Service "Sophos MCS Client" -ea SilentlyContinue)){
	Write-Host "Sophos MCS Client Found - Breaking the Loop"
	Break
	}
    start-sleep -seconds 60
}
Write-Host ""
Write-Host "Sophos Setup Completed"

# Verify that Sophos Central Endpoint Agent Installed
Write-Host ""
Write-Host "Verifying that Sophos Central Endpoint installed and is Running"

Get-SophosInstalled
if ($installed -eq "True") {
	Write-Host "--Sophos Central Endpoint Agent Installed Successfully"
	if ($mcsclient.Status -eq "Running"){
	Write-Host "--Sophos MCS Client is Running"
		if ($mcsagent.Status -eq "Running"){
		Write-Host ""
		Write-Host "--Sophos MCS Agent is Running"
		Write-Host ""
		Write-Host "Sophos Central Agent is Installed and Running"
		Write-Host ""
		Stop-Transcript
		Exit 0
		}
	}
}
else {
	Write-Host "--Sophos Central Install Failed"
	Write-Host ""
	Write-Host "Please check the Sophos Central Install Logs for more details"
	Write-Host ""
	Write-Host "Log Location - <system>\programdata\Sophos\Cloudinstaller\Logs\"
	Stop-Transcript
	Exit 1
	}