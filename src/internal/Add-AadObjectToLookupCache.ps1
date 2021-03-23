
function Add-AadObjectToLookupCache {
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObject,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('servicePrincipal', 'user', 'group')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $true)]
        [object] $LookupCache,
        #
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    process {
        if (!$LookupCache.$ObjectType.ContainsKey($InputObject.id)) { $LookupCache.$ObjectType.Add($InputObject.id, $InputObject) }
        if ($PassThru) { return $InputObject }
    }
}
