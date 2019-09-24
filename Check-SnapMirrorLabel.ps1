#########################################################################################################################################################################
#Name: Check-SnapMirrorLabel.ps1
#Author: Riccardo Santoni
#Version: 1
#Description:
#The script is scheduled to run everyday at 07 am and verify is the backup at source Netapp was created successfully and with snapmirror-label 'Daily'
#for volumes vol_sql_db and vol_sql_logf_clone. We've noticed that sometimes the Snapshot is created succesfully by Snapmanager for SQL but without
#the snapmorror label 'Daily' associated with it, if this failes to happen the snap will not be copied over to DR Netapp failing to comply with SOX check.
#Instead of having to do the check manually, this script will check everyday if the lastest snap have the Snapmirror label correctly applied, if not it applies it and 
#schedule a Snapmirror update to copy the Snapshot to destination. Everytime the script executes will notify netops team with the result of the checks. 
#This script runs before the other script 'Get-SnapVault.ps1' is scheduled to run to notify IT Support of any SOX check failure.
#########################################################################################################################################################################

#Import NetApp PS Module
Import-Module DataONTAP

#Credentials Used to connect to the filer - must runs as DELTA\svc_script_run local user account..
$encrypted = "01000000d08c9ddf0115d1118c7a00c04fc297eb010000006eee04d255ee1048bf6fb7c46325e9c90000000002000000000003660000c0000000100000002689562df30f52a0c83336088ee075280000000004800000a00000001000000026007b0315faa3aa1003a8e682527002200000006b69a233aeef9f85ab15a0de86112795dccb260d4da28cab6b58b067d2e663cd140000003d635bc1c10207b9b13dae729a2422bc8f4861d9"
$password = ConvertTo-SecureString -string $encrypted
$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist "admin",$password


#Enter Netapp Ip management address
$NetappSourceIp = Enter_Ip
$NetappDestinationIp = Enter_Ip

#Defining Variables
$lastday = (Get-Date).AddHours(-24)
$EmailFrom = "itsupport@email.com"          #set receipient email address
$EmailTo =  "riccardo.santoni@email.com"    #set destination email address
$SMTPServer = "10.192.x.x"  
$Labelmissing = 0


# Volumes that we want to check for the correct label
$Volumes = @("vol_sql_db","vol_sql_logf_clone")    
$SnapCollection= @()

#clear count of error messages
$error.Clear() 

#Connect to Filer

Try {
    Connect-NcController -Name $NetappIp -Credential $cred -HTTPS -ErrorAction Stop
} catch {    
    Send-MailMessage -To $EmailTo -Subject "SOX Backup Check Failed" -Body "Could not connect to the Netapp <br/><br/> $error" -SmtpServer $SMTPServer -From $EmailFrom -BodyAsHtml
    break
}



#Collecting the Snapshot of the previous day for each volumes recursivelly and check if the snap exist and has the Daily label associated, if not associates it and start a snapmirror update

foreach ($Vol in $Volumes) {

$SnaptoCheck = Get-NcVol -name $Vol | Get-NcSnapshot | where {$lastday -le $_.Created}

if ($SnaptoCheck -ne $null) { 
    $NSnap = $SnaptoCheck.count
    if ($SnaptoCheck.count -ge 1) {
    $SnapShot = $SnaptoCheck[0]
    } else {$SnapShot = $SnaptoCheck}
    $SnapCollection += $SnapShot
    if (($SnapShot.SnapmirrorLabel -ne "Daily") -and ($SnapShot.Name.StartsWith("sqlsnap"))) {
        Set-NcSnapshot -Snapshot $SnapShot -Volume $Vol -Vserver SVM_SQL -SnapmirrorLabel Daily
        
        #invoke snapmirror update this need to be done connecting to DR controller
        Connect-NcController -Name $NetappDestinationIp -Credential $cred -HTTPS
        $Destination_path = Get-NcSnapmirror -SourceVolume $Vol
        
        Invoke-NcSnapmirrorUpdate -Destination $Destination_path.DestinationLocation
        
        $Body = "Snapmirror label not correctly applied for last day snap for vol $Vol. The label was applied manually and a Snapmirror Update was triggered, Snapshot: <br/>"
        $Body += $($SnapShot | ConvertTo-Html -As List -property Name, Created) + "<br/><br/>"
        $Body +="Please perform checks to verify Snapmirror trasfer will completes succesfully"
        Send-MailMessage -To $EmailTo -Subject "SOX Check: Snapmirror Label not applied" -SmtpServer $SMTPServer -From $EmailFrom -body $Body -BodyAsHtm
        Connect-NcController -Name $NetappDestinationIp -Credential $cred -HTTPS
        $Labelmissing++
     }     
} else 

{Send-MailMessage -To $EmailTo -Subject "Backup missing for vol_sql_db on $lastday" -SmtpServer $SMTPServer -From $EmailFrom -body "Volume $Vol is missing latest snapshot on source filer on $lastday" -BodyAsHtm}

}


#If all check completed succesfully send an email inform that no issue where found, if script completed with error send an email informing about some erros were returned in the script execution

$Errornum = $error.Count

if(($Labelmissing -eq 0) -and ($Errornum -eq 0)){
    $Body = "SOX Backup pre-check script completed succesfully with no errors for volumes<br/><br/>"
    foreach ($Snapshot in $SnapCollection) {       
        
        $Body += $($SnapShot | ConvertTo-Html -As List -property Volume, Name, Created) + "<br/><br/>"
            
    }
    Send-MailMessage -To $EmailTo -Subject "SOX Backup Check" -Body $Body -SmtpServer $SMTPServer -From $EmailFrom -BodyAsHtml
    } 
    Elseif ($Errornum -gt 0)      
    {
        $Body = "The script Check-SnapMirrorLabel.ps1 completed with errors N $Errornum<br/><br/>"
        $Body += "ERROR(s)<br/>"
        $Body += $error
        Send-MailMessage -To $EmailTo -Subject "SOX Backup Check Script completed with errors" -Body $Body -SmtpServer $SMTPServer -From $EmailFrom -BodyAsHtml
    }
