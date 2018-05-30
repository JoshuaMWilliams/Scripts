<#
.SYNOPSIS
    Retrieves machines that specified user is the TopConsoleUser for
.DESCRIPTION
    Uses SCCM Database to determine computer that the specified user is the "TopConsoleUser" for.
.PARAMETER Username 
    The SAMAccountName you would like to search
.PARAMETER SiteServer
    The site server for SCCM
.NOTES
  Version:        1.0
  Author:         Joshua M. Williams (JoshuaMWilliams@ProtonMail.com)
  Creation Date:  5/29/18
#>

Function Get-TopConsoleUser{
    param(
	[parameter(Mandatory = $True, ValueFromPipeline = $True)]
	$Username,
        [parameter(Mandatory = $True)]
        $SiteServer,
	[parameter(Mandatory = $True)]
	[ValidateLength(3,3)]
	$SiteCode 
    )
    $SamAccountName = (Get-ADUser $Username).SamAccountName
    $query = "
        Select  *  FROM SMS_R_SYSTEM
            INNER JOIN SMS_G_System_SYSTEM_CONSOLE_USAGE
                ON SMS_R_SYSTEM.ResourceID = SMS_G_System_SYSTEM_CONSOLE_USAGE.ResourceID
            WHERE
                SMS_G_System_SYSTEM_CONSOLE_USAGE.TopConsoleUser LIKE '%$SamAccountName'
    "
    (Get-WmiObject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Query $query).SMS_R_SYSTEM.Name
}
