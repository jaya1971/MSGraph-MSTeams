<# 
.SYNOPSIS
    1. Query all 365 groups that are MS Teams enabled and detect if new members have been added.
    2. If it's a new MS Team, then it will post a message for each member in the new MS Teams


.INPUTS
    All inputs will be handled by this script.  It will call a function in "Group_Maint.psm1" file
.OUTPUTS
    There will be a csv for each MS Teams enabled 365 group in a sub directory with the scripts

.NOTES
    Author:         Alex Jaya
    Creation Date:  11/15/2021
    Modified Date:  11/21/2021
#>
Import-Module '.\Group_Maint.psm1' -Force
Import-Module -Name ActiveDirectory
Import-Module ExchangeOnlineManagement
Import-Module MicrosoftTeams

$GroupPath = 'C:\Temp\Collab'

#Connect to various modules-------------------------------------------------------------------------------------------------------------------
#grabbing encrypted pw
[Byte[]] $key = (1..32)
$pass = get-content ".\pswd.txt" | ConvertTo-SecureString -Key $key
$Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "UserUPN@domain.com", $pass
Login-AzAccount -Credential $Cred
Connect-MicrosoftTeams -Credential $cred
Connect-ExchangeOnline -CertificateThumbPrint "Thumbprint" -AppID "EXO_APPID" -Organization "ORG.onmicrosoft.com"

#Connect to MS Graph--------------------------------------------------------------------------------------------------------------------------
$365secret = Get-AzureKeyVaultSecret -VaultName "kv" -Name "365AdminUser"
$EXOsecret = Get-AzureKeyVaultSecret -VaultName "kv" -Name "EXOApp"
$clientID = "EXO_APPID"
$tenantName = "ORG.onmicrosoft.com"
$ClientSecret = $EXOsecret
$Username = "365AdminUserUPN@ORG.onmicrosoft.com"
$Password = $365secret
$resource = "https://graph.microsoft.com"


$ReqTokenBody = @{
    Grant_Type    = "Password"
    client_Id     = $clientID
    Client_Secret = $clientSecret
    Username      = $Username
    Password      = $Password
    Resource      = $resource
    Scope      = "user.read%20openid%20profile%20offline_access" 
} 

$TokenResponse = Invoke-RestMethod "https://login.microsoftonline.com/common/oauth2/token" -Method POST -ContentType "application/x-www-form-urlencoded" -Body $ReqTokenBody
$token = $TokenResponse.access_token
$headers = @{
    "Authorization" = "Bearer $($tokenResponse.access_token)"
    "Content-type"  = "application/json"
}
Logout-AzAccount
[array]$TeamsGroups = Get-UnifiedGroup -Filter {ResourceProvisioningOptions -eq "Team"} -ResultSize Unlimited | Select-Object ExternalDirectoryObjectId, DisplayName

foreach($Team in $TeamsGroups){
    $TeamID = $team.ExternalDirectoryObjectId
    $TeamName = $Team.DisplayName
    $TeamPath = "$GroupPath\$TeamName"
    $TeamNamePath = Test-Path "$TeamPath.csv" -PathType Leaf
    $groupSID = get-adgroup -Filter {displayName -eq $TeamName} | Select-Object SID
    $TeamSID = $groupSID.SID.ToString()
   
    if(!$TeamNamePath){
        try{
            Write-Output "samaccountname" | out-file "$TeamPath.csv" -Encoding UTF8

        }Catch{}
    }
    
    try{
        Add-TeamUser -User $UserName -GroupId $TeamID
    }catch{}
    Start-Sleep -Seconds 5

    #Call function from Group_Maint.psm1
    $NewTeamMember = Get-NewTeamMember -ThisTeamSID $TeamSID -ThisGroupName $TeamName

    $genChannel = Get-TeamChannel -GroupId $TeamID | Where-Object{$_.DisplayName -eq 'General'} | Select-Object DisplayName,Id
    $GeneralID = $genChannel.Id
    $GeneralName = $genChannel.DisplayName
    $URLchatmessage="https://graph.microsoft.com/v1.0/teams/$TeamID/channels/$GeneralID/messages"
    if($NewTeamMember){
        foreach($member in $NewTeamMember){

        $BodyJsonTeam = @"
            
                        {
                            "body": {
                                "contentType": "html",
                                "content":  "Hello $member,<br/><br/>Welcome to the $TeamName Team!"
                            }
                        }
                        
"@
        Invoke-RestMethod -Method Post -Uri $URLchatmessage -Body $BodyJsonTeam -Headers $headers

        }
    }
    try{
    Remove-TeamUser -User $UserName -GroupId $TeamID -ErrorAction SilentlyContinue
    }catch{}
}

Disconnect-MicrosoftTeams
Get-PSSession | Remove-PSSession