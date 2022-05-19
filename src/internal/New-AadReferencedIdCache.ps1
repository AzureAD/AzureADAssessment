
function New-AadReferencedIdCache {
    [CmdletBinding()]
    #[OutputType([psobject])]
    param ()

    [PSCustomObject]@{
            user                = New-Object 'System.Collections.Generic.HashSet[guid]'
            group               = New-Object 'System.Collections.Generic.HashSet[guid]'
            application         = New-Object 'System.Collections.Generic.HashSet[guid]'
            servicePrincipal    = New-Object 'System.Collections.Generic.HashSet[guid]'
            appId               = New-Object 'System.Collections.Generic.HashSet[guid]'
            roleGroup           = New-Object 'System.Collections.Generic.HashSet[guid]'
            administrativeUnit  = New-Object 'System.Collections.Generic.HashSet[guid]'
            unknownType         = New-Object 'System.Collections.Generic.HashSet[guid]'
        }
}
