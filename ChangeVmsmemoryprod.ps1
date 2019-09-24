##Created by Riccardo Santoni - Task Change VM memory
##This script changes the memory for VMs specified, powering them off and then restarting them after the change. 

##VMs name - List the VMs to change the memory to the desired value
$Vms2change = @("VMNAME1","VMNAME2","VMNAME3","VMNAME4")
##Memory GB value - Set this with the desired amount of GB 
$MemoryGb = 6
##Email Settings
$emailServer = "10.192.x.x"
$sender = "powershell@email.com"
$recipients = "riccardo.santoni@email.com"
##Load VMware PS plugin
Add-PSSnapin VMware.VimAutomation.Core
##Connect to vCenter - Password encrypted with ConvertTo-SecureString
$encrypted = "01000000d082340115d1118c7a00c04fc297eb078560000ed0f42723dfd4646a0542a897bfcbef3055660000020007774323660000c00000343003200005b7a203232u3iphioh4uoi1h432wrrec220000000a4a35de5cd5ae3c9c9d8cbc6746a533111736294d15fa39cefe88deaf90a5e5a14000000f583404be4a91a34ecfce29880bc8e5f008129fb"
$user = "domain\user"
$password = ConvertTo-SecureString -string $encrypted

connect-viserver -server vcenterServer -User $user -Password $password
foreach ($VM2change in $Vms2change) 
{
    ###########################Start- Custom Task #########################
    $beforechange = (GET-VM -Name $VM2change|FT -auto MemoryGB|out-string)
    ##Stop VM
    GET-VM -Name $VM2change| Shutdown-VMGuest -Confirm:$False
    start-sleep -s 180
    ##Change Memory
    GET-VM -Name $VM2change| set-vm -MemoryGB $MemoryGb -Confirm:$False
    ##Start VM
    GET-VM -Name $VM2change| Start-VM -Confirm:$False
    $afterchange = (GET-VM -Name $VM2change|FT -auto MemoryGB|Out-String)
    ##ping VM
    start-sleep -s 120
    $isalive= (Test-Connection -ComputerName $VM2change -count 1|Out-String)
    ###########################End- Custom task #########################
    ##Compose eMail and send
    $body = @" 
    Memory Before,$beforechange.
    Memory After, $afterchange.
    Is VM up??, $isalive
"@
    send-mailmessage -from $sender -to $recipients -subject "VM Memory Change $VM2change" -Bodyashtml "$body" -smtpserver $EmailServer
}
