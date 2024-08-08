param(        
    [string]$tenantId="TENANT ID HERE",        
    #[string]$file="$Env:temp/VMsAutomaticTaggingResults.csv"    
    [string]$file="c:\temp\VMsAutomaticTaggingResults.csv"
    ) 
<#region connect to Azure
$connectionName = "AzureRunAsConnection"
try {    
    # Get the connection "AzureRunAsConnection"    
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName    
    $TenantId = $servicePrincipalConnection.TenantId    
    $ApplicationId = $servicePrincipalConnection.ApplicationId    
    $Thumbprint = $servicePrincipalConnection.CertificateThumbprint 
    Add-AzAccount `        
        -ServicePrincipal `        
        -TenantId $TenantId `        
        -ApplicationId $ApplicationId `        
        -CertificateThumbprint $Thumbprint >$null
    } catch {    
     if (!$servicePrincipalConnection) {        
        $ErrorMessage = "Connection $connectionName not found."        
        throw $ErrorMessage    
    } else {        
        Write-Error -Message $_.Exception        
        throw $_.Exception    
    }
}#>

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
    }    else {        
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
                "to"      = @(                    @{                        
                    "email" = $ToAddress                        
                    "name"  = $ToName                    
                    }                
                )                
                "subject" = $Subject            
            }        
        )        
        "content"          = @(            
            @{                
                "type"  = $mailbodyType                
                "value" = $MailBodyValue            
            }        
        )        
        "from"             = @{            
            "email" = $FromAddress            
            "name"  = $FromName        
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
        "authorization" = "Bearer 
        $token"    
    }    
    #send the mail through Sendgrid    
    $Parameters = @{        
        Method      = "POST"        
        Uri         = "https://api.sendgrid.com/v3/mail/send"        
        Headers     = $Header        
        ContentType = "application/json"        
        Body        = $BodyJson    
    }    
    Invoke-RestMethod @Parameters    
    write-output "Email sent"
}

$subs = Get-AzSubscription -TenantId $tenantId 
$vmobjs = @()
foreach ($sub in $subs){        
    Write-Host Processing subscription $($sub.SubscriptionName)    
    $vms = @()    
    $subtag = $null    
    $alltags = @()    
    $tags = $null
    try {        
        Set-AzContext -SubscriptionId $sub.SubscriptionId                
        $alltags = Get-AzTag -ResourceId /subscriptions/$sub
        foreach($tagKey in $alltags.Properties.TagsProperty.Keys) {            
            if ($tagKey -eq "SubscriptionUsage"){                
                $tagValue = $alltags.Properties.TagsProperty[$tagKey]                
                $subtag =  $tagValue                
                write-host "Subscription has tag value " 
                $subtag             
            }        
        }
        if ((!($null -eq $subtag)) -and (($subtag.toString() -eq "NonProd") -or ($subtag.toString() -eq "Prod"))) {            
            write-host "Tag validation accepted"                        
            $vms = Get-AzVM
            if ($subtag.toString() -eq "NonProd") {                
                $tags = @{"AtosBilling" = "NonProd"}            
            } else {                
                $tags = @{"AtosBilling" = "Prod"}            
            } 
            foreach ($vm in $vms) {                
                if (!($vm.tags.ContainsKey('AtosBilling')) -or ($null -eq $tags)) {                    
                    try {                        
                        Update-AzTag -ResourceId $vm.id -Tag $tags -Operation Merge                        
                        write-output "AtosBilling Tag added to server: " 
                        $vm.Name                        
                        $detail = @{                            
                            Subscription    = $sub.Name                            
                            VM              = $vm.Name                            
                            ResourceGroup   = $vm.ResourceGroupName                            
                            Action            = "Tagged"                            
                            Tag             = $subtag.toString()                        
                        }                        
                        $vmobjs += New-Object PSObject -Property $detail                    
                    } catch {                        
                        Write-output $error[0]                        
                        $detail = @{                            
                            Subscription    = $sub.Name                            
                            VM              = $vm.Name                           
                            ResourceGroup   = $vm.ResourceGroupName                            
                            Action            = "NA"                            
                            Tag             = "Ignored, GeneralizedVM or other"                        
                        }                        
                        $vmobjs += New-Object PSObject -Property $detail                    
                    }                
                } else {                    
                    write-output "SKIP, AtosBilling already exists on server: " $vm.Name                    
                    $detail = @{                        
                        Subscription    = $sub.Name                        
                        VM              = $vm.Name                        
                        ResourceGroup   = $vm.ResourceGroupName                        
                        Action            = "skipped"                        
                        Tag             = "Tag already exists"                    
                    }                    
                    $vmobjs += New-Object PSObject -Property $detail                
                }            
            }        
        } else {            
            write-output "Subscription doesn't have a tag or tag is incorrect"            
            $detail = @{                
                Subscription    = $sub.Name                
                VM              = "NA"                
                ResourceGroup   = "NA"                
                Action            = "NA"                
                Tag             = "Missing or incorrect Subscription tag"            
            }            $vmobjs += New-Object PSObject -Property $detail        
        }              
    }    catch {        
        Write-Host $error[0]    
    }
}
$vmobjs | Export-Csv -NoTypeInformation -Path $fileWrite-Host "VM list written to $file"
$apikey = "API KEY"
$MailParameters = @{    
    ToAddress   = "javier.juarezparedes"    
    ToName      = "Javier"    
    FromAddress = "Javier.juarezparedes"    
    FromName    = "Javier"    
    Subject     = "AutomatedTagging report"    
    Body        = "Results for AutomatedTagging script is attached."    
    BodyAsHTML  = "Results for AutomatedTagging script is attached. 'n 'n Atos XXX"    
    FileName    = "VMsAutomaticTaggingResults.csv"    
    FileNameWithFilePath = $file    
    AttachementType = "csv"    
    Token       = $apikey
}
write-host "sending email"Send-Email @MailParameters