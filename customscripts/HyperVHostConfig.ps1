<# 
Azure Nested VV Host Configuration
.File Name
 - HyperVHostConfig.ps1
 
.What calls this script?
 - This is a PowerShell DSC script called by azuredeploy.json

.What does this script do?  
 - Creates an Internal Switch in Hyper-V called "Nat Switch"
 - Creates a NAT Network on 192.168.0.0/24.  (All of your Nested VMs need static IPs on this network)
 - Add a new IP address to the Internal Network for Hyper-V attached to the NAT Switch

 There are also commented commands that you could use to automatically provision machines
 - Downloads an zipped VM to the local drive
 - Creates the Virtual Machine in Hyper-V
 - Issues a Start Command for the new Nested
#>

Configuration Main
{
	Param ( [string] $nodeName )

	Import-DscResource -ModuleName 'PSDesiredStateConfiguration', 'xHyper-V'

	node $nodeName
  	{
		# Ensures a VM with default settings
        xVMSwitch InternalSwitch
        {
            Ensure         = 'Present'
            Name           = 'Nat Switch'
            Type           = 'Internal'
        }
		
		Script ConfigureHyperV
    	{
			GetScript = 
			{
				@{Result = "ConfigureHyperV"}
			}	
		
			TestScript = 
			{
           		return $false
        	}	
		
			SetScript =
			{
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				# this is the switch that needs to be on P4 
				$NatSwitch = Get-NetAdapter -Name "vEthernet (NAT Switch)"
				New-NetIPAddress -IPAddress 192.168.0.1 -PrefixLength 24 -InterfaceIndex $NatSwitch.ifIndex
				New-NetNat -Name NestedVMNATnetwork -InternalIPInterfaceAddressPrefix 192.168.0.0/24 -Verbose
				
				# Create the rest of the switches 
				New-VMSwitch "P1Switch" -SwitchType "Private" 
				New-VMSwitch "P2Switch" -SwitchType "Private" 
				New-VMSwitch "P3Switch" -SwitchType "Private" 
				New-VMSwitch "P5Switch" -SwitchType "Private" 

				$VHDDownload = "https://d.barracuda.com/ngfirewall/8.1.0/GWAY-8.1.0-0440-HyperV-VTxxx.vhd"
				$downloadedFile = "D:\VTxxx.vhd"
				$vmFolder = "C:\VM"
				(New-Object System.Net.WebClient).DownloadFile($VHDDownload, $downloadedFile)


				New-VM -Name CGWAN `
					   -MemoryStartupBytes 2GB `
					   -BootDevice VHD `
					   -VHDPath 'D:\VTxxx.vhd' `
                      -Path 'C:\VM\' `
					   -Generation 1 `
#				       -Switch "NAT Switch"
					   -Switch "P1Switch"
					   
				# Add network interfaces 
				# note the order of the interfaces (they are jumbled)
				Add-VMNetworkAdapter -Name "P2" -VMName CGWAN -SwitchName "NAT Switch"
				Add-VMNetworkAdapter -Name "P3" -VMName CGWAN -SwitchName "P3Switch"
				Add-VMNetworkAdapter -Name "P4" -VMName CGWAN -SwitchName "P2Switch"
				Add-VMNetworkAdapter -Name "P5" -VMName CGWAN -SwitchName "P5Switch"

			    Start-VM -Name CGWAN
			}
		}	
  	}
}