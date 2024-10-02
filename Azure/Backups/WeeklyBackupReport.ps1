###################################################
#  Weekly backup report ##
##  Summarize all successful and failed backup of the last 7 days.##
##
##  Last modified by:
##     - Javier Juarez 01/20/2023##  
##################################################
param(        
    [string]$tenantId="5b438694-4d84-4561-8891-13a86a443556",        
    [string]$file="$Env:temp/VMsAutomaticTaggingResults.csv"
) 

Connect-AzAccount -Identity

Function Send-Email {    
    param (        
        [cmdletbinding()]        
        [parameter()]        
        [string]$ToAddress,        
        [parameter()]        
        [string]$ToName,        
        [parameter()]        
        [string]$FromAddress,        
        [parameter()]        
        [string]$FromName,        
        [parameter()]        
        [string]$Subject,        
        [parameter()]        
        [string]$Body,        
        [parameter()]        
        [string]$BodyAsHTML,        
        [parameter()]        
        [string]$FileName,        
        [parameter()]        
        [string]$FileNameWithFilePath,        
        [parameter()]        
        [string]$AttachementType,        
        [parameter()]        
        [string]$Token    
    )    
    if (-not[string]::IsNullOrEmpty($BodyAsHTML)) {        
        $MailbodyType = 'text/HTML'        
        $MailbodyValue = $BodyAsHTML    
    }    else {        
        $MailbodyType = 'text/plain'        
        $MailBodyValue = $Body    
    }
    #Convert File to Base64    
    $EncodedFile = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))        
    # Create a body for sendgrid    
    write-output "Preparing email"    
    $SendGridBody = @{        
        "personalizations" = @(            
            @{                
                "to"      = @(                    
                    @{                        
                        "email" = $ToAddress                        
                        "name"  = $ToName                    
                    }                
                )                
                "subject" = $Subject            
            }        
        )        
        "content"          = @(            
            @{                
                "type"  = $mailbodyType                
                "value" = $MailBodyValue            
            }        
        )        
        "from"             = @{            
            "email" = $FromAddress            
            "name"  = $FromName        
        }        
        "attachments" = @(            
            @{                
                "content"=$EncodedFile                
                "filename"=$FileName                
                "type"= $AttachementType                
                "disposition"="attachment"            
            }        
        )    
    }
    $BodyJson = $SendGridBody | ConvertTo-Json -Depth 10
    #Create the header    
    $Header = @{        
        "authorization" = "Bearer $token"    
    }    
    #send the mail through Sendgrid    
    $Parameters = @{        
        Method      = "POST"        
        Uri         = "https://api.sendgrid.com/v3/mail/send"        
        Headers     = $Header        
        ContentType = "application/json"        
        Body        = $BodyJson    
    }    
    Invoke-RestMethod @Parameters    write-output "Email sent"
}

$subs = Get-AzSubscription -TenantId $tenantId 
$jobsArray = @()
foreach ($sub in $subs){        
    write-output Processing subscription $($sub.SubscriptionName)    
    Set-AzContext -SubscriptionId $sub.SubscriptionId    
    $vaults = Get-AzRecoveryServicesVault
    foreach ($vault in $vaults) {        
        $VMs = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID
        foreach ($vm in $VMs.FriendlyName) {            
            $JobsCompleted = Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -Status Completed -From (Get-Date).AddDays(-7).ToUniversalTime() -BackupManagementType AzureVM | Where-Object {$_.WorkloadName -eq $vm}            
            $JobsFailed = Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -Status Failed -From (Get-Date).AddDays(-7).ToUniversalTime() -BackupManagementType AzureVM | Where-Object {$_.WorkloadName -eq $vm}            
            for ($i=0; $i -lt $JobsCompleted.Length; $i++){                
                $JobCompletedDetails = Get-AzRecoveryServicesBackupJobDetail -Job $JobsCompleted[$i] -VaultId $vault.ID                
                $jobsArray += $JobCompletedDetails            
            }            
            for ($i=0; $i -lt $JobsFailed.Length; $i++){                
                $JobFailedDetails = Get-AzRecoveryServicesBackupJobDetail -Job $JobsFailed[$i] -VaultId $vault.ID                
                $jobsArray += $JobFailedDetails            
            }            
            Write-Host "Getting details for server $vm"        
        }    
    }
    $jobsArray | Select-Object WorkloadName, Status, JobId, StartTime, EndTime, Duration, @{N="Backup Size";E={$_.Properties['Backup Size']}} | Export-Csv -NoTypeInformation -Path $file}
Write-Host "VM list written to $file"
#API key for sendgrid
$apikey = "API KEY"
#Setting the parameters for the created email from email block
$MailParameters = @{    
    ToAddress   = "ISCloudTeam@BSWHealth.org"    
    ToName      = "CloudTeam"    
    FromAddress = "AtosCloudTeam@mail.bswhive.com"    
    FromName    = "AtosCloudTeam"    
    Subject     = "Automated Weekly backup report"    
    Body        = "Results for Automated Weekly backup report script is attached."    
    BodyAsHTML  = "Results for Automated Weekly backup report script is attached."    
    FileName    = "WeeklyBackupReport.csv"    
    FileNameWithFilePath = $file    
    AttachementType = "csv"    
    Token       = $apikey
}
#Sending Emailwrite-output "sending email"Send-Email @MailParameters