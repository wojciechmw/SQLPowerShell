
<#PSScriptInfo

.VERSION 1.0

.GUID 7fcee308-eb41-4076-a62b-3457abb72e08

.AUTHOR Wojciech Wojtulewski

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>


<# 

.DESCRIPTION 
 PowerShell functions for SQL server 

#> 
Param()


[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null 
Add-Type -Assembly System.IO.Compression.FileSystem
<#
 .SYNOPSIS
    Generate scripts for all objects in the SQL server database

 .DESCRIPTION
    The function allows generating SQL scripts for all objects in the SQL databases.
 
 .PARAMETER dbName
    Database name or empty if all databases

 .PARAMETER serverName
    SQL server name, this is a mandatory parameter

 .PARAMETER trustedConnection
    Set to true if Trusted connection, default set to true

 .PARAMETER user
    SQL Server username

 .PARAMETER password
    SQL Server user password

 .PARAMETER objectType
    Type of object to scripting (all, tables, views, procedures, functions)

 .PARAMETER startDate
    Modification date

 .PARAMETER increaseDays
    Numbers of days back when an object was modified, if 0 ignore startDate

 .PARAMETER outputPath 
    Destination folder, default user document folder

 .PARAMETER compress
    Compress output files

 .PARAMETER delete
    Delete files after compressed, works only if compressed set on true

.EXAMPLE
#Get all views for all databases, using trusted connection
Get-SQLObjectScripts -serverName "SQLEXPRESS" -objectType "views" -increaseDays 0

#>

function Get-SqlObjectScripts
{
    Param
    (
        [string]$dbname="",
        [Parameter(Mandatory=$true)]
        [string]$serverName="",
        [bool]$trustedConnection=$true,
        [string]$user="",
        [String]$password="",
        [ValidateSet("all","tables","views","procedures","functions")] [string]$objectType="all",
        [datetime]$startDate=(Get-Date -UFormat "%D"),
        [int]$increaseDays=7,
        [string]$outputPath="",
        [bool]$compress=$false,
        [bool]$delete=$false
    )
    Process 
    {

        $increaseDays=$increaseDays* -1
        $srv=New-Object ('Microsoft.SqlServer.Management.Smo.Server') $serverName
        $srv.ConnectionContext.LoginSecure=$trustedConnection
        if(!$trustedConnection)
        {
            $srv.ConnectionContext.Login=$user
            $srv.ConnectionContext.Password=$password #ConvertFrom-SecurString -SecureString $password
        }
        $dbs=$srv.Databases
        if($outputPath -eq "")
        {
            $outputPath=[Environment]::GetFolderPath("MyDocuments")+"\SqlScripts"
        }
        if(-Not (CheckPath -path $outputPath))
        {
            return
        }

        foreach($db in $dbs)
        {
            [bool]$processing=$false
            if(($dbname -ne "") -and ($db.Name -eq $dbname))
            {
                $processing=$true
            }
            else 
            {
                if(($db.Name -eq "msdb") -or ($db.Name -eq "master") -or ($db.Name -eq "model") -or ($db.Name -eq "tempdb"))
                {
                    $processing=$false
                }
                elseif($dbname -eq "")
                {
                    $processing=$true
                }
                else 
                {
                    $processing=$false
                }
            }
            if($processing)
            {
                $dbpath=$outputPath+"\"+$dbname

                [string[]]$folders=@("tables","views","indexes","procedures","functions","triggers","ForeignKey")
                if(-Not (CreateEnvironment -path $dbpath -subpaths $folders))
                {
                    return
                }
                if(($objectType -eq "all") -or ($objectType -eq "tables"))
                {
                    
                    foreach($table in $dbs[$db.Name].Tables)
                    {
                        if(($table.Schema -ne "sys") -and ($table.Schema -ne "information_schema"))
                        {
                            if(($table.DateLastModified -gt (Get-Date).AddDays($increaseDays)) -or ($increaseDays -eq 0))
                            {
                                $filename=$dbpath+"\tables\"+$table.Schema+"_"+$table.Name+".sql"
                                $table.Script()|out-File $filename
                            }
                            foreach($index in $table.Indexes)
                            {
                                if(($index.DateLastModified -gt (Get-Date).AddDays($increaseDays)) -or ($increaseDays -eq 0))
                                {
                                    $filename=$dbpath+"\indexes\"+$table.Schema+"_"+$table.Name+"_"+$index.Name+".sql"
                                    $index.Script()|out-File $filename
                                }
                            }
                            foreach($trigger in $table.Triggers)
                            {
                                if(($trigger.DateLastModified -gt (Get-Date).AddDays($increaseDays)) -or ($increaseDays -eq 0))
                                {
                                    $filename=$dppath+"\triggers\"+$table.Schema+"_"+$table.Name+"_"+$trigger.Name+".sql"
                                    $trigger.Script()|out-File $filename
                                }
                            }
                        }
                    }
                }
                if(($objectType -eq "all") -or ($objectType -eq "views"))
                {
                    foreach($view in $dbs[$db.Name].Views)
                    {
                        if(($view.Schema -ne "sys") -and ($view.Schema -ne "information_schema"))
                        {
                            if(($view.DateLastModified -gt (Get-Date).AddDays($increaseDays)) -or ($increaseDays -eq 0))
                            {
                                $filename=$dbpath+"\views\"+$view.Schema+"_"+$view.Name+".sql"
                                $view.Script()|out-File $filename
                            }
                        }
                    }
                }
                if(($objectType -eq "all") -or ($objectType -eq "procedures"))
                {
                    foreach($procedure in $dbs[$db.Name].Procedures)
                    {
                        if(($procedure.Schema -ne "sys") -and ($procedure.Schema -ne "information_schema"))
                        {
                            if(($procedure.DateLastModified -gt (Get-Date).AddDays($increaseDats)) -or ($increaseDays -eq 0))
                            {
                             $filename=$dbpath+"\procedures\"+$procedure.Schema+"_"+$procedure.Name+".sql"
                             $procedure.Script()|out-file $filename
                            }
                        }
                    }
                }
                if(($objectType -eq "all") -or ($objectType -eq "functions"))
                {
                    foreach($function in $dbs[$db.Name].Functions)
                    {
                        if(($function.Schema -ne "sys" ) -and ($function.Schema -ne "information_schema"))
                        {
                            $filename=$dppath+"\functions\"+$function.Schema+"_"+$function.Name+".sql"
                            $function.Script()|out-File $filename
                        }
                    }
                }
                if($compresse)
                {
                    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
                    $cfile=$outputPath+"\"+$dbname+"_"+(Get-Date).ToString("MMMMyyyy")+".zip"
                    [System.IO.Compression.ZipFile]::CreateFromDirectory($dbpath,$cfile,$compressionLevel,$false)
                    if($delete)
                    {
                        Remove-Item -Path $dbpath -Recurse -Force
                    }
                }
            }
            

        }

    }
}

function Private:CheckPath 
{
    Param
    (
        [string]$path=""
    )
    Process
    {
        if($path -eq "")
        {
            Write-Error "CheckPath: Invalid parameter value"
            return $false 
        }
        if(-Not (Test-Path $path))
        {
            try 
            {
                New-Item $path -ItemType "directory"
            }
            catch 
            {
                $msg="CheckPath: " + $_
                Write-Error $msg
                return $false
            }
        }
        else 
        {
            return $true
        }
    }
}
<#

#>
function Private:CreateEnvironment
{
    Param
    (
        [string]$path,
        [string[]]$subpaths
        
    )
    Process 
    {
        if(($subpaths.Count -eq 0) -or ($path -eq ""))
        {
            Write-Error "CreateEnvironment: Invalid parameter value"
            return $false
        }
        foreach($sub in $subpaths)
        {
            $tmp=$path+"\"+$sub
            if(-Not (CheckPath -path $tmp))
            {
                return $false
            }
        }
        return $true
    }
}



