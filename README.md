## About

This is a very first alpha version of a PowerShell backup/restore module for Qlik Sense.

Please note that it needs testing before using in production environment!

Documentation and examples will be improved on soon!

It is **NOT** finished!

## Installation
The module can be installed by copying the Qlik-Snapshot.psm1 file to C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Qlik-Snapshot\, the module will then be loaded and ready to use from the PowerShell console. You can also load the module using the Import-Module command.
```sh
Import-Module Qlik-Snapshot.psm1
```
Once the module is loaded you can view a list of available commands by using the Get-Help PowerShell command.
```sh
Get-Help Qlik
```

##Usage

The following commands are made available after the module has been loaded.

```sh
PS C:\Temp> Get-Help Qlik

Name                              Category  Module                    Synopsis
----                              --------  ------                    --------
Restore-QlikState                 Function  Qlik-Snapshot             ...
Remove-QlikState                  Function  Qlik-Snapshot             ...
Find-QlikState                    Function  Qlik-Snapshot             ...
Backup-QlikState                  Function  Qlik-Snapshot             ...
```

The idea is that it should both be simple to get started and to use. If a ```Backup-QlikState``` command is issued a folder called **Snapshots** will be created in the current work directory. This folder and all snapshots which will be created below it can be copied or moved, both on the same server but also to another server if desired.

The other commands works in the same manner, ```Restore-QlikState```will look for the **Snapshots** folder in the current directory, and so will ```Find-QlikState``` and ```Remove-QlikState``` as well.

####Backup-QlikState

```sh
PS C:\Temp> Get-Help Backup-QlikState

NAME
    Backup-QlikState

SYNTAX
    Backup-QlikState [[-Label] <string>] [[-SenseDataFolder] <string>] [[-CertExportPWD] <string>] [[-PostgresBin]
    <string>] [[-PostgresConf] <string>] [[-PostgresLocation] <string>] [[-PostgresAccount] <string>] [[-PostgresPort]
    <string>] [[-PostgresDB] <string>] [[-IncludeArchivedLogs]] [[-Silent]]  [<CommonParameters>]
```

####Restore-QlikState

```sh
PS C:\Temp> Get-Help Restore-QlikState

NAME
    Restore-QlikState

SYNTAX
    Restore-QlikState [[-Number] <int>] [[-SenseDataFolder] <string>] [[-CertExportPWD] <string>] [[-PostgresBin]
    <string>] [[-PostgresConf] <string>] [[-PostgresLocation] <string>] [[-PostgresAccount] <string>] [[-PostgresPort]
    <string>] [[-PostgresDB] <string>] [[-IncludeArchivedLogs]] [[-Silent]]  [<CommonParameters>]
```

####Find-QlikState

```sh
PS C:\Temp> Get-Help Find-QlikState

NAME
    Find-QlikState

SYNTAX
    Find-QlikState [[-Label] <string>]  [<CommonParameters>]
```

####Remove-QlikState

```sh
PS C:\Temp> Get-Help Remove-QlikState

NAME
    Remove-QlikState

SYNTAX
    Remove-QlikState [[-Number] <int>] [[-Silent]]  [<CommonParameters>]
```
