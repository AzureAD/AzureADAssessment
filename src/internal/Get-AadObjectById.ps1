
function Get-AadObjectById {
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Id')]
        [string] $ObjectId,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('servicePrincipal', 'application', 'user', 'group', 'administrativeUnits')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $false)]
        [Alias('Select')]
        [string[]] $Properties,
        #
        [Parameter(Mandatory = $false)]
        [psobject] $LookupCache,
        #
        [Parameter(Mandatory = $false)]
        [switch] $UseLookupCacheOnly
    )

    process {
        if ($LookupCache -and $LookupCache.$ObjectType.ContainsKey($ObjectId)) {
            return $($LookupCache.$ObjectType)[$ObjectId]
        }
        elseif (!$UseLookupCacheOnly) {
            $Object = Get-MsGraphResults 'directoryObjects' -UniqueId $ObjectId -DisableUniqueIdDeduplication -DisableGetByIdsBatching -Select $Properties
            if ($LookupCache) { Add-AadObjectToLookupCache $Object -Type $ObjectType -LookupCache $LookupCache }
            return $Object
        }
    }
}
