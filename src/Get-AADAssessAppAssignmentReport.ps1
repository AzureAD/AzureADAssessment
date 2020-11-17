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

    $servicePrincipals = Get-AzureADServicePrincipal -All $true
    $servicePrincipals | ForEach-Object { Get-AzureADServiceAppRoleAssignedTo -ObjectId $_.ObjectId -All $true }
    $servicePrincipals | ForEach-Object { Get-AzureADServiceAppRoleAssignment -ObjectId $_.ObjectId -All $true }
}
