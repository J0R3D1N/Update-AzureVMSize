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
        $AVSets = 1..$Labsize.AVSetsPerRG | % {("lab-{0}-as{1}" -f $Element,$_)}
        $VMs = 1..$Labsize.VMsPerRG | % {("lab-{0}-vm{1}-{2}" -f $Element,$_,((([char[]]([char]97..[char]122)) + 0..9 | sort {Get-Random})[0..6] -join ""))}
        $ASVMRange = (($labsize.VMsPerAS * $labsize.AVSetsPerRG) - 1)
        $NonASVMRange = $ASVMRange + 1

        $tmpVMHash = Split-Array -InputObject $VMs[0..$ASVMRange] -Parts $Labsize.AVSetsPerRG -KeyType  ByIndex
        $tmpOSHash = Split-Array -InputObject $VMs -Parts $OS.Count -KeyType ByIndex
        $tmpOSHashKeys = ($tmpOSHash.Keys | Sort) | % {$_}
        $tmpVMHashKeys = ($tmpVMHash.Keys | Sort) | % {$_}

        $LabDetails.$($Element) = @{
            ResourceGroup = ("lab-{0}-rg" -f $Element)
            AvailabilitySets = $AVSets
            VirtualMachines = [Ordered]@{}
        }

        If ($OS.Count -eq 1) {
            For ($x=0;$x -lt $tmpVMHashKeys.Count;$x++) {
                $AVSetName = $AVSets[$x % $tmpVMHashKeys.Count]
                $tmpVMHashKey = $tmpVMHashKeys[$x]
                Foreach ($VM in $tmpVMHash[$tmpVMHashKey]) {
                    $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                        AvailabilitySet = $AVSetName
                        OperatingSystem = [String]$OS
                    }
                }
            }

            $VMs[$NonASVMRange..$VMs.Count] | % {
                $VM = $_
                $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                    AvailabilitySet = ""
                    OperatingSystem = [String]$OS
                }
            }
        }
        Else {
            For ($x=0;$x -lt $tmpVMHashKeys.Count;$x++) {
                $AVSetName = $AVSets[$x % $tmpVMHashKeys.Count]
                $tmpVMHashKey = $tmpVMHashKeys[$x]
                Foreach ($VM in $tmpVMHash[$tmpVMHashKey]) {
                    $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                        AvailabilitySet = $AVSetName
                        OperatingSystem = $OS
                    }
                }
            }

            $VMs[$NonASVMRange..$VMs.Count] | % {
                $VM = $_
                $LabDetails.$($Element).VirtualMachines.$($VM) = [Ordered]@{
                    AvailabilitySet = ""
                    OperatingSystem = $OS
                }
            }

            For ($a=0;$a -lt $tmpOSHashKeys.Count;$a++) {
                $OSName = $OS[$a % $tmpOSHashKeys.Count]
                $tmpOSHashKey = $tmpOSHashKeys[$a]
                Foreach ($VM in $tmpOSHash[$tmpOSHashKey]) {
                    $LabDetails.$($Element).VirtualMachines.$($VM).OperatingSystem = $OSName
                }
            }
        }
    }
    Return $LabDetails
}