Param(
    [Parameter(Position=0,mandatory=$true)]
    [string]$settingsFile
) 

$settings = Get-Content $settingsFile | Out-String | ConvertFrom-Json
$sqlServer = $settings.sqlServer
$fhirServer = $settings.fhirServer
$dbName = $settings.dbName
$requestBodyFile = $settings.requestBodyFile

$credential = Get-Credential -Message "Please enter credential for sql admin:"

function Install-Prerequisite {
    Write-Host "- Check Prerequisite:"

    if (Get-Module -ListAvailable -Name SqlServer) {
        Write-Host "`t- SQL Already Installed"
    } 
    else {sdf
        try {
            Install-Module -Name SqlServer -AllowClobber -Confirm:$False -Force  
            Write-Host "- SQL was installed successfully."
        }
        catch [Exception] {
            $_.message 
            exit
        }
    }
}

function Clean-Database {
    Param($credential) 

    Invoke-Sqlcmd -ServerInstance $sqlServer -Database $dbName -Credential $credential -InputFile ".\cleandb.sql"
    Write-Host "- Clean database completed."
}

function Start-ImportOperation {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/fhir+json")
    $headers.Add("Prefer", "respond-async")

    $body = Get-Content -Path $requestBodyFile
    $response = Invoke-WebRequest "$fhirServer/`$import" -Method "POST" -Headers $headers -Body $body

    if ($response.StatusCode -ne 202) {
        throw "Import operation failed to start. $response"
    }

    Write-Host "- Import operation started: $($response.Headers['Content-Location'])"
    return $response.Headers['Content-Location']
}

function Wait-ImportComplete {
    Param($statusLocation) 

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/fhir+json")
    $headers.Add("Prefer", "respond-async")

    while ((Invoke-WebRequest $statusLocation -Method "GET" -Headers $headers).StatusCode -eq 202) {
        $orchestratorTask = Invoke-Sqlcmd -ServerInstance $sqlServer -Database $dbName -Credential $credential -Query "select TaskId, Status, JSON_VALUE(TaskContext, '$.Progress') as Progress from TaskInfo where TaskTypeId = 2 order by HeartbeatDateTime desc"
        if (3 -eq $orchestratorTask['Progress']) {
            Write-Host "$(Get-Date): Importing resources to database (bulk copy):"
            $processingTasks = Invoke-Sqlcmd -ServerInstance $sqlServer -Database $dbName -Credential $credential -Query "select TaskId, Status, JSON_VALUE(TaskContext, '$.SucceedImportCount') as ImportedResourceCount from TaskInfo where TaskTypeId = 1 order by HeartbeatDateTime desc"
            $processingTasks | Format-Table
        }
        elseif (4 -eq $orchestratorTask['Progress']) {
            Write-Host "$(Get-Date): Post processing. (Remove duplicated resource. Rebuild indexes.)"
        }
        
        Start-Sleep -Seconds 10
    }

    Write-Host "$(Get-Date): Import operation completed."
}

function Calculate-Result {
    $orchestratorTask = Invoke-Sqlcmd -ServerInstance $sqlServer -Database $dbName -Credential $credential -Query "select TaskId, Status, HeartbeatDateTime as EndTime, JSON_VALUE(InputData, '$.TaskCreateTime') as StartTime from TaskInfo where TaskTypeId = 2 order by HeartbeatDateTime desc"
    $startTime = [Datetime]::Parse($orchestratorTask['StartTime']).ToUniversalTime()
    $endTime = $orchestratorTask['EndTime']
    $processingTaskEnd = (Invoke-Sqlcmd -ServerInstance $sqlServer -Database $dbName -Credential $credential -Query "select Top 1 HeartbeatDateTime from TaskInfo where TaskTypeId = 1 order by HeartbeatDateTime desc")[0]

    $durationInSec = ($endTime - $startTime).TotalSeconds
    $posrProcessingDurationInSec = ($endTime - $processingTaskEnd).TotalSeconds
    $resourceCount = (Invoke-Sqlcmd -ServerInstance $sqlServer -Database $dbName -Credential $credential -Query "select count(*) from Resource")[0]
    $qps = $resourceCount / $durationInSec

    Write-Host "- Result:"
    Write-Host "`t- Duration(sec): $durationInSec"
    Write-Host "`t- Post processing duration(sec): $posrProcessingDurationInSec"
    Write-Host "`t- Total resources: $resourceCount"
    Write-Host "`t- Throughput: $qps resources/s"
}

Install-Prerequisite
Clean-Database -credential $credential
$statusLocation = Start-ImportOperation
Wait-ImportComplete -statusLocation $statusLocation
Calculate-Result