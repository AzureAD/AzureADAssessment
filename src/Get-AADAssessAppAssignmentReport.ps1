<# 
 .Synopsis
  Gets a report of all assignments to all applications

 .Description
  This functions returns a list indicating the applications and their user/groups assignments  

 .Example
  Get-AADAssessAppAssignmentReport | Export-Csv -Path ".\AppAssignments.csv" 
#>
function Get-AADAssessAppAssignmentReport {
    #Get all app assignemnts using "all users" group
    #Get all app assignments to users directly

    Confirm-ModuleAuthentication -ForceRefresh
    $servicePrincipals = Get-AzureADServicePrincipal -All $true
    Confirm-ModuleAuthentication -ForceRefresh
    $servicePrincipals | ForEach-Object { Get-AzureADServiceAppRoleAssignedTo -ObjectId $_.ObjectId -All $true }
    Confirm-ModuleAuthentication -ForceRefresh
    $servicePrincipals | ForEach-Object { Get-AzureADServiceAppRoleAssignment -ObjectId $_.ObjectId -All $true }
}
