Function Format-DbaBackupInformation{
    <#
    .SYNOPSIS
        Transforms the data in a dbatools backuphistory object for a restore
    
    .DESCRIPTION
       Performs various mapping on Backup History, ready restoring
       Options include changing restore paths, backup paths, database name and many others
    
    .PARAMETER BackupHistory

    .PARAMETER ReplaceDatabasName
        If a single value is provided, this will be replaced do all occurences a database name
        If a Hashtable is passed in, each database name mention will be replaced as specified. If a database's name does not apper it will not be replace
        DatabaseName will also be replaced where it  occurs in the file paths of data and log files.
        Please note, that this won't change the Logical Names of datafiles, that has to be done with a seperate Alter DB call
    
    .PARAMETER DatabaseNamePrefix
        This string will be prefixed to all restored database's name 
        
    .PARAMETER DataFileDirectory
        This will move ALL restored files to this location during the restore

    .PARAMETER LogFileDirectory
        This will move all log files to this location. 
    
    .PARAMETER FileNamePrefix
        This string will  be prefixed to all restored files (Data and Log)

    .PARAMETER RebaseBackupFolder
        Use this to rebase where your backups are stored. 

    .EXAMPLE
        $History | Format-DbaBackupInformation -ReplaceDatabaseName NewDb

    .EXAMPLE
        $History | Format-DbaBackupInformation -ReplaceDatabaseName @{'OldB'='NewDb';'ProdHr'='DevPr'}   
    
    .EXAMPLE
        $History | Format-DbaBackupInformation -DataFileDirectory 'D:\DataFiles\' -LogFileDirectory 'E:\LogFiles\
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$BackupHistory,
        [object]$ReplaceDatabaseName,
        [string]$DataFileDirectory,
        [string]$LogFileDirectory,
        [string]$DatabaseNamePrefix,
        [string]$DatabaseFilePrefix,
        [string]$DatabaseFileSuffix,
        [string]$RebaseBackupFolder,
        [switch]$EnableException
    )
    Begin{
        
        Write-Message -Message "Starting" -Level Verbose
        if ($ReplaceDatabaseName -is [string]){
            Write-Message -Message "String passed in for DB rename" -Level Verbose
            $ReplaceDatabaseNameType = 'single'
        }
        elseif ($ReplaceDatabaseName -is [HashTable]) {
            Write-Message -Message "Hashtable passed in for DB rename" -Level Verbose
            $ReplaceDatabaseNameType='multi'
        }
        if ($DataFileDirectory[-1] -eq '\' ){
            $DataFileDirectory = $DataFileDirectory.substring(0,$DataFileDirectory.length-1)
        }
        if ($LogFileDirectory[-1] -eq '\' ){
            $LogFileDirectory = $LogFileDirectory.substring(0,$LogFileDirectory.length-1)
        }
        if ($RebaseBackupFolder[-1] -eq '\' ){
            $RebaseBackupFolder = $RebaseBackupFolder.substring(0,$RebaseBackupFolder.length-1)
        }
    }


    Process{
        
        ForEach ($History in $BackupHistory){
             if ("OriginalDatabase" -notin $History.PSobject.Properties.name){
                $History | Add-Member -Name 'OriginalDatabase' -Type NoteProperty -Value $History.Database
             }
             if ("OriginalFileList" -notin $History.PSobject.Properties.name){
                $History | Add-Member -Name 'OriginalFileList' -Type NoteProperty -Value ''
                $History | ForEach-Object {$_.OriginalFileList = $_.FileList}
             }
             if ("OriginalFullName" -notin $History.PSobject.Properties.name){
                $History | Add-Member -Name 'OriginalFullName' -Type NoteProperty -Value $History.FullName
             }
            if ($ReplaceDatabaseNameType -eq 'single'){
                $History.Database = $ReplaceDatabaseName
                $ReplaceMentName = $ReplaceDatabaseName
                Write-Message -Message "New DbName (String) = $($History.Database)" -Level Verbose
            }elseif ($ReplaceDatabaseNameType -eq 'multi'){
                if ($null -ne $ReplaceDatabaseName[$History.Database]){
                    $History.Database = $ReplaceDatabaseName[$History.Database]
                    $ReplacementName = $ReplaceDatabaseName[$History.Database]
                    Write-Message -Message "New DbName (Hash) = $($History.Database)" -Level Verbose
                }
            }
            $History.Database = $DatabaseNamePrefix+$History.Database
            $History.FileList | ForEach-Object {
                $_.PhysicalName = $_.PhysicalName -Replace $History.OriginalDatabase, $ReplacementName
                Write-message -Message " 1 PhysicalName = $($_.PhysicalName) " -Level Verbose
                $Pname = [System.Io.FileInfo]$_.PhysicalName
                $RestoreDir = $Pname.DirectoryName
                if ($_.Type -eq 'D'){
                    if ('' -ne $DataFileDirectory){
                        $RestoreDir = $DataFileDirectory
                    }
                }elseif ($_.Type -eq 'L'){
                    if ('' -ne $LogFileDirectory){
                        $RestoreDir = $LogFileDirectory
                    }
                    elseif ('' -ne $DataFileDirectory){
                        $RestoreDir = $DataFileDirectory
                    }
                }
                
                $_.PhysicalName = $RestoreDir+"\"+$DatabaseFilePrefix+$Pname.BaseName+$DatabaseFileSuffix+$pname.extension
                Write-message -Message "PhysicalName = $($_.PhysicalName) " -Level Verbose
            }
            if ($null -ne $RebaseBackupFolder){
                $History.FullName | ForEach-Object{
                    $file = [System.IO.FileInfo]$_
                    $_ = $RebaseBackupFolder+"\"+$file.BaseName+$file.Extension
                }
            }
            $History   
        }
    }

    End{
       
    }
}