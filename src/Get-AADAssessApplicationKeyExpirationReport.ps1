<# 
 .Synopsis
  Provides a report to show all the keys expiration date accross application and service principals 

 .Description
  Provides a report to show all the keys expiration date accross application and service principals
  
 .Example
  Connect-AzureAD
  Get-AADAssessApplicationKeyExpirationReport
  
#>
Function Get-AADAssessApplicationKeyExpirationReport {
    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        Confirm-ModuleAuthentication -ForceRefresh
        $apps = Get-AzureADApplication -All $true

        foreach ($app in $apps) {
            $appObjectId = $app.ObjectId
            $appName = $app.DisplayName
            
            Confirm-ModuleAuthentication
            $appKeys = Get-AzureADApplicationKeyCredential -ObjectId $appObjectId

            foreach ($appKey in $appKeys) {        
                $result = New-Object PSObject
                $result | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $appName
                $result | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Application"
                $result | Add-Member -MemberType NoteProperty -Name "KeyType" -Value $appKey.Type
                $result | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $appKey.StartDate
                $result | Add-Member -MemberType NoteProperty -Name "End Date" -Value $appKey.EndDate
                $result | Add-Member -MemberType NoteProperty -Name "Usage" -Value $appKey.Usage
                Write-Output $result
            }

            Confirm-ModuleAuthentication
            $appKeys = Get-AzureADApplicationPasswordCredential -ObjectId $appObjectId
            
            foreach ($appKey in $app.PasswordCredentials) {        
                $result = New-Object PSObject
                $result | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $appName
                $result | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Application"
                $result | Add-Member -MemberType NoteProperty -Name "KeyType" -Value "Password"
                $result | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $appKey.StartDate
                $result | Add-Member -MemberType NoteProperty -Name "End Date" -Value $appKey.EndDate
                Write-Output $result
            }
        }

        Confirm-ModuleAuthentication -ForceRefresh
        $servicePrincipals = Get-AzureADServicePrincipal -All $true

        foreach ($sp in $servicePrincipals) {
            $spName = $sp.DisplayName
            $spObjectId = $sp.ObjectId

            Confirm-ModuleAuthentication
            $spKeys = Get-AzureADServicePrincipalKeyCredential -ObjectId $spObjectId        

            foreach ($spKey in $spKeys) {
                $result = New-Object PSObject
                $result | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $spName
                $result | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Service Principal"
                $result | Add-Member -MemberType NoteProperty -Name "KeyType" -Value $spKey.Type
                $result | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $spKey.StartDate
                $result | Add-Member -MemberType NoteProperty -Name "End Date" -Value $spKey.EndDate
                $result | Add-Member -MemberType NoteProperty -Name "Usage" -Value $spKey.Usage
                Write-Output $result
            }    
            
            Confirm-ModuleAuthentication
            $spKeys = Get-AzureADServicePrincipalPasswordCredential -ObjectId $spObjectId    

            
            foreach ($spKey in $spKeys) {
                $result = New-Object PSObject
                $result | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $spName
                $result | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "Service Principal"
                $result | Add-Member -MemberType NoteProperty -Name "KeyType" -Value "Password"
                $result | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $spKey.StartDate
                $result | Add-Member -MemberType NoteProperty -Name "End Date" -Value $spKey.EndDate
                Write-Output $result
            }    
        }
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}
