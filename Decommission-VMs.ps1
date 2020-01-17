######################################################################################################################################
### Name:        Decommission-VMs.ps1                                                                                               ###
### Author:      Riccardo Santoni                                                                                                   ###
### Version:     2.0                                                                                                                ###
### Description: This script will pull in a list of servers from a text file that need to be decommissioned and remove them from    ###
###              VMware, SolarWinds, Active Directory, DNS Record,  Windows Update Services and System Center Configuration Manager.###
### Changes:     Added DNS Session                                                                                                  ###
######################################################################################################################################
# Ask for credentials #
$Cred = Get-Credential

# Get Servers to Decommission #
$Servers = Get-Content C:\PATH\Servers_list.txt
$Date = Get-Date -Format dd-MM-yyyy

############################################################# VMware Section #############################################################
# Load PowerCli #
# Connect to vCenter Server #
$vCenterServer = "Server.domain.com" #Enter here the vCenter server name
Connect-ViServer $vCenterServer -Credential $Cred
# Delete VM's from vCenter #
ForEach ($Server in $Servers){
    if((Get-VM $Server).PowerState -eq "PoweredOn"){
        Stop-VM -VM $Server -Confirm:$false
        While((Get-VM $Server).PowerState -eq "PoweredOn"){
            Write-Host -ForegroundColor Green "waiting for VM to shutdown"
        }
    }
    Get-VM $Server | Remove-VM -DeletePermanently -Confirm:$false
}
########################################################### SolarWinds Section ###########################################################

# Connect to the Solarwinds Server #
$SolrwindServer = "Server.domain.com" #Enter here the Solarwinds Server name
$swis = Connect-Swis -Credential $Cred -Hostname $SolrwindServer
# Get the URI of each Machine #
$uri = foreach($vm in $Servers){
    Get-SwisData $swis 'SELECT NodeID, Caption,uri FROM Orion.Nodes' | Where-Object caption -like $vm
}
$uri = foreach($vm in $Servers){
    Get-SwisData $swis 'SELECT NodeID, Caption,uri FROM Orion.Nodes' | Where-Object caption -like $vm
}
# Delete each node from SolarWinds using the retreived URI #
foreach($i in $uri){ 
    Remove-SwisObject $swis -Uri $i.uri
}
########################################################### Active Directory Section #####################################################

# Check for each VM in AD, Delete if there #
foreach ($Server in $Servers){
        if (@(Get-ADComputer $server -ErrorAction SilentlyContinue).Count) {
            Write-Host "$Server is in AD, Delete"
            Get-ADComputer $Server | Remove-ADComputer -Confirm:$false -ErrorAction SilentlyContinue  
        }
        else {
            Write-Host "$Server isn't in AD" 
        }
}

########################################################### DNS Section #####################################################

#enter domain zone here
$domainZone = "domainzone.com"
#enter one domain controller to connect here
$dc = "DCName"

foreach ($Server in $Servers){
    $DnsRecord = Get-DnsServerResourceRecord -zonename $domainZone -ComputerName $dc -Name $Server
    if ($DnsRecord -ne $null){
        Remove-DnsServerResourceRecord -InputObject $DnsRecord -zonename $domainZone -ComputerName $dc
        Write-Host "$Server - DNS Deleted" 
        
    } else {
        Write-Host "$Server - No DNS Record found" 
    }
}
########################################################### WSUS Section #################################################################
# Enter WSUS Server name here#
$WsusServer = "WsusServerName"

[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WsusServer,$False,8530)
# Delete VM from Desktop WSUS Database #
ForEach($Server in $Servers){
    try{
        $Client = $wsus.GetComputerTargetByName($Server)
        $Client[0].Delete()
    } catch { $Server + "  - Wsus Record not found"}
}

################################################################ SCCM Section ###########################################################
# Set Site Server and Site Name #
$SCCMServer = "SCCMServerName" 
$sitename = "Site"
# Delete VM from SCCM #
ForEach ($Server in $Servers){
    $comp = gwmi -cn $SCCMServer -namespace root\sms\site_$($sitename) -class sms_r_system -filter "Name='$($Server)'"
    if ($comp -ne $null){
        # Output 
        Write-Host "$Server with resourceID $($comp.ResourceID) will be deleted" 
        # Delete the computer account 
        $comp.delete()
    } else { Write-Host "SCCM Record for Server " $Server " not found"}
}


# Configure Email to be sent as report of operation #
$VMNames = $Servers | Format-List | Out-String
$body ="
To Administrator,
The following VM's have been deleted from VMWare, AD, SolarWinds, DNS, WSUS and SCCM:

$VMNames
    
PLEASE DO NOT REPLY TO THIS EMAIL.
   
Regards"
#Enter SMTP Server here to send email
$SMTPServer = ""
# Send E-Mail to Administrators confirming the VM's that have been decommissioned, replace source and destination and emails here#
Send-MailMessage -From Decommission@email.com -To Administrator@email -Subject "VM's deleted on $Date" -Body $body -SmtpServer $SMTPServer 
# END #
Exit
