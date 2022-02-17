<# 
DESCRIPTION
This script create a new mailbox on the smallest mailbox database that matches a filter and set other attributes
USAGE
PS \\LAITCASM\Tools\banner.html> .\Create-ExchangeMailbox.ps1 -NewUserID "user" -GivenName "user" -Surname “userSUrname” -SourceUserID “_UserTemplate” -CustomAttrib “user team”
#>

 
param(
    [Parameter(Mandatory = $true)][String]$NewUserID,
    [String]$SourceUserID = $Null,
    [String]$DisplayName = $Null,
    [String]$GivenName = $Null,
    [String]$Surname = $Null,
    [String]$CustomAttrib = $Null,
    [String]$SendWelcome = $True)
 
$DBFilter = "Primary*" # Limit databases to only those that start with "Primary"
$RetentionPolicy = "Default Archive and Retention Policy"
 
$ContiuneOnExist = $True # Option good for testing
 
$CopyAttributes = "MemberOf","Description","Company","Department","Office","Title","streetAddress","City","State","PostalCode","Country"
 
$AddToGroup = $False
$Group = 'Active Directory users'
 
$Password = "P@ssW0rD!"

 

$From = "admin@laitcasm.com"
$MsgSubject = "Welcome to the Company!"
$MsgBody = Get-Content "\\LAITCASM\Tools\banner.html" | out-string
 
Function Get-SmallestDB {
    Try {
        $MBXDbs = Get-MailboxDatabase | ? {$_.Identity -like $DBFilter } 
        $MBXDBCount = $PSSessions.Count
    }
    Catch {
        $MBXDBCount =  0
    }
     
    If (!$MBXDbs) {ExitScript "find databases with a name that matches a filter of [$DBFilter]." $False}
 
    # Loop through each of the MBXDbs
    ForEach ($MBXDB in $MBXDbs) {
        # Get current mailboxes sizes by summing the size of all mailboxes and "Deleted Items" in the database
        $TotalItemSize = Get-MailboxStatistics -Database $MBXDB | %{$_.TotalItemSize.Value.ToMB()} | Measure-Object -sum
        $TotalDeletedItemSize = Get-MailboxStatistics -Database $MBXDB.DistinguishedName | %{$_.TotalDeletedItemSize.Value.ToMB()} | Measure-Object -sum
 
         
        $TotalDBSize = $TotalItemSize.Sum + $TotalDeletedItemSize.Sum
        # Compare the sizes to find the smallest DB
        If (($TotalDBSize -lt $SmallestDBsize) -or ($SmallestDBsize -eq $null)) {
            $SmallestDBsize = $DBsize
            $SmallestDB = $MBXDB }}
    return $SmallestDB }
 
Function ExitScript ($ErrorText,$ShowFullError) {
    Write-Host "`nAn error occurred when trying to $ErrorText, exiting script`r`n"  -ForegroundColor Red
    If ($ShowFullError) {
        Write-Host "Error: " $error[0] -ForegroundColor Red
    }
    Break }
 
Function CopyUser ($SourceUser,$NewUser,$GivenName,$Surname,$DisplayName) {
 
    Import-module ActiveDirectory
 
    If ($DisplayName -eq "") {
        If ($GivenName -eq "" -And $SurName -eq "") {
            $DisplayName = $NewUserID
        }
        Else {
            $DisplayName = "$GivenName $SurName" # Set DisplayName if it's blank
        }
        $DisplayName = $DisplayName.Trim() # Removes the leading & trailing spaces
    }
 
    Write-Host "New user account will be based on user: [$SourceUser]" -ForegroundColor Green
    Try {$UserTemp = Get-User $SourceUser -ErrorAction SilentlyContinue}
    Catch {ExitScript "run [Get-User $SourceUser], confirm user ID exist" $False}
 
    $UserTemp = $Null
    $UserTemp = Get-User $NewUser -ErrorAction SilentlyContinue
    If ($UserTemp -and !$ContiuneOnExist) {
        Write-Host "User ID $NewUser already exist, script exiting." -ForegroundColor Red
        Exit
    }
    ElseIf ($UserTemp -and $ContiuneOnExist) {
        Return
    }
 
    $SecurePassword = convertto-securestring $Password -asplaintext -force
 
    Try {$objSourceUser = Get-ADUser -Identity $SourceUser -Properties $CopyAttributes -ErrorAction Stop}
    Catch {ExitScript "run [Get-ADUser $SourceUser], confirm user ID exist" $False}
 
    $OUPath = $objSourceUser.DistinguishedName.Replace("CN=$($objSourceUser.Name),","")
 
    Write-Host "`tCreating user -> DisplayName: [$DisplayName] GivenName: [$GivenName] SurName: [$SurName] `n`tCreating in OU: [$OUPath]" -ForegroundColor Cyan
 
    New-ADUser -Instance $objSourceUser -UserPrincipalName "$NewUser$UPNSufix" -SAMAccountName $NewUser -Name $DisplayName -DisplayName $DisplayName -AccountPassword $SecurePassword -GivenName $GivenName  -Surname $Surname -Path $OUPath
    Set-ADUser -Identity $NewUser -Enabled $True # I've seen the accounts randomly not being enabled without this
  
    Sleep 1 
    If ($objSourceUser.memberOf) {
        Get-ADUser -Identity $NewUser | Add-ADPrincipalGroupMembership -MemberOf $objSourceUser.memberOf
    }
}
 
If ($SourceUserID){
    CopyUser $SourceUserID $NewUserID $GivenName $Surname $DisplayName }
Else {
    Write-Host "SourceUserID not specified, script will assume user [$NewUserID] already exist and will Mailbox enabled it only." -ForegroundColor Yellow
}
 
Try {$UserTemp = Get-User $NewUserID -ErrorAction Stop}
Catch {ExitScript "run [Get-User $NewUserID], confirm user ID exist" $False}
 
Write-Host "`nGetting smallest Exchange DB that matches filter [$DBFilter]..." -ForegroundColor Green -NoNewLine
$TargetDB = Get-SmallestDB
Write-Host " Found, [$TargetDB] will be used." -ForegroundColor Green 
 
Write-Host "`nCreating mailbox for [$NewUserID] on [$TargetDB]" -ForegroundColor Cyan
Try {Enable-Mailbox $NewUserID -Database $TargetDB -ErrorAction Stop}
Catch {
    If ($_.Exception.Message -like '*is of type UserMailbox*') {
        Write-Host `t "[$NewUserID] already has a mailbox, continuing to next step " -ForegroundColor Yellow}
    Else {ExitScript "run [Enable-Mailbox $NewUserID -Database $TargetDB]" $True}}
 
Write-Host "Enabling retention policy and single item recovery" -ForegroundColor Cyan
Try {Set-Mailbox  $NewUserID  -RetentionPolicy $RetentionPolicy -SingleItemRecoveryEnabled $true  -CustomAttribute10 $CustomAttrib -ErrorAction Stop}
Catch {ExitScript "run [Set-Mailbox  $NewUserID  -RetentionPolicy $RetentionPolicy -SingleItemRecoveryEnabled $true]" $True}
 
If ($AddToGroup) {
    Try {Add-DistributionGroupMember -Identity $Group -Member $NewUserID -BypassSecurityGroupManagerCheck -ErrorAction Stop}
    Catch {
        If ($_.Exception.Message -like '*already a member of the group*') {
            Write-Host `t "Object [$NewUserID] is already in [$Group]" }
        Else {ExitScript "run [Add-DistributionGroupMember -Identity $Group -Member $NewUserID]" $True}}
}
 
If ($SendWelcome) {
    $objNewUser = Get-ADUser $NewUserID -Properties "EmailAddress"
    $EmailAddress = $objNewUser.EmailAddress
    If ($EmailAddress -eq $Null) {
        Write-Host "New user [$NewUserID] not found, waiting 5 seconds and retying..."
        Start-Sleep -s 5
        $objNewUser = Get-ADUser $NewUserID -Properties "EmailAddress"
        $EmailAddress = $objNewUser.EmailAddress
        If ($EmailAddress -eq $Null) {
            Write-Host "New user still not found, Welcome e-mail not sent. Exiting."
            Exit
        }
    }
    Write-Host "`nSending Welcome message to [$EmailAddress], waiting 10 seconds for mailbox creation process to finish" -ForegroundColor Cyan
    start-sleep 10 # This delay is sometimes needed
 
    
    Try {Send-MailMessage -From $From -To $EmailAddress -Subject $MsgSubject -Body $MsgBody -SmtpServer $SMTPServer -BodyAsHtml}
    Catch {ExitScript "run [Send-MailMessage -From $From -To $EmailAddress -SmtpServer $SMTPServer]" $True}
 }
