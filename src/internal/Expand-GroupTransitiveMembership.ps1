<#
.SYNOPSIS
    Expand and return transitive group membership based on group members data in cache.
.EXAMPLE
    PS C:\>Expand-GroupTransitiveMembership 00000000-0000-0000-0000-000000000000 -LookupCache $LookupCache
    Expand transitive group membership of group "00000000-0000-0000-0000-000000000000". Ensure all nested groups are in $LookupCache.
.INPUTS
    System.Object
#>
function Expand-GroupTransitiveMembership {
    [CmdletBinding()]
    param (
        # GroupId within Cache for which to calculate transitive member list.
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Collections.Generic.Stack[guid]] $GroupId,
        # Lookup Cache populated with all nested group objects necessary to calculate transitive members.
        [Parameter(Mandatory = $true)]
        [psobject] $LookupCache
    )

    $Group = Get-AadObjectById $GroupId.Peek() -LookupCache $LookupCache -ObjectType group -UseLookupCacheOnly
    if ($Group.psobject.Properties.Name.Contains('transitiveMembers')) { $Group.transitiveMembers }
    else {
        $transitiveMembers = New-Object 'System.Collections.Generic.Dictionary[guid,psobject]'
        if ($Group.psobject.Properties.Name.Contains('members')) {
            foreach ($member in $Group.members) {
                if (!$transitiveMembers.ContainsKey($member.id)) {
                    $transitiveMembers.Add($member.id, $member)
                    $member
                }
                if ($member.'@odata.type' -eq '#microsoft.graph.group') {
                    if (!$GroupId.Contains($member.id)) {
                        $GroupId.Push($member.id)
                        $transitiveMembersNested = Expand-GroupTransitiveMembership $GroupId -LookupCache $LookupCache
                        foreach ($memberNested in $transitiveMembersNested) {
                            if (!$transitiveMembers.ContainsKey($memberNested.id)) {
                                $transitiveMembers.Add($memberNested.id, $memberNested)
                                $memberNested
                            }
                        }
                    }
                }
            }
        }
        if ($GroupId.Count -eq 1) { $Group | Add-Member -Name transitiveMembers -MemberType NoteProperty -Value ([System.Collections.ArrayList]$transitiveMembers.Values) -ErrorAction Ignore }
    }
    [void]$GroupId.Pop()
}
