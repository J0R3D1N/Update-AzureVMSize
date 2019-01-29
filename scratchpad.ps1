Function Generate-LabDetails {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Small","Medium","Large")]
        [string]$Size,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Windows","Linux","Both")]
        [string]$OperatingSystem
    )

    
    Switch($Size) {
        Small {
            $Labsize = [Ordered]@{
                VMs = 9
                ResourceGroups = 3
                VMsPerRG = 3
                AVSetsPerRG = 1
                VMsPerAS = 2
                NonASVMsPerRG = 1
            }
        }
        Medium {
            $Labsize = [Ordered]@{
                VMs = 24
                ResourceGroups = 4
                VMsPerRG = 6
                AVSetsPerRG = 2
                VMsPerAS = 2
                NonASVMsPerRG = 2
            }
        }
        Large {
            $Labsize = [Ordered]@{
                VMs = 63
                ResourceGroups = 7
                VMsPerRG = 9
                AVSetsPerRG = 2
                VMsPerAS = 4
                NonASVMsPerRG = 1
            }
        }
    }

    Switch ($OperatingSystem) {
        "Windows" {[System.Collections.ArrayList]$OS = @("Windows")}
        "Linux" {[System.Collections.ArrayList]$OS = @("Linux")}
        "Both" {[System.Collections.ArrayList]$OS = @("Windows","Linux")}
    }

    $Elements = ("carbon","hellium","neon","argon","krypton","xenon","radon")
    [System.Collections.Hashtable]$LabDetails = [Ordered]@{}
    For ($i=0;$i -lt $Labsize.ResourceGroups;$i++) {
        $Element = $Elements[$i % $Labsize.ResourceGroups]
        $RGName = ("lab-{0}-rg" -f $Element)

        <# If (Get-AzureRmResourceGroup -Name $RGName -ErrorAction SilentlyContinue) {
            Write-Verbose ("[{0}] - Resource Group exists!" -f $RGName)
        }
        Else {
            Write-Warning ("[{0}] - Resource Group not found, Creating Resource Group!" -f $RGName)
            Write-Verbose "Getting Azure Locations..."
            $Locations = Get-AzureRmLocation | Select DisplayName,Location
            Write-Verbose ("Found {0} Azure Locations" -f $Locations.Count)
            $LocationSelection = (@"
`n
"@)
            $LocationRange = 0..($Locations.Count - 1)
            For ($i = 0; $i -lt $Locations.Count;$i++) {$LocationSelection += " [$i] $($Locations[$i].DisplayName)`n"}
            $LocationSelection += "`n Please select a Location"
        
            Do {
                $LocationChoice = Show-Menu -Title "Select an Azure Datacenter Location" -Menu $LocationSelection -Style Mini -Color Yellow
            }
            While (($LocationRange -notcontains $LocationChoice) -OR (-NOT $LocationChoice.GetType().Name -eq "Int32"))
            
            Write-Verbose ("Azure Datacenter Location: {0}" -f $Locations[$LocationChoice].DisplayName)

            New-AzureRmResourceGroup -Name $RGName -Location $Locations[$LocationChoice].Location -WhatIf
        
        } #>

        $AVSets = 1..$Labsize.AVSetsPerRG | % {("lab-{0}-as{1}" -f $Element,$_)}
        $VMs = 1..$Labsize.VMsPerRG | % {("lab-{0}-vm{1}-{2}" -f $Element,$_,((([char[]]([char]97..[char]122)) + 0..9 | sort {Get-Random})[0..6] -join ""))}
        $ASVMRange = (($labsize.VMsPerAS * $labsize.AVSetsPerRG) - 1)
        $NonASVMRange = $ASVMRange + 1

        $tmpVMHash = Split-Array -InputObject $VMs[0..$ASVMRange] -Parts $Labsize.AVSetsPerRG -KeyType  ByIndex
        $tmpOSHash = Split-Array -InputObject $VMs -Parts $OS.Count -KeyType ByIndex
        $tmpOSHashKeys = ($tmpOSHash.Keys | Sort) | % {$_}
        $tmpVMHashKeys = ($tmpVMHash.Keys | Sort) | % {$_}

        $LabDetails.$($Element) = @{
            ResourceGroup = $RGName
            AvailabilitySets = [Ordered]@{}
            VirtualMachines = [Ordered]@{}
        }

        Foreach ($AS in $AVSets) {
            $LabDetails.$($Element).AvailabilitySets.$($AS) = [Ordered]@{
                Name = [String]$AS
                ResourceGroupName = $LabDetails.$($Element).ResourceGroup
                TemplateFilePath = ("{0}\ArmTemplates\AVSet.json" -f $Script:Path)
                Subscription = $objAzureSub.Id
                Parameters = [Ordered]@{
                    avSetName = [String]$AS
                    faultDomains = 3
                    updateDomains = 5
                    sku = "Aligned"
                }
            }
        }

        If ($OS.Count -eq 1) {
            If ($tmpVMHashKeys.Count -gt 1) {
                For ($x=0;$x -lt $tmpVMHashKeys.Count;$x++) {
                    $AVSetName = $AVSets[$x % $tmpVMHashKeys.Count]
                    $tmpVMHashKey = $tmpVMHashKeys[$x]
                    Foreach ($VM in $tmpVMHash[$tmpVMHashKey]) {
                        $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                            Name = [String]$VM
                            ResourceGroupName = $LabDetails.$($Element).ResourceGroup
                            TemplateFilePath = ("{0}\ArmTemplates\Lab-VM-{1}.json" -f $Script:Path,$OS)
                            Subscription = $objAzureSub.id
                            Parameters = @{
                                storageAccountName = ("lab-{0}-strgacct" -f $Element)
                                publicIPAddressName = ("{0}-publicIP" -f [String]$VM)
                                publicIpAddressType = "Dynamic"
                                publicIpAddressSku = "Basic"
                                virtualNetworkName = ("lab-{0}-vNet" -f $Element)
                                virtualNicName = ("{0}-vNic" -f [String]$VM)
                                subnetName = "Subnet"
                                virtualMachineName = [String]$VM
                                virtualMachineSize = "Standard_F1s"
                                adminUsername = "AzureLabAdmin"
                                adminPassword = '@zure@dm|n1!' 
                                availabilitySetName = $AVSetName
                                operatingSystem = [String]$OS
                            }
                        }
                    }
                }
            }
            Else {
                $AVSetName = $AVSets
                $tmpVMHashKey = $tmpVMHashKeys
                Foreach ($VM in $tmpVMHash[$tmpVMHashKey]) {
                    $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                        Name = [String]$VM
                        ResourceGroupName = $LabDetails.$($Element).ResourceGroup
                        TemplateFilePath = ("{0}\ArmTemplates\Lab-VM-{1}.json" -f $Script:Path,[String]$OS)
                        Subscription = $objAzureSub.id
                        Parameters = @{
                            storageAccountName = ("lab-{0}-strgacct" -f $Element)
                            publicIPAddressName = ("{0}-publicIP" -f [String]$VM)
                            publicIpAddressType = "Dynamic"
                            publicIpAddressSku = "Basic"
                            virtualNetworkName = ("lab-{0}-vNet" -f $Element)
                            virtualNicName = ("{0}-vNic" -f [String]$VM)
                            subnetName = "Subnet"
                            virtualMachineName = [String]$VM
                            virtualMachineSize = "Standard_F1s"
                            adminUsername = "AzureLabAdmin"
                            adminPassword = '@zure@dm|n1!' 
                            availabilitySetName = $AVSetName
                            operatingSystem = [String]$OS
                        }
                    }
                }
            }

            $VMs[$NonASVMRange..$VMs.Count] | % {
                $VM = $_
                $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                    Name = [String]$VM
                    ResourceGroupName = $LabDetails.$($Element).ResourceGroup
                    TemplateFilePath = ("{0}\ArmTemplates\Lab-VM-{1}.json" -f $Script:Path,[String]$OS)
                    Subscription = $objAzureSub.id
                    Parameters = @{
                        storageAccountName = ("lab-{0}-strgacct" -f $Element)
                        publicIPAddressName = ("{0}-publicIP" -f [String]$VM)
                        publicIpAddressType = "Dynamic"
                        publicIpAddressSku = "Basic"
                        virtualNetworkName = ("lab-{0}-vNet" -f $Element)
                        virtualNicName = ("{0}-vNic" -f [String]$VM)
                        subnetName = "Subnet"
                        virtualMachineName = [String]$VM
                        virtualMachineSize = "Standard_F1s"
                        adminUsername = "AzureLabAdmin"
                        adminPassword = '@zure@dm|n1!' 
                        availabilitySetName = ""
                        operatingSystem = [String]$OS
                    }
                }
            }
        }
        Else {
            For ($x=0;$x -lt $tmpVMHashKeys.Count;$x++) {
                $AVSetName = $AVSets[$x % $tmpVMHashKeys.Count]
                $tmpVMHashKey = $tmpVMHashKeys[$x]
                Foreach ($VM in $tmpVMHash[$tmpVMHashKey]) {
                    $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                        Name = [String]$VM
                        ResourceGroupName = $LabDetails.$($Element).ResourceGroup
                        TemplateFilePath = ("{0}\ArmTemplates\Lab-VM-{1}.json" -f $Script:Path,$OS)
                        Subscription = $objAzureSub.id
                        Parameters = @{
                            storageAccountName = ("lab-{0}-strgacct" -f $Element)
                            publicIPAddressName = ("{0}-publicIP" -f [String]$VM)
                            publicIpAddressType = "Dynamic"
                            publicIpAddressSku = "Basic"
                            virtualNetworkName = ("lab-{0}-vNet" -f $Element)
                            virtualNicName = ("{0}-vNic" -f [String]$VM)
                            subnetName = "Subnet"
                            virtualMachineName = [String]$VM
                            virtualMachineSize = "Standard_F1s"
                            adminUsername = "AzureLabAdmin"
                            adminPassword = '@zure@dm|n1!' 
                            availabilitySetName = $AVSetName
                            operatingSystem = ""
                        }
                    }
                }
            }

            $VMs[$NonASVMRange..$VMs.Count] | % {
                $VM = $_
                $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                    Name = [String]$VM
                    ResourceGroupName = $LabDetails.$($Element).ResourceGroup
                    TemplateFilePath = ("{0}\ArmTemplates\Lab-VM-{1}.json" -f $Script:Path,$OS)
                    Subscription = $objAzureSub.id
                    Parameters = @{
                        storageAccountName = ("lab-{0}-strgacct" -f $Element)
                        publicIPAddressName = ("{0}-publicIP" -f [String]$VM)
                        publicIpAddressType = "Dynamic"
                        publicIpAddressSku = "Basic"
                        virtualNetworkName = ("lab-{0}-vNet" -f $Element)
                        virtualNicName = ("{0}-vNic" -f [String]$VM)
                        subnetName = "Subnet"
                        virtualMachineName = [String]$VM
                        virtualMachineSize = "Standard_F1s"
                        adminUsername = "AzureLabAdmin"
                        adminPassword = '@zure@dm|n1!' 
                        availabilitySetName = ""
                        operatingSystem = ""
                    }
                }
            }

            For ($a=0;$a -lt $tmpOSHashKeys.Count;$a++) {
                $OSName = $OS[$a % $tmpOSHashKeys.Count]
                $tmpOSHashKey = $tmpOSHashKeys[$a]
                Foreach ($VM in $tmpOSHash[$tmpOSHashKey]) {
                    $LabDetails.$($Element).VirtualMachines.$($VM).TemplateFilePath = ("{0}\ArmTemplates\Lab-VM-{1}.json" -f $Script:Path,$OSName)
                    $LabDetails.$($Element).VirtualMachines.$($VM).Parameters.operatingSystem = $OSName
                }
            }
        }
    }
    Return $LabDetails
}

$Deployments = [Ordered]@{}

Foreach ($Key in $ConfigData.Keys) {
    For ($i=0;$i -lt $ConfigData.$($key).AvailabilitySets.Count;$i++){
        $Deployments.$("$key-CreateAvailabilitySet-$i") = $ConfigData.$($Key).AvailabilitySets[$i]
    }
    For ($i=0;$i -lt $ConfigData.$($key).VirtualMachines.Count;$i++){
        $Deployments.$("$key-CreateVirtualmachine-$i") = $ConfigData.$($Key).VirtualMachines[$i]
    }
}
<#



$RGs = Get-AzureRmResourceGroup | ? {$_.resourcegroupname -ne "rg-dev-prkrlab-argon" -and $_.resourcegroupname -notlike "*-prkrlab"}
$OS = "Windows","Linux"

$RGs | % {
    $RGName = $_.ResourceGroupName
    $RGSubName = $_.ResourceGroupName.Split("-")[-1].ToUpper()
    $OS | % {
        $ASName = ("{0}-AS-{1}" -f $RGSubName,$_)
        New-AzureRmAvailabilitySet -Name $ASName -ResourceGroupName $RGName -Location 'USGov Arizona' -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5
    }
}

Function Update-AzureContext {
    [CmdletBinding()]
    Param()

    Function Show-Menu {
        Param(
            [string]$Menu,
            [string]$Title = $(Throw [System.Management.Automation.PSArgumentNullException]::new("Title")),
            [switch]$ClearScreen,
            [Switch]$DisplayOnly,
            [ValidateSet("Full","Mini","Info")]
            $Style = "Full",
            [ValidateSet("White","Cyan","Magenta","Yellow","Green","Red","Gray","DarkGray")]
            $Color = "Gray"
        )
        if ($ClearScreen) {[System.Console]::Clear()}
    
        If ($Style -eq "Full") {
            #build the menu prompt
           $menuPrompt = "/" * (95)
            $menuPrompt += "`n`r////`n`r//// $Title`n`r////`n`r"
            $menuPrompt += "/" * (95)
            $menuPrompt += "`n`n"
        }
        ElseIf ($Style -eq "Mini") {
            #$menuPrompt = "`n"
            $menuPrompt = "\" * (80)
            $menuPrompt += "`n\\\\  $Title`n"
            $menuPrompt += "\" * (80)
            $menuPrompt += "`n"
        }
        ElseIf ($Style -eq "Info") {
            #$menuPrompt = "`n"
            $menuPrompt = "-" * (80)
            $menuPrompt += "`n-- $Title`n"
            $menuPrompt += "-" * (80)
        }
    
        #add the menu
        $menuPrompt+=$menu
    
        [System.Console]::ForegroundColor = $Color
        If ($DisplayOnly) {Write-Host $menuPrompt}
        Else {Read-Host -Prompt $menuprompt}
        [system.console]::ResetColor()
    }

    Write-Verbose "Getting Azure Subscriptions..."
    $Subs = Get-AzureRmSubscription | % {$_.Name}
    Write-Verbose ("Found {0} Azure Subscriptions" -f $Subs.Count)
    $SubSelection = (@"
`n
"@)
    $SubRange = 0..($Subs.Count - 1)
    For ($i = 0; $i -lt $Subs.Count;$i++) {$SubSelection += " [$i] $($Subs[$i])`n"}
    $SubSelection += "`n Please select a Subscription"

    Do {
        $SubChoice = Show-Menu -Title "Select an Azure Subscription" -Menu $SubSelection -Style Mini -Color Yellow
    }
    While (($SubRange -notcontains $SubChoice) -OR (-NOT $SubChoice.GetType().Name -eq "Int32"))
    
    Write-Verbose ("Updating Azure Subscription to: {0}" -f $Subs[$SubChoice])
    Select-AzureRmSubscription -Subscription $Subs[$SubChoice] | Out-Null
}

Set-Alias -Name uac -Value Update-AzureContext -Description "Gets the current Azure Subscriptions and creates a menu to change the current subscription."

function prompt {
    $AzureContext = Get-AzureRmContext -ErrorAction SilentlyContinue   
    If ($AzureContext) {
        $SubName = $AzureContext.Name.Split(" ")[0]
                    $Account = $AzureContext.Account.Id
        $host.UI.Write("Cyan", $host.UI.RawUI.BackGroundColor, "[$SubName - $Account]`n") + "[PS] " + (Get-Location).path + '>'
    }
    Else {
        $host.UI.Write("Yellow", $host.UI.RawUI.BackGroundColor, "[NotConnected] ") + (Get-Location).path + '>'
    }
}

#>