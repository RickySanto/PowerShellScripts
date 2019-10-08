######################################################################################################################################
### Name:        Decommission-VMs.ps1                                                                                               ###
### Author:      Riccardo Santoni                                                                                                   ###                                                                                                            ###
### Description: This script takes a list of servers from a text file and verify whether the server has 2 registry key set as per   ###
###              vulnerability remediation requirements. If not the registry key will be changed accordingly.                       ###
###              The 2 vulneabilities in question are (ADV180002 Spectre/Meltdown) and (ADV180012 Spectre/Meltdown Variant 4)       ###                                                               ###                                                                                           ###
######################################################################################################################################

#Scipt will ask for credentials to run
$Cred = Get-Credential
#Get list of VMs from a text file
$Servers = Get-Content "C:\PATH\ServersRegistry.txt"


foreach($Server in $Servers) {
    
    $session = New-PSSession $Server -Credential $Cred 
    
    #Check for first registry key
    $resultFeatureSettingsOverrideReg = Invoke-Command -session $session -ArgumentList $Server -ScriptBlock  {
    
        $Server = $args[0]
        $FeatureSettingsOverrideReg = Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverride
        Write-Host $Server "FeatureSettingsOverrideReg" $FeatureSettingsOverrideReg.FeatureSettingsOverride

        if ($FeatureSettingsOverrideReg.FeatureSettingsOverride -ne 8) {
            reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 8 /f

            $newFeatureSettingsOverrideReg = Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverride     
        
            $result = "Registry Key FeatureSettingsOverride for Server `t`t" + $Server + " `t changed to " + $newFeatureSettingsOverrideReg.FeatureSettingsOverride
            Write-Host $result
            return $result
        
        } else {
            $result =  "FeatureSettingsOverride for `t`t" + $Server + " `t no change"
            Write-Host = $result
            return $result
        }
    }

    #Check for second registry key
    $resultFeatureSettingsOverrideMaskReg = Invoke-Command -session $session -ArgumentList $Server -ScriptBlock  {

        $Server = $args[0]
        $FeatureSettingsOverrideMaskReg = Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverrideMask
        Write-Host $Server "FeatureSettingsOverrideMaskReg" $FeatureSettingsOverrideMaskReg.FeatureSettingsOverrideMask


        if ($FeatureSettingsOverrideMaskReg.FeatureSettingsOverrideMask -ne 3){
            reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f 
        
            $newFeatureSettingsOverrideMaskReg = Get-ItemProperty -Path "hklm:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverrideMask
        
            $result = "Registry Key FeatureSettingsOverrideMask for Server `t`t" + $Server + " `t changed to " + $newFeatureSettingsOverrideMaskReg.FeatureSettingsOverrideMask
            Write-Host $result
            return $result
       
        } else {
            $result = "FeatureSettingsOverrideMask for `t'" + $Server + " `t no change"
            Write-Host $result
            return $result 
        }
    }

    #produce output of the two action on the txt file registryChangeResult.txt
    Add-Content "C:\PATH\registryChangeResult.txt" $resultFeatureSettingsOverrideReg
    Add-Content "C:\PATH\registryChangeResult.txt" $resultFeatureSettingsOverrideMaskReg
    Get-PSSession | Remove-PSSession 

}