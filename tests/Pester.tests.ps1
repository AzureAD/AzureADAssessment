
## This is not an actual Pester test yet but we can use this snippit to quickly authenticate to module for testing.
$MsalClientApp = New-MsalClientApplication -ClientId c62a9fcb-53bf-446e-8063-ea6e2bfcc023 -TenantId jasoth.onmicrosoft.com -RedirectUri 'http://localhost' | Enable-MsalTokenCacheOnDisk -PassThru
Connect-AADAssessment $MsalClientApp
