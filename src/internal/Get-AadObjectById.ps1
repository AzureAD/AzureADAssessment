
function Get-AadObjectById {
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Id')]
        [object] $ObjectId,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('servicePrincipal', 'user', 'group')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $false)]
        [object] $LookupCache
    )

    process {
        if ($LookupCache -and $LookupCache.$ObjectType.ContainsKey($ObjectId)) {
            return $($LookupCache.$ObjectType)[$ObjectId]
        }
        else {
            return Get-MsGraphResults 'directoryObjects' -UniqueId $ObjectId
        }
    }
}
