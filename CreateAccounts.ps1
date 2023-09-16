param (
    [Parameter(Mandatory = $false)] [ValidateNotNullorEmpty()] [string] $CsvFile = "Accounts.csv",
    [Parameter(Mandatory = $false)] [ValidateNotNullorEmpty()] [string] $CsvDelimiter = ";"
)

Import-Module ActiveDirectory -ErrorAction SilentlyContinue
 
$domain = "AD.local"
$accountPath = "CN=Users,DC=ad,DC=local"
$accounts = Import-Csv $CsvFile -Delimiter $CsvDelimiter
 
foreach ($account in $accounts) {  
    Write-Host "Creating $($account.Username) ... " -NoNewline:$True
    $accountPassword = ConvertTo-SecureString -AsPlainText $account.Password -Force
    $accountUPN = "$($account.Username)@$($domain)"
    New-ADUser -SamAccountName $account.Username -name $account.Username -UserPrincipalName $accountUPN -Accountpassword $accountPassword -Enabled $true -PasswordNeverExpires $true -path $accountPath -OtherAttributes @{ Description = $ServiceAccount.Description }
    Write-Host -ForegroundColor Green "OK"
}