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