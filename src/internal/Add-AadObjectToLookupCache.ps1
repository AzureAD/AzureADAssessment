
function Add-AadObjectToLookupCache {
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('servicePrincipal', 'user', 'group')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $true)]
        [psobject] $LookupCache,
        #
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    process {
        if (!$LookupCache.$ObjectType.ContainsKey($InputObject.id)) {
            #if ($ObjectType -eq 'servicePrincipal') { $LookupCache.servicePrincipalAppId.Add($InputObject.appId, $InputObject) }
            $LookupCache.$ObjectType.Add($InputObject.id, $InputObject)
        }
        if ($PassThru) { return $InputObject }
    }
}
