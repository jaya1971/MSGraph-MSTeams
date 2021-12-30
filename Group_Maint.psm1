<# 
.SYNOPSIS
    Script to monitor the addition and removal of members of a specific group and take action.
    Schedule this script on a task scheduler server to run in incremental time

.INPUTS
    Modify the $Group and $GroupPath variable 
.OUTPUTS


.NOTES
    Author:         Alex Jaya
    Creation Date:  08/06/2021
    Modified Date:  08/12/2021

.EXAMPLE

#>

function global:Get-NewTeamMember{
    Param(
        [Parameter()] [ValidateNotNullOrEmpty()][string] $ThisTeamSID=$(throw "Group SID and DisplayName are required - Example: GetNewTeamMember -ThisTeamSID 'GROUPSID' -ThisGroupName 'GROUPNAME'"),
        [Parameter()] [ValidateNotNullOrEmpty()][string] $ThisGroupName=$(throw "Group SID and DisplayName are required - Example: GetNewTeamMember -ThisTeamSID 'GROUPSID' -ThisGroupName 'GROUPNAME'")
        )
    
    Process{
        $GroupPath = 'C:\Temp\Collab'
        $Previous ="$GroupPath\$ThisGroupName.csv"
        try{
        $currentMembers = Get-AdGroupMember $ThisTeamSID -ErrorAction Stop | Select-Object samaccountname
        }catch{}
        $previousMembers = import-csv -Path $Previous | Select-Object samaccountname

        #Detect deleted members
        $RemoveUsers = $previousMembers | Where-Object -FilterScript{$_.samaccountname -notin $currentMembers.samaccountname} | Select-Object -ExpandProperty samaccountname

        #Detect new members
        $AddUsers = $currentMembers | Where-Object -FilterScript{$_.samaccountname -notin $previousMembers.samaccountname} | Select-Object -ExpandProperty samaccountname

        try{
        Get-AdGroupMember -Identity $ThisTeamSID | Select-Object samaccountname | Export-Csv -Path $Previous -Encoding UTF8 -NoTypeInformation
        }Catch{}

        #-Take Action Here-------

        #Action on New Users
        if($AddUsers){
            $DisplayName = foreach($user in $AddUsers){

                Get-ADUser -Identity $user | Select-Object -ExpandProperty Name
            }
            return $DisplayName
        }


        #Action on Removed Users
        if($RemoveUsers){
            foreach($user in $RemoveUsers){
                #Action
            }
        }
    }

}