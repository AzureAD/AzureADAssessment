
## This is not an actual Pester test yet but we can use this snippit to quickly authenticate to module for testing.
Import-Module AzureADAssessment -ArgumentList @{
    "ai.instrumentationKey" = 'f7c43a96-9493-41e3-ad62-4320f5835ce2'
}
$MsalClientApp = New-MsalClientApplication -ClientId c62a9fcb-53bf-446e-8063-ea6e2bfcc023 -RedirectUri 'http://localhost' | Enable-MsalTokenCacheOnDisk -PassThru
Connect-AADAssessment $MsalClientApp
