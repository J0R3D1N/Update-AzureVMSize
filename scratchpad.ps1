#region RunspacePool Demo
$Parameters = @{}
$RunspacePool = [runspacefactory]::CreateRunspacePool(
    [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
)
[void]$RunspacePool.SetMaxRunspaces(2)
$RunspacePool.Open()
$jobs = New-Object System.Collections.ArrayList
1..10 | ForEach {
    $Parameters.Pipeline = $_
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    [void]$PowerShell.AddScript({
        Param (
            $Pipeline
        )
        If ($Pipeline -BAND 1) {
            $Fail = $True
        }
        $ThreadID = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        [pscustomobject]@{
            Pipeline = $Pipeline
            Thread = $ThreadID
            Fail = $Fail
        }
        Start-Sleep -Seconds 120
        #Remove-Variable fail
    }, $True) #Setting UseLocalScope to $True fixes scope creep with variables in RunspacePool
    [void]$PowerShell.AddParameters($Parameters)
    [void]$jobs.Add((
        [pscustomobject]@{
            PowerShell = $PowerShell
            Handle = $PowerShell.BeginInvoke()
        }
    ))
}
While ($jobs.handle.IsCompleted -eq $False) {
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 100
}