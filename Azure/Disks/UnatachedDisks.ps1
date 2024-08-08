param(
    [string]$tenantId = "Tenant_ID",
    [string]$file = ".\UnatachedDisksAzure.csv"
)

Function Send-Email {
    param (
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
    if (-not[string]::IsNullOrEmpty($BodyAsHTML)) {
        $MailbodyType = 'text/HTML'
        $MailbodyValue = $BodyAsHTML
    }
    else{
        $MailbodyType = 'text/plain'
        $MailBodyValue = $Body
    }

    #Convert File to Base64
    $EncodedFile = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
    
    # Create a body for sendgrid
    write-output "Preparing email"
    $SendGridBody = @{
        "personalizations" = @(
            @{
                "to"      = @(
                    @{
                        "email" = $ToAddress
                        "name"  = $ToName
                    }
                )
                "subject" = $Subject
            }
        )
        "content"          = @(
            @{
                "type"  = $mailbodyType
                "value" = $MailBodyValue
            }
        )
        "from"             = @{
            "email" = $FromAddress
            "name"  = $FromName
        }
        "attachments" = @(
            @{
                "content"=$EncodedFile
                "filename"=$FileName
                "type"= $AttachementType
                "disposition"="attachment"
            }
        )
    }

    $BodyJson = $SendGridBody | ConvertTo-Json -Depth 10

    #Create the header
    $Header = @{
        "authorization" = "Bearer $token"
    }
    #send the mail through Sendgrid
    $Parameters = @{
        Method      = "POST"
        Uri         = "https://api.sendgrid.com/v3/mail/send"
        Headers     = $Header
        ContentType = "application/json"
        Body        = $BodyJson
    }
    Invoke-RestMethod @Parameters
    write-output "Email sent"
}

$subs = Get-AzSubscription -TenantId $tenantId $count = 0$jobsArray = @()
foreach ($sub in $subs){        
    Write-Host Processing subscription $($sub.SubscriptionName)    
    Set-AzContext -SubscriptionId $sub.SubscriptionId    
    #$deleteUnattachedDisks=0        
    #Obtaining all unnatached Disks from the subscription    
    $managedDisks = Get-AzDisk | ?{$_.DiskState -eq "Unattached"}        
    #Starting validation for each disk obtained    
    foreach ($md in $managedDisks) {                
        #Validating the disk is actually in unnatached state        
        if($md.DiskState -eq "Unattached"){
            #Validating if the disk is not tagged already, otherwise it will proceed to check the tag or delete            
            if (!($md.tags.ContainsKey('DeleteAfter')) -or ($null -eq $tags)) {                
                try {                    
                    $resource = Get-AzResource -Name $md.Name -ResourceGroup $md.ResourceGroupName                    
                    $tags = @{"DeleteAfter"=(Get-Date).AddDays(14).ToUniversalTime()}                     
                    Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge                     
                    Write-Host "Tagging unattached Managed Disk with Id: $($md.Name)"
                                #Building CSV file                    
                    $detail = @{                        
                        Subscription    = $sub.Name                        
                        DiskName        = $md.Name                        
                        ResourceGroup   = $md.ResourceGroupName                        
                        Action          = "SuccessfullyTagged"                        
                        DeleteAfter     = (Get-Date).AddDays(14).ToUniversalTime()                    
                    }                
                } catch {                    
                    Write-Host "FAILED to tag unattached Managed Disk with Id: $($md.Name)"
                    #Writting to CSV file                    
                    $detail = @{                        
                        Subscription    = $sub.Name                        
                        DiskName        = $md.Name                        
                        ResourceGroup   = $md.ResourceGroupName                        
                        Action          = "FailedToTag"                        
                        DeleteAfter     = "Empty"                    
                    }                
                }                                               
                        
            } else {
                #Checking if its tagged with never to delete                
                if ($md.tags.DeleteAfter -eq "never") {                    
                    Write-Host "Found tag to never delete for Disk: $($md.Name)"                    
                    #Writting to CSV file                    
                    $detail = @{                        
                        Subscription    = $sub.Name                        
                        DiskName        = $md.Name                        
                        ResourceGroup   = $md.ResourceGroupName                        
                        Action          = "NeverDelete"                        
                        DeleteAfter     = $md.tags.DeleteAfter                    
                    }                
                } else {
                    #Validating if the Delete After Tag is already over expired date and it doesnt equals never                    
                    if ([dateTime]$md.tags.DeleteAfter -lt (Get-Date).AddDays(-7)){
                                    #Using try and catch block to delete the disk                        
                        try {                            
                            #$md | Remove-AzDisk -Force                            
                            Write-Host "Successfully deleted unattached Managed Disk with Id:" $($md.Id)                            
                            #Writing to CSV file                            
                            $detail = @{                                
                                Subscription    = $subscription.Name                                
                                DiskName        = $md.Name                                
                                ResourceGroup   = $md.ResourceGroupName                                
                                Action          = "SuccessfullyDeleted"                                
                                DeleteAfter     = $md.tags.DeleteAfter                            
                            }
                        } catch {                            
                            Write-host "Failed to delete disk: " $md.Name                                                
                            #Writing to CSV file                            
                            $detail = @{                                
                                Subscription    = $subscription.Name                                
                                DiskName        = $md.Name                                
                                ResourceGroup   = $md.ResourceGroupName                                
                                Action          = "FailedToDelete"                                
                                DeleteAfter     = $md.tags.DeleteAfter                            
                            }                                                
                        }
                                                        
                    } else {                                                
                        Write-host "Tag not yet expired for disk: " $md.Name                                            
                        #Writing to CSV file                        
                        $detail = @{                            
                            Subscription    = $subscription.Name                            
                            DiskName        = $md.Name                            
                            ResourceGroup   = $md.ResourceGroupName                            
                            Action          = "NotYetExpired"                            
                            DeleteAfter     = $md.tags.DeleteAfter                        
                        }
                                
                    } #End Tag expiration If
                            
                } #End Never tag If
                        
            } #End Tag Confirmation If
                    
        } #End DiskStateIf
                    
        $count++        $jobsArray += New-Object PSObject -Property $detail
         
    } #End ForEachDisk     
    
}#End ForEachSub

Write-host $count "Unnatached disk found and actioned."
$jobsArray | Select-Object DiskName, ResourceGroup, Subscription, Action, DeleteAfter| Export-Csv -NoTypeInformation -Path $fileWrite-Host "VM list written to $file"
#API key for sendgrid
$apikey = "API KEY"
#Setting the parameters for the created email from email block
$MailParameters = @{    
    ToAddress   = "ToEmail"    
    ToName      = "Javier"    
    FromAddress = "FromMail"    
    FromName    = "Javier"    
    Subject     = "Unnatached Disk tag and Removal report"    
    Body        = "Unnatached Disk tag and Removal script is attached."    
    BodyAsHTML  = "Unnatached Disk tag and Removal script is attached."    
    FileName    = "UnnatachedDisks.csv"    
    FileNameWithFilePath = $file    
    AttachementType = "csv"    
    Token       = $apikey}
#Sending Email
write-host "sending email"Send-Email @MailParameters