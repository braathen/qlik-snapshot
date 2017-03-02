$nl = [Environment]::NewLine

#function ExecuteDbTools($exe, $commands) {
#  Push-Location $params.PostgresBin
#  $result = Start-Process -FilePath $exe -ArgumentList "$($commands)" -NoNewWindow
#  Pop-Location
#  if ($LastExitCode -ne 0) {
#    Write-Host $result
#    Break
#  }
#  return $result
#}

function QueryDatabase($params, $sql) {
  Push-Location $params.PostgresBin
  $result = .\psql -qtA -h $params.PostgresLocation -p $params.PostgresPort -U $params.PostgresAccount -d $params.PostgresDB -c $sql
  Pop-Location
  if ($LastExitCode -ne 0) {
    Write-Host $result
    Break
  }
  return $result
#  return ExecuteDbTools ".\psql" "-qtA -h $($params.PostgresLocation) -p $($params.PostgresPort) -U $($params.PostgresAccount) -d $($params.PostgresDB) -c $sql"
}

function DropDatabase($params) {
  Push-Location $params.PostgresBin
  $result = .\dropdb -h $params.PostgresLocation -p $params.PostgresPort -U $params.PostgresAccount $params.PostgresDB
  Pop-Location
  if ($LastExitCode -ne 0) {
    Write-Host $result
    Break
  }
  return $result
}

function CreateDatabase($params) {
  Push-Location $params.PostgresBin
  $result = .\createdb -h $params.PostgresLocation -p $params.PostgresPort -U $params.PostgresAccount -T template0 $params.PostgresDB
  Pop-Location
  if ($LastExitCode -ne 0) {
    Write-Host $result
    Break
  }
  return $result
}

function RestoreDatabase($params, $file) {
  Push-Location $params.PostgresBin
  $result = .\pg_restore.exe -h $params.PostgresLocation -p $params.PostgresPort -U $params.PostgresAccount -d $params.PostgresDB $file
  Pop-Location
  if ($LastExitCode -ne 0) {
    Write-Host $result
    Break
  }
  return $result
}

function BackupDatabase($params, $filename) {
  Write-Host "$($nl)Backing up database..."
  Push-Location $params.PostgresBin
  $result = .\pg_dump.exe -h $params.PostgresLocation -p $params.PostgresPort -U $params.PostgresAccount  -o -b -F t -f $filename $params.PostgresDB
  Pop-Location
  if ($LastExitCode -ne 0) {
    Write-Host $result
    Break
  }
}

function GetCertificate($store) {
  $certStore = Get-Item "cert:\$store"
  $certStore.Open("ReadOnly")
  $certs = $certStore.Certificates.Find("FindByExtension", "1.3.6.1.5.5.7.13.3", $false)
  return $certs.ThumbPrint  
}

function PromptUser($title, $message, $yesprompt, $noprompt, $silent) {
  if (-Not $silent) {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", $yesprompt
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", $noprompt
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    return $host.ui.PromptForChoice($title, $message, $options, 0)
  } else {
      return 0
  }
}

function PromptForNumber($max) {
  $number = 0
  $inputOK = $false
  do {
    try {
      [int]$number = Read-Host "[1-$max] Number"
      if ($number -ge 1 -and $number -le $max) {
        $inputOK = $true
      }
    }
    catch {
    } 
  }
  until ($inputOK)
  return $number
}

function GetSnapshots($Number) {
  Get-ChildItem -Path $(Join-Path $pwd -ChildPath "Snapshots") -Recurse -Include settings.json -ErrorAction SilentlyContinue | ForEach-Object { $counter = 0; $snapshots = @() } {
    $counter++
    $settings = (Get-Content $_ -Encoding UTF8) -join "`n" | ConvertFrom-Json
    $date = ([regex]::matches($_, "(?<=Snapshots\\)(.*)(?=\\settings)") | %{$_.value})
    $snapshots += @{No=$($counter.ToString("00")); Snapshot=$date; Label=$settings.Label; HostName=$settings.HostName}
  }
  if($counter -eq 0) {
    Write-Host "No snapshots found in current location"
    Break
  }
  return $snapshots
}

function SelectedSnapshot($settingsPath, $SelectedSnapshot) {
  $settings = (Get-Content $(Join-Path $settingsPath -ChildPath "settings.json") -Encoding UTF8) -join "`n" | ConvertFrom-Json
  Write-Host "$($nl)Selected snapshot"
  Write-Host "-----------------"
  Write-Host "Snapshot: $($SelectedSnapshot)"
  Write-Host "Label: $($settings.Label)"
  Write-Host "HostName: $($settings.HostName)"
  return $settings
}

function IsAdministrator() {
  If (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {    
    Write-Host "This command needs to be run as Administrator"
    Break
  }  
}

function StopServices() {
  Write-Host "$($nl)Stopping services..."
  Get-Service QlikSense* | Where {$_.Status -eq 'running' -and $_.Name -ne 'QlikSenseRepositoryDatabase' } | Stop-Service -Force
  Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -Match 'Engine|Repository|Scheduler|ServiceDispatcher'} | Stop-Process -Force
}

function StartServices() {
  Write-Host "$($nl)Starting services..."
  Get-Service QlikSense* | Foreach { Start-Service $_.Name -PassThru; }
}

### BACKUP ### 

function Backup-QlikState {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$false,Position=0)]
    [string]$Label = "n/a",
    [parameter(Mandatory=$false,Position=1)]
    [string]$SenseDataFolder = "$env:ProgramData\Qlik",
    [parameter(Mandatory=$false,Position=2)]
    [string]$CertExportPWD = "QlikSense",
    [parameter(Mandatory=$false,Position=3)]
    [string]$PostgresBin = "$env:ProgramFiles\Qlik\Sense\Repository\PostgreSQL\9.3\bin",
    [parameter(Mandatory=$false,Position=4)]
    [string]$PostgresConf = "$SenseDataFolder\Sense\Repository\PostgreSQL\9.3",
    [parameter(Mandatory=$false,Position=5)]
    [string]$PostgresLocation = "localhost",
    [parameter(Mandatory=$false,Position=6)]
    [string]$PostgresAccount = "postgres",
    [parameter(Mandatory=$false,Position=7)]
    [string]$PostgresPort = "4432",
    [parameter(Mandatory=$false,Position=8)]
    [string]$PostgresDB = "QSR",
    [parameter(Mandatory=$false,Position=9)]
    [switch]$IncludeArchivedLogs,
    [parameter(Mandatory=$false,Position=10)]
    [switch]$Silent
  )

  PROCESS {
    $params = @{
      CertExportPWD       = "$CertExportPWD";
      SenseDataFolder     = "$SenseDataFolder";
      PostgresBin         = "$PostgresBin";
      PostgresConf        = "$PostgresConf";
      PostgresLocation    = "$PostgresLocation";
      PostgresAccount     = "$PostgresAccount";
      PostgresPort        = "$PostgresPort";
      PostgresDB          = "$PostgresDB";
      IncludeArchivedLogs = $IncludeArchivedLogs;
      Silent              = $Silent;
    }

    $settings = @{
      Label               = "$Label";
      Apps                = "$SenseDataFolder\Sense\Apps";
      StaticContent       = "$SenseDataFolder\Sense\Repository";
      ArchivedLogs        = "$SenseDataFolder\Sense\Archived Logs";
      CustomData          = "$SenseDataFolder\Custom Data";
      RootFolder          = "";
      DatabaseHost        = "";
      HostName            = "";
    }

    IsAdministrator

    # Qlik Sense certificates
    $RootCertName = GetCertificate "LocalMachine\Root"
    $Certificate = GetCertificate "LocalMachine\My"
    $ClientCert = GetCertificate "CurrentUser\My"

    # Get Shared persistence paths from database
    $settings.HostName = QueryDatabase $params 'SELECT \"HostName\" FROM \"LocalConfigs\";'
    $SPActive = QueryDatabase $params 'SELECT \"AppFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
    if ($SPActive -ne "") {
      $settings.Apps = $SPActive
      $settings.StaticContent = QueryDatabase $params 'SELECT \"StaticContentRootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
      $settings.ArchivedLogs = QueryDatabase $params 'SELECT \"ArchivedLogsRootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
      $settings.CustomData = QueryDatabase $params 'SELECT \"Connector64RootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
      $settings.RootFolder = QueryDatabase $params 'SELECT \"RootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
      $settings.DatabaseHost = QueryDatabase $params 'SELECT \"DatabaseHost\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
    }

    Write-Host "$($nl)Identified settings"
    Write-Host "-------------------"
    Write-Host "Root certificate: $RootCertName"
    Write-Host "Certificate: $Certificate"
    Write-Host "Client certificate: $ClientCert"
    Write-Host "Hostname: $($settings.HostName)"
    Write-Host "$($nl)Paths"
    Write-Host "-----"
    Write-Host $settings.Apps
    Write-Host $settings.StaticContent
    Write-Host $settings.CustomData
    if ($params.IncludeArchivedLogs) {
      Write-Host $settings.ArchivedLogs
    }

    # Set directories
    $homeDir = Join-Path $pwd -ChildPath "Snapshots"
    $backupDir = Join-Path $homeDir -ChildPath $(Get-Date -Format "yyyyMMdd-HHmmss")

    $result = PromptUser 'BACKUP' 'Do you want to continue with backup?' 'Yes, start backup procedure' 'No, do not proceed with backup procedure' $params.Silent
    if ($result -eq 1) {
      Break
    }

    # Write setting.json to snapshot
    $settings | ConvertTo-Json -Depth 5 | New-Item -Force -Path $(Join-Path $backupDir -ChildPath "settings.json") -Type file | Out-Null

    # Backup content
    robocopy $settings.Apps "$backupDir\Apps" /mir /NP /NJH /NJS /R:10 /w:3
    robocopy $settings.StaticContent "$backupDir\StaticContent" /XD "Exported Certificates" "Archived Logs" "PostgreSQL" "TempContent" "Transaction Logs" "DefaultExtensionTemplates" "DefaultApps" /S /NP /NJH /NJS /R:10 /w:1
    robocopy $settings.CustomData "$backupDir\CustomData" /NP /NJH /NJS /R:10 /w:3
    if ($params.IncludeArchivedLogs) {
      robocopy $settings.ArchivedLogs "$backupDir\ArchivedLogs" /NP /NJH /NJS /R:10 /w:1
    }

    # Backup database configuration, host.cfg and certificates
    robocopy "$($params.PostgresConf)" "$backupDir\DatabaseConfig" *.conf /NP /NJH /NJS /R:10 /w:3
    robocopy "$($params.SenseDataFolder)\Sense" "$backupDir" Host.cfg /NP /NJH /NJS /R:10 /w:3
    robocopy "$($params.SenseDataFolder)\Sense\Repository\Exported Certificates" "$backupDir\ExportedCertificates" /S /NP /NJH /NJS /R:10 /w:3

    #if($LastExitCode -ne 0) {
    #  Write-Host "An error occured during file copy..."
    #  Break
    #}

    # Backup postgres database
    BackupDatabase $params "$backupDir\Database.tar"

    # Backup exported certificates
    if ($RootCertName) { certutil -f -p $params.CertExportPWD -exportpfx -privatekey Root $RootCertName "$backupDir\root.pfx" }
    if ($Certificate) { certutil -f -p $params.CertExportPWD -exportpfx  MY $Certificate "$backupDir\server.pfx" }
    if ($ClientCert) { certutil -f -p $params.CertExportPWD -exportpfx -user MY $ClientCert "$backupDir\client.pfx" NoRoot }
  }
}

### RESTORE ### 

function Restore-QlikState {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$false,Position=0)]
    [int]$Number = 0,
    [parameter(Mandatory=$false,Position=1)]
    [string]$SenseDataFolder = "$env:ProgramData\Qlik",
    [parameter(Mandatory=$false,Position=2)]
    [string]$CertExportPWD = "QlikSense",
    [parameter(Mandatory=$false,Position=3)]
    [string]$PostgresBin = "$env:ProgramFiles\Qlik\Sense\Repository\PostgreSQL\9.3\bin",
    [parameter(Mandatory=$false,Position=4)]
    [string]$PostgresConf = "$SenseDataFolder\Sense\Repository\PostgreSQL\9.3",
    [parameter(Mandatory=$false,Position=5)]
    [string]$PostgresLocation = "localhost",
    [parameter(Mandatory=$false,Position=6)]
    [string]$PostgresAccount = "postgres",
    [parameter(Mandatory=$false,Position=7)]
    [string]$PostgresPort = "4432",
    [parameter(Mandatory=$false,Position=8)]
    [string]$PostgresDB = "QSR",
    [parameter(Mandatory=$false,Position=9)]
    [switch]$IncludeArchivedLogs,
    [parameter(Mandatory=$false,Position=10)]
    [switch]$IgnoreFiles,
    [parameter(Mandatory=$false,Position=11)]
    [switch]$Silent
  )

  PROCESS {
    $params = @{
      CertExportPWD       = "$CertExportPWD";
      SenseDataFolder     = "$SenseDataFolder";
      PostgresBin         = "$PostgresBin";
      PostgresConf        = "$PostgresConf";
      PostgresLocation    = "$PostgresLocation";
      PostgresAccount     = "$PostgresAccount";
      PostgresPort        = "$PostgresPort";
      PostgresDB          = "$PostgresDB";
      IncludeArchivedLogs = $IncludeArchivedLogs;
      Silent              = $Silent;
    }

    $settings = @{
      Label               = "$Label";
      Apps                = "$SenseDataFolder\Sense\Apps";
      StaticContent       = "$SenseDataFolder\Sense\Repository";
      ArchivedLogs        = "$SenseDataFolder\Sense\Archived Logs";
      CustomData          = "$SenseDataFolder\Custom Data";
      RootFolder          = "";
      DatabaseHost        = "";
      HostName            = "";
    }

    IsAdministrator

    # Select snapshot
    $snapshots = GetSnapshots
    if(-Not ($Number -ge 1 -and $Number -le $snapshots.length)) {
      Write-Output $snapshots | % { New-Object PSObject -Property $_} | Format-Table
      $Number = PromptForNumber $snapshots.length
    }
    $SelectedSnapshot = $snapshots[$Number-1].Snapshot

    # Set directories
    $homeDir = Join-Path $pwd -ChildPath "Snapshots"
    $restoreDir = Join-Path $homeDir -ChildPath $SelectedSnapshot

    # Get settings from snapshot
    $settings = SelectedSnapshot $restoreDir $SelectedSnapshot
    $result = PromptUser 'RESTORE' 'Do you want to restore the above snapshot?' 'Yes, start restore procedure' 'No, do not proceed with restore procedure' $params.Silent
    if ($result -eq 1) {
      Break
    }

    # Set write access and terminate all connections
    #$result = QueryDatabase $params ('begin; set transaction read write; alter database \"{0}\" set default_transaction_read_only = off; commit;' -f $params.PostgresDB)
    $result = QueryDatabase $params ("SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '{0}' AND pid <> pg_backend_pid();" -f $params.PostgresDB)

    StopServices

    Write-Host "$($nl)Restoring database..."

    # begin restore process
    DropDatabase $params
    CreateDatabase $params
    RestoreDatabase $params "$restoreDir\Database.tar"

    if(-Not $IgnoreFiles) {
      Write-Host  "$($nl)Restoring files..."
      robocopy "$backupDir\Apps" $settings.Apps /mir /NP /NJH /NJS /R:10 /w:3
      robocopy "$backupDir\StaticContent" $settings.StaticContent /S /NP /NJH /NJS /R:10 /w:3
      robocopy "$backupDir\CustomData" $settings.CustomData /S /NP /NJH /NJS /R:10 /w:3
      if ($params.IncludeArchivedLogs) {
        robocopy "$backupDir\ArchivedLogs" $settings.ArchivedLogs /S /NP /NJH /NJS /R:3 /w:1
      }

      robocopy "$($params.PostgresConf)" "$backupDir\DatabaseConfig" *.conf /NP /NJH /NJS /R:10 /w:3
      robocopy "$($params.SenseDataFolder)\Sense" "$backupDir" Host.cfg /NP /NJH /NJS /R:10 /w:3
      robocopy "$($params.SenseDataFolder)\Sense\Repository\Exported Certificates" "$backupDir\ExportedCertificates" /S /NP /NJH /NJS /R:10 /w:3
    }

    $SPActive = QueryDatabase $params 'SELECT \"AppFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\";'
    if ($SPActive -ne "") {
      Write-Host "$($nl)Writing settings to database..."
      #$result = QueryDatabase $params ('begin; set transaction read write; alter database \"{0}\" set default_transaction_read_only = off; commit;' -f $params.PostgresDB)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"AppFolder\" = \"{0}\"; commit;' -f $settings.Apps)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"StaticContentRootFolder\" = \"{0}\"; commit;' -f $settings.StaticContent)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"Connector64RootFolder\" = \"{0}\"; commit;' -f $settings.CustomData)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"Connector32RootFolder\" = \"{0}\"; commit;' -f $settings.CustomData)
      #$result = QueryDatabase $params ('begin;Update \"LocalConfigs\" SET \"HostName\" = \"{0}\"; commit;' -f $settings.HostName)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"RootFolder\" = \"{0}\"; commit;' -f $settings.RootFolder)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"ArchivedLogsRootFolder\" = \"{0}\"; commit;' -f $settings.ArchivedLogs)
      $result = QueryDatabase $params ('begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"DatabaseHost\" = \"{0}\"; commit;' -f $settings.DatabaseHost)
    }

    StartServices
  }
}

### REMOVE ### 

function Remove-QlikState {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$false,Position=0)]
    [int]$Number = 0,
    [parameter(Mandatory=$false,Position=1)]
    [switch]$Silent
  )

  PROCESS {
    $params = @{
      Silent = $Silent;
    }

    IsAdministrator
    
    # Select snapshot
    $snapshots = GetSnapshots
    if(-Not ($Number -ge 1 -and $Number -le $snapshots.length)) {
      Write-Output $snapshots | % { New-Object PSObject -Property $_} | Format-Table
      $Number = PromptForNumber $snapshots.length
    }
    $SelectedSnapshot = $snapshots[$Number-1].Snapshot

    # Set directories
    $homeDir = Join-Path $pwd -ChildPath "Snapshots"
    $removeDir = Join-Path $homeDir -ChildPath $SelectedSnapshot

    # Get settings from snapshot
    $settings = SelectedSnapshot $removeDir $SelectedSnapshot
    $result = PromptUser 'REMOVE' 'Do you want to remove the above snapshot?' 'Yes, remove snapshot' 'No, do not remove snapshot' $params.Silent
    if ($result -eq 1) {
      Break
    }

    Write-Host "$($nl)Removing $removeDir"
    Remove-Item -Recurse -Force $removeDir
  }
}

### FIND ### 

function Find-QlikState {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$false,Position=0)]
    [string]$Label
  )

  PROCESS {

    IsAdministrator

    $snapshots = GetSnapshots

    Write-Output $snapshots | % { New-Object PSObject -Property $_} | Format-Table
  }
}
