[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("AvailabilitySetsOnly","StandaloneVMs","ALL")]
    [String]$VirtualMachineTypes
)
BEGIN {
    try {
        $Error.Clear()
        Function Global:Get-ChoicePrompt {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory=$true)]
                [String[]]$OptionList, 
                [Parameter(Mandatory=$false)]
                [String]$Title, 
                [Parameter(Mandatory=$False)]
                [String]$Message = $null, 
                [int]$Default = 0 
            )
            $Options = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription] 
            $OptionList | foreach  { $Options.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList $_))} 
            $Host.ui.PromptForChoice($Title, $Message, $Options, $Default) 
        }
        Function Get-FileNameDialog {
            Param (
                $InitialDirectory,
                [ValidateSet("CSV","TXT")]
                $FileType
            )
            [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.initialDirectory = $InitialDirectory
            If ($FileType -eq "CSV") {$OpenFileDialog.filter = "CSV files (*.csv)| *.csv| All files (*.*)| *.*"}
            ElseIf ($FileType -eq "TXT") {$OpenFileDialog.filter = "Text files (*.txt)| *.txt| All files (*.*)| *.*"}
            Else {$OpenFileDialog.filter = "CSV files (*.csv)| *.csv| Text files (*.txt)| *.txt| All files (*.*)| *.*"}
            $OpenFileDialog.ShowDialog() | Out-Null
            $File = $OpenFileDialog.filename
            Return $File
        }
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
                $menuPrompt = "`n"
                $menuPrompt = "/" * (95)
                $menuPrompt += "`n`r////`n`r//// $Title`n`r////`n`r"
                $menuPrompt += "/" * (95)
                $menuPrompt += "`n`n"
            }
            ElseIf ($Style -eq "Mini") {
                $menuPrompt = "`n"
                $menuPrompt = "\" * (80)
                $menuPrompt += "`n\\\\  $Title`n"
                $menuPrompt += "\" * (80)
                $menuPrompt += "`n"
            }
            ElseIf ($Style -eq "Info") {
                $menuPrompt = "`n"
                $menuPrompt = "-" * (80)
                $menuPrompt += "`n-- $Title`n"
                $menuPrompt += "-" * (80)
            }
        
            #add the menu
            $menuPrompt+=$menu
        
            [System.Console]::ForegroundColor = $Color
            If ($DisplayOnly) {Write-Host $menuPrompt}
            Else {Read-Host -Prompt $menuprompt}
            [System.Console]::ResetColor()
        }
        Function Get-PSJobStatus {
            Param(
                [Int]$RefreshInterval = 5,
                [Int]$RequiredJobs,
                [Int]$MaximumJobs = $RequiredJobs
            )
            While (@(Get-Job -State "Running").Count -ne 0) {
                Clear-Host
                $JobsHashtable = Get-Job | Select Name,State | Group State -AsHashTable -AsString
                $CurrentJobs = (Get-Job | Measure).Count
                $RunningJobs = $JobsHashtable["Running"].Count
                $CompletedJobs = $JobsHashtable["Completed"].Count
                $FailedJobs = $JobsHashtable["Failed"].Count
                $BlockedJobs = $JobsHashtable["Blocked"].Count
                $RemainingJobs = $RequiredJobs - $CurrentJobs
                [System.Collections.Arraylist]$RunningJobStatus = @()
                
                $Status = ("{0} OF {1} JOBS CREATED - MAXIMUM JOBS SET TO {2}" -f $CurrentJobs,$RequiredJobs,$MaximumJobs)
                If ($CurrentJobs -le $MaximumJobs) {Show-Menu -Title "All Background Jobs have been submitted!" -DisplayOnly -Style Mini -Color White}
                Show-Menu -Title $Status -DisplayOnly -Style Info -Color Yellow
        
                Write-Host " >>" -NoNewline; Write-Host " $RemainingJobs " -NoNewline -ForegroundColor DarkGray; Write-Host "Jobs Remaining" -ForegroundColor DarkGray
                Write-Host " >>" -NoNewline; Write-host " $CurrentJobs " -NoNewline -ForegroundColor White; Write-Host "Total Jobs Created" -ForegroundColor White
                Write-Host " >>" -NoNewline; Write-Host " $RunningJobs " -NoNewline -ForegroundColor Cyan; Write-Host "Jobs In Progress" -ForegroundColor Cyan
                Write-Host " >>" -NoNewline; Write-Host " $CompletedJobs " -NoNewline -ForegroundColor Green; Write-Host "Jobs Completed" -ForegroundColor Green
                Write-Host " >>" -NoNewline; Write-Host " $BlockedJobs " -NoNewline -ForegroundColor Yellow; Write-Host "Jobs Blocked" -ForegroundColor Yellow
                Write-Host " >>" -NoNewline; Write-Host " $FailedJobs " -NoNewline -ForegroundColor Red; Write-Host "Jobs Failed" -ForegroundColor Red
        
                $Jobs = Get-Job | Group-Object State -AsHashTable -AsString
                foreach ($Job in $Jobs["Running"]) {
                    $JobName = $Job.Name
                    $JobDuration = ($Job.PSBeginTime - (Get-Date)).Negate()
                                        
                    $objJob = [PSCustomObject][Ordered]@{
                        JobName = ("{0}    " -f $JobName)
                        ElapsedTime = ("{0:N0}.{1:N0}:{2:N0}:{3:N0}" -f $JobDuration.Days,$JobDuration.Hours,$JobDuration.Minutes,$JobDuration.Seconds)
                        JobStatus = "Virtual Machine Resize in Progress"
                    }
                    [Void]$RunningJobStatus.Add($objJob)
                }
        
                If ($RunningJobStatus) {
                    Show-Menu -Title "Job Status" -DisplayOnly -Style Info -Color Cyan
                    $RunningJobStatus | Sort 'JobName' -Descending | Format-Table -AutoSize | Out-Host
                }
                Else {Show-Menu -Title "Waiting for Jobs to Start" -DisplayOnly -Style Info -Color Gray}
        
                Write-Host "`n`rNext refresh in " -NoNewline
                Write-Host $RefreshInterval -ForegroundColor Magenta -NoNewline
                Write-Host " Seconds"
                Start-Sleep -Seconds $RefreshInterval
            }
        } 
        Function Get-PSJobReport {
            [CmdletBinding()]
            Param()
            [System.Collections.ArrayList]$CompletedJobStatus = @()
            Foreach ($Job in @(Get-Job -State Completed)) {
                $JobDuration = $Job.PSEndTime -$Job.PSBeginTime
                $JobResults = $Job | Receive-Job -Keep
                If ($Job.ChildJobs[0].Error) {$ErrorMessage = "Errors - Check Portal"}
                Else {$ErrorMessage = "No Errors"}
                                                                 
                $objJob = [PSCustomObject][Ordered]@{
                    JobName = ("{0}    " -f $Job.Name)
                    ElapsedTime = ("{0:N0}.{1:N0}:{2:N0}:{3:N0}" -f $JobDuration.Days,$JobDuration.Hours,$JobDuration.Minutes,$JobDuration.Seconds)
                    CompletedTimeStamp = $Job.PSEndTime
                    JobStatus = $Job.State
                    ErrorStatus = $ErrorMessage
                    RollingResize = $JobResults.RollingResize
                    'Stop-AzureRmVm' = $JobResults.StopAzureVm
                    'Update-AzureRmVm' = $JobResults.UpdateAzureVm
                    'Start-AzureRmVm' = $JobResults.StartAzureVm
                }
        
                [Void]$CompletedJobStatus.Add($objJob)
            }
            Return $CompletedJobStatus
        }         
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        Show-Menu -Title "[SCRIPT] Update-AzureVMSize.ps1" -ClearScreen -DisplayOnly -Style Full -Color White

        Write-Verbose ("Opening File Dialog for CSV file selection...")
        Start-Sleep -Milliseconds 750
        $Importfile = Get-FileNameDialog -FileType CSV
        If ((Import-Csv $Importfile | Get-Member).Name -Contains "ResizeGroup") {
            Switch ($VirtualMachineTypes) {
                "AvailabilitySetsOnly" {
                    $VMResizeGroups = Import-Csv $Importfile |
                    Where-Object {$_.AvailabilitySet -ne "" -and $_.NoResize -eq "" -and $_.TargetSize -ne "N/A"} |
                    Select-Object Name,Subscription,ResourceGroupName,AvailabilitySet,Location,ResizeGroup,OSType,Size,@{l="TargetSize";e={("Standard_{0}" -f $_.TargetSize)}} |
                    Group-Object ResizeGroup -AsHashTable -AsString
                }
                "StandaloneVMs" {
                    $VMResizeGroups = Import-Csv $Importfile |
                    Where-Object {$_.AvailabilitySet -eq "" -and $_.NoResize -eq "" -and $_.TargetSize -ne "N/A"} |
                    Select-Object Name,Subscription,ResourceGroupName,AvailabilitySet,Location,ResizeGroup,OSType,Size,@{l="TargetSize";e={("Standard_{0}" -f $_.TargetSize)}} |
                    Group-Object ResizeGroup -AsHashTable -AsString
                }
                Default {
                    $VMResizeGroups = Import-Csv $Importfile |
                    Where-Object {$_.NoResize -eq "" -and $_.TargetSize -ne "N/A"} |
                    Select-Object Name,Subscription,ResourceGroupName,AvailabilitySet,Location,ResizeGroup,OSType,Size,@{l="TargetSize";e={("Standard_{0}" -f $_.TargetSize)}} |
                    Group-Object ResizeGroup -AsHashTable -AsString
                }
            }
        }
        Else {
            Write-Warning ("The import file ({0}) does not contain a ResizeGroup header!" -f $Importfile)
            Write-Warning ("Header values from file: {0}" -f ((Import-Csv $Importfile | Get-Member -MemberType NoteProperty).Name -Join ", "))
            Return
        }
    }
    catch {$PSCmdlet.ThrowTerminatingError($PSItem)}        
}
PROCESS {
    try {
        Do {
            $Groups = $VMResizeGroups.Keys | Sort | % {$_}
            Write-Verbose ("Found {0} Resize Groups" -f $VMResizeGroups.Keys.Count)
            $GroupSelection = (@"
`n
"@)
            $GroupRange = 0..($Groups.Count - 1)
            For ($i = 0; $i -lt $Groups.Count; $i++) {
                $Key = $Groups[$i]
                $GroupSelection += (" [{0}] VM Resize Group {1} (VMs: {2})`n" -f $i,$Groups[$i],$VMResizeGroups["$key"].Count)
            }
            $GroupSelection += " [C] Cancel`n"
            $GroupSelection += "`n Please select a VM Resize Group"

            Do {
                Write-Host "`n`r"
                $Choice = Show-Menu -Title "Select a VM Resize Group" -Menu $GroupSelection -Style Mini -Color Cyan
                $GroupChoice = $Groups[$Choice]
            }
            Until (($GroupRange -contains $Choice -OR $GroupRange -eq $Choice) -OR ($Choice.ToUpper() -eq "C"))

            If ($Choice.ToUpper() -eq "C") {
                Write-Warning "User cancelled the VM Resize Group selection!"
                Break
            }
            Write-Host "`n`r"
            Write-Verbose ("Current VM Resize Group Selected: Group {0}" -f $GroupChoice)
            Show-Menu -Title "Opening Grid View, validate VM(s) to be Resized..." -DisplayOnly -Style Mini -Color Gray
            Start-Sleep -Milliseconds 1750
            $VMResizeGroups["$($GroupChoice)"] | Out-GridView -Title "Validate Virtual Machines to be resized - CLOSE WHEN DONE!" -Wait

            Switch (Get-ChoicePrompt -OptionList "&Yes","&No" -Message ("`nDo you want to contine with Resizing {0} Virtual Machines in Group {1}? (Y/N)" -f $VMResizeGroups["$($GroupChoice)"].Count,$GroupChoice) -Default 0) {
                0 {
                    Write-Host "`n"
                    Write-Host (">>> Getting VM Properties and creating background processing jobs...") -BackgroundColor Cyan -ForegroundColor Black
                    Write-Verbose ("Clearing Previous PS Jobs")
                    Get-Job PSJob-* | Remove-Job -Confirm:$false
                    Foreach ($VM in $VMResizeGroups["$($GroupChoice)"]) {
                        # Connecting to the Virtual Machine Azure Subscription
                        Select-AzureRmSubscription -Subscription $VM.Subscription -Confirm:$false | Out-Null
                        # Getting VM Properties
                        $AzureVM = Get-AzureRmVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
                        If ($AzureVM.HardwareProfile.VmSize -ne $VM.TargetSize) {
                            $Scriptblock = {
                                Param($VMName,$RGName,$SubName,$TargetSize)
                                
                                $VMStatus = [PSCustomObject][Ordered]@{
                                    RollingResize = $true
                                    StopAzureVm = ""
                                    UpdateAzureVm = ""
                                    StartAzureVm = ""
                                }

                                Select-AzureRmSubscription -Subscription $SubName -Confirm:$false | Out-Null
                                $VirtualMachine = Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName
                                If ($NULL -eq $VirtualMachine.AvailabilitySetReference) {
                                    $VMStatus.RollingResize = $false
                                    $StopVM = Stop-AzureRmVM -Name $VirtualMachine.Name -ResourceGroupName $VirtualMachine.ResourceGroupName -Force
                                    If ($StopVM.Status -eq "Succeeded") {
                                        $VMStatus.StopAzureVm = $StopVM.Status
                                        $VirtualMachine.HardwareProfile.VmSize = $TargetSize
                                        $UpdateVM = Update-AzureRmVM -VM $VirtualMachine -ResourceGroupName $VirtualMachine.ResourceGroupName
                                        If ($UpdateVM.StatusCode -eq "OK") {
                                            $VMStatus.UpdateAzureVm = $UpdateVM.StatusCode
                                            $StartVM = Start-AzureRmVM -Name $VirtualMachine.Name -ResourceGroupName $VirtualMachine.ResourceGroupName
                                            If ($StartVM.Status -eq "Succeeded") {$VMStatus.StartAzureVm = $StartVM.Status}
                                            Else {$VMStatus.StartAzureVm = $StartVM.Status}
                                        }
                                        Else {
                                            $VMStatus.UpdateAzureVm = $UpdateVM.StatusCode
                                            $StartVM = Start-AzureRmVM -Name $VirtualMachine.Name -ResourceGroupName $VirtualMachine.ResourceGroupName
                                            If ($StartVM.Status -eq "Succeeded") {$VMStatus.StartAzureVm = $StartVM.Status}
                                            Else {$VMStatus.StartAzureVm = $StartVM.Status}
                                        }
                                    }
                                    Else {$VMStatus.StopAzureVm = $StopVM.Status}
                                }
                                Else {
                                    $VMStatus.StopAzureVm = "N/A"
                                    $VMStatus.StartAzureVm = "N/A"
                                    $VirtualMachine.HardwareProfile.VmSize = $TargetSize
                                    $UpdateVM = Update-AzureRmVM -VM $VirtualMachine -ResourceGroupName $VirtualMachine.ResourceGroupName
                                    If ($UpdateVM.StatusCode -eq "OK") {$VMStatus.UpdateAzureVm = $UpdateVM.StatusCode}
                                    Else {$VMStatus.UpdateAzureVm = $UpdateVM.StatusCode}
                                }
                                Return $VMStatus
                            }
                            
                            While (@(Get-Job -State "Running").Count -ge 10) {
                                Clear-Host
                                $JobsHashtable = Get-Job | Select Name,State | Group State -AsHashTable -AsString
                                $CurrentJobs = (Get-Job | Measure).Count
                                $RunningJobs = $JobsHashtable["Running"].Count
                                $CompletedJobs = $JobsHashtable["Completed"].Count
                                $FailedJobs = $JobsHashtable["Failed"].Count
                                $BlockedJobs = $JobsHashtable["Blocked"].Count
                                $RemainingJobs = ($VMResizeGroups["$GroupChoice"].Count) - $CurrentJobs
                                [System.Collections.Arraylist]$RunningJobStatus = @()
                                
                                $Status = ("{0} OF {1} JOBS CREATED - MAXIMUM JOBS SET TO {2}" -f $CurrentJobs,($VMResizeGroups["$GroupChoice"].Count),10)
                                Show-Menu -Title $Status -DisplayOnly -Style Info -Color Yellow
                        
                                Write-Host " >>" -NoNewline; Write-Host " $RemainingJobs " -NoNewline -ForegroundColor DarkGray; Write-Host "Jobs Remaining" -ForegroundColor DarkGray
                                Write-Host " >>" -NoNewline; Write-host " $CurrentJobs " -NoNewline -ForegroundColor White; Write-Host "Total Jobs Created" -ForegroundColor White
                                Write-Host " >>" -NoNewline; Write-Host " $RunningJobs " -NoNewline -ForegroundColor Cyan; Write-Host "Jobs In Progress" -ForegroundColor Cyan
                                Write-Host " >>" -NoNewline; Write-Host " $CompletedJobs " -NoNewline -ForegroundColor Green; Write-Host "Jobs Completed" -ForegroundColor Green
                                Write-Host " >>" -NoNewline; Write-Host " $BlockedJobs " -NoNewline -ForegroundColor Yellow; Write-Host "Jobs Blocked" -ForegroundColor Yellow
                                Write-Host " >>" -NoNewline; Write-Host " $FailedJobs " -NoNewline -ForegroundColor Red; Write-Host "Jobs Failed" -ForegroundColor Red
                        
                                $Jobs = Get-Job | Group-Object State -AsHashTable -AsString
                                foreach ($Job in $Jobs["Running"]) {
                                    $JobName = $Job.Name
                                    $JobDuration = ($Job.PSBeginTime - (Get-Date)).Negate()
                                                        
                                    $objJob = [PSCustomObject][Ordered]@{
                                        JobName = ("{0}    " -f $JobName)
                                        ElapsedTime = ("{0:N0}.{1:N0}:{2:N0}:{3:N0}" -f $JobDuration.Days,$JobDuration.Hours,$JobDuration.Minutes,$JobDuration.Seconds)
                                        JobStatus = "Virtual Machine Resize in Progress"
                                    }
                                    [Void]$RunningJobStatus.Add($objJob)
                                }
                        
                                If ($RunningJobStatus) {
                                    Show-Menu -Title "Job Status" -DisplayOnly -Style Info -Color Cyan
                                    $RunningJobStatus | Sort 'JobName' -Descending | Format-Table -AutoSize | Out-Host
                                }
                                Else {Show-Menu -Title "Waiting for Jobs to Start" -DisplayOnly -Style Info -Color Gray}
                        
                                Write-Host "`n`rNext refresh in " -NoNewline
                                Write-Host 10 -ForegroundColor Magenta -NoNewline
                                Write-Host " Seconds"
                                Start-Sleep -Seconds 10
                            }

                            Start-Job -Name ("PSJob-{0}" -f $VM.Name) -ScriptBlock $Scriptblock -ArgumentList $VM.Name,$VM.ResourceGroupName,$VM.Subscription,$VM.TargetSize | Out-Null
                        }
                        Else {Write-Warning ("[{0}] - VM matches the Target Size ({1})" -f $VM.Name,$VM.TargetSize)}
                    }

                    Get-PSJobStatus -RefreshInterval 5 -RequiredJobs $VMResizeGroups["$($GroupChoice)"].Count

                    Show-Menu -Title "Generating Job Report (includes Export to CSV)" -DisplayOnly -Style Mini -Color Cyan -ClearScreen
                    $Global:PSJobReport = Get-PSJobReport
                    $fileName = (".\PSJobReport_Group{0}_{1}.csv" -f $GroupChoice,(Get-Date -Format yyyyMMdd_HHmmss))
                    Write-Host (">>> Exporting the PS job report to CSV: $fileName") -BackgroundColor Yellow -ForegroundColor Black
                    $Global:PSJobReport | Export-Csv $fileName -NoTypeInformation

                    Switch (Get-ChoicePrompt -OptionList "&Yes","&No" -Message "`nDo you want to see the Job Report? (Y/N)" -Default 0) {
                        0 {$Global:PSJobReport | Out-GridView -Wait}
                        1 {Write-Warning "Skipping the PS job report display"}
                    }
                    
                    Write-Host "`n"
                    Write-Host (">>> Removing VM Resize Group {0} from the list of available groups to resize" -f $GroupChoice) -BackgroundColor Cyan -ForegroundColor Black
                    $VMResizeGroups.Remove("$($GroupChoice)")
                    If ($VMResizeGroups.Keys.Count -gt 0) {
                        Switch (Get-ChoicePrompt -OptionList "&Yes","&No" -Message "`nDo you want to contine with Resizing the remaining groups? (Y/N)" -Default 0) {
                            0 {Write-Host ("Resuming resize operation for remaining groups") -ForegroundColor Cyan}
                            1 {
                                Write-Warning "Exiting the script!"
                                $exitScript = $true
                            }
                        }
                    }
                    Else {Write-Host (">>> All VM Resize Groups have been processed!") -BackgroundColor Green -ForegroundColor Black}
                }
                1 {Write-Warning "VM Resize operation aborted!"; Break}
            }
            If ($exitScript) {Break} 
        }
        Until ($VMResizeGroups.Keys.Count -eq 0)
        $stopWatch.Stop()
        $elapsed = ("{0} hrs {1} mins {2} sec {3} ms" -f $stopWatch.Elapsed.Hours,$stopWatch.Elapsed.Minutes,$stopWatch.Elapsed.Seconds,$stopWatch.Elapsed.Milliseconds)
        Write-Host (">>> Script completed in: $elapsed") -ForegroundColor black -BackgroundColor Green
    }
    catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
}
