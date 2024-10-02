##################################################
##  remove azure snapshots ##
##  
##     - removes snapshots with deleteAfter tag greater than 7 days ago
##     - Ignores snapshots With tag set as never  
##     - Marks for investigation Snapshots without tag "DeleteAfter"
##  Last modified by:
##     - Javier Juarez 09/04/2024##  
##################################################

param(        
    [string]$tenantId="TenantID",        
    [string]$file="$Env:temp/AutomaticSnapRemovalResults.csv"    
    #[string]$file="c:\temp\AutomaticSnapRemovalResults.csv"
    ) 
#region connect to Azure
connect-azaccount -identity

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
    } else {        
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
    Invoke-RestMethod @Parameters    
    write-output "Email sent"
}

$subscriptions = Get-AzSubscription -TenantId $tenantId 
$deletedSnaps = @()
$results = ""
$vmobjs = @()
#Selecting each subscription
foreach($subscription in $subscriptions) {    
    $sink = Set-AzContext -Subscription $subscription    
    Write-output "Subscription: " $subscription.Name

    #Fetching all snapshots in the subscription    
    $theseSnaps = Get-AzSnapshot    
    Write-output " Found: " $theseSnaps.count " Snapshots"
    foreach($snap in $theseSnaps){
        #Validating if Snapshot contains the DeleteAfter Tag        
        if($snap.tags.DeleteAfter){
            #Validating the DeleteAfter tag is not tagged to never be deleted            
            if ($snap.tags.DeleteAfter -eq "never") {                
                Write-output $snap.Tags.DeleteAfter " Tagged to never delete"                
                #Writing to CSV file                
                $detail = @{                    
                    Subscription    = $subscription.Name                    
                    Snapshot        = $snap.Name                    
                    ResourceGroup   = $snap.ResourceGroupName                    
                    Action          = "NeverDelete"                    
                    DeleteAfter     = $snap.tags.DeleteAfter                
                }                
                $vmobjs += New-Object PSObject -Property $detail
            } else {                
                #Validating if the Delete After Tag is already over expired date and it doesnt equals never                
                if ([dateTime]$snap.tags.DeleteAfter -lt (Get-Date).AddDays(-7)){                    
                    Write-output "Removing " $snap.Name
                    #Using try to validate if snapshot cant be removed, otherwise we would report an error                    
                    try {                        
                        $sink = Remove-AzSnapshot -SnapshotName $snap.Name -ResourceGroupName $snap.ResourceGroupName -Confirm:$false -WarningAction Continue -Force -AsJob 
                        # -WhatIf                        
                        $deletedSnaps += $snap                        
                        $results.removed ++                        
                        #Writing to CSV file                        
                        $detail = @{                            
                            Subscription    = $subscription.Name                            
                            Snapshot        = $snap.Name                            
                            ResourceGroup   = $snap.ResourceGroupName                            
                            Action          = "Deleted"                            
                            DeleteAfter     = $snap.tags.DeleteAfter                        
                        }                        
                    $vmobjs += New-Object PSObject -Property $detail                        
                    Write-output $snap.Name " Removed"

                    #Cathing error from try in case removal fails                    
                    } catch {                        
                        Write-output $snap.Tags.DeleteAfter " Error when removing"                        
                        #Writing to CSV file                        
                        $detail = @{                            
                            Subscription    = $subscription.Name                            
                            Snapshot        = $snap.Name                            
                            ResourceGroup   = $snap.ResourceGroupName                            
                            Action          = "Error on Deletion"                            
                            DeleteAfter     = $snap.tags.DeleteAfter                        
                        }                        
                        $vmobjs += New-Object PSObject -Property $detail                    
                    }                
                #If the DeleteAfter tag doesnt contain never and date has not expired, then it means its a recent snapshot                
                } else {                    
                    Write-output $snap.Name " not yet expired"                    
                    $results.lessThan7DaysOld ++                    
                    #Writing to CSV file                   
                    $detail = @{                        
                        Subscription    = $subscription.Name                        
                        Snapshot        = $snap.Name                        
                        ResourceGroup   = $snap.ResourceGroupName                        
                        Action          = "NotYetExpired"                        
                        DeleteAfter     = $snap.tags.DeleteAfter                    
                    }                    
                $vmobjs += New-Object PSObject -Property $detail                
                }            
            }
            #This block means the snapshot doesnt have a DeleteAfter tag and needs to be investigated        
        } Else {            
            Write-output $snap.Name "Doesnt have a delete after tag, needs investigation"            
            $results.noDeleteAfterTag ++            
            #Writing to CSV file            
            $detail = @{                
                Subscription    = $subscription.Name                
                Snapshot        = $snap.Name                
                ResourceGroup   = $snap.ResourceGroupName                
                Action          = "Investigate"                
                DeleteAfter     = "NotTagged"            
            }            
            $vmobjs += New-Object PSObject -Property $detail            
            $results.investigate ++        
        }            
    }
}
$results

#Export into CSV file the variable vmobjs
$vmobjs | Export-Csv -NoTypeInformation -Path $fileWrite-Host "VM list written to $file"

#API key for sendgrid
$apikey = "ApiKey"

#Setting the parameters for the created email from email block
$MailParameters = @{    
    ToAddress   = "to@email.com"    
    ToName      = "CloudTeam"    
    FromAddress = "from@email.com"    
    FromName    = "CloudTeam"    
    Subject     = "Automated Snapshot Removal report"    
    Body        = "Results for Automated Snapshot Removal script is attached."    
    BodyAsHTML  = "Results for Automated Snapshot Removal script is attached."    
    FileName    = "AutomaticSnapRemovalResults.csv"    
    FileNameWithFilePath = $file    
    AttachementType = "csv"    
    Token       = $apikey
}
#Sending Email
write-host "sending email"Send-Email @MailParameters
