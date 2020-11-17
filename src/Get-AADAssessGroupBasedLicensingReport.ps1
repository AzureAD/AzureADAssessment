function Get-AADAssessGroupBasedLicensingReport {
    [CmdletBinding()]
    param(
    )

    #Source : https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/licensing-ps-examples

    $groupsWithLicensingErrors = Get-MsolGroup -HasLicenseErrorsOnly $true

    $groupWithLicenses = Get-MsolGroup -All | Where-Object { $_.Licenses }  
    
    foreach ($groupWithLicense in $groupWithLicenses) {
        $groupId = $groupWithLicense.ObjectId;
        $groupName = $groupWithLicense.DisplayName;
        $groupLicenses = $groupWithLicense.Licenses | Select-Object -ExpandProperty SkuPartNumber

        

        $licensingError = $groupsWithLicensingErrors | where { $_.ObjectId -eq $groupId } 

        $licensingErrorFlag = @($licensingError).Count -gt 0

    
        #aggregate results for this group
        foreach ($groupLicense in $groupLicenses) {
            New-Object Object |
            Add-Member -NotePropertyName GroupName -NotePropertyValue $groupName -PassThru |
            Add-Member -NotePropertyName GroupId -NotePropertyValue $groupId -PassThru |
            Add-Member -NotePropertyName GroupLicense -NotePropertyValue $groupLicense -PassThru |
            Add-Member -NotePropertyName LicensingErrors -NotePropertyValue $licensingErrorFlag -PassThru
        }
    }
}
