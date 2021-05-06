$input_file = "C:\LogRhythm\Scripts\LR-AnalyzeLPS\lps_files.json"

$regex_1 = "Log Source Type\:\s+(?<logsourcetype>.*)"
$regex_2 = "MPE Policy\:\s+(?<mpe>.*)"
$regex_3 = "Total Compares\:\s+(?<compares>.*)"
$regex_4 = "LPS\-Policy\-Total\:\s+(?<lps>.*)"
$regex_5 = "Mediator ID\s+(?<mediatorid>\d+)"
$regex_6 = "Mediator Version\s+(?<mediatorversion>[\d\.]+)"
$regex_7 = "Stat Collection Start\s+(?<start>\d{2}\-\d{2}\-\d{4}\s+\d{2}\:\d{2}\s+\w{2})"
$regex_8 = "Stat Collection End\s+(?<stop>\d{2}\-\d{2}\-\d{4}\s+\d{2}\:\d{2}\s+\w{2})"

$dps = Get-content $input_file -Raw | ConvertFrom-Json
$logfile = $dps.config.logfile
$globallogleve = $dps.config.loglevel

Function Write-Log {  

    # This function provides logging functionality.  It writes to a log file provided by the $logfile variable, prepending the date and hostname to each line
    # Currently implemented 4 logging levels.  1 = DEBUG / VERBOSE, 2 = INFO, 3 = ERROR / WARNING, 4 = CRITICAL
    # Must use the variable $globalloglevel to define what logs will be written.  1 = All logs, 2 = Info and above, 3 = Warning and above, 4 = Only critical.  If no $globalloglevel is defined, defaults to 2
    # Must use the variable $logfile to define the filename (full path or relative path) of the log file to be written to
    # Auto-rotate feature written but un-tested
           
    [CmdletBinding()]
    Param([Parameter(Mandatory = $true)] [string]$logdetail,
        [Parameter(Mandatory = $false)] [int32]$loglevel = 2
    )
    if (($globalloglevel -ne 1) -and ($globalloglevel -ne 2) -and ($globalloglevel -ne 3) -and ($globalloglevel -ne 4)) {
        $globalloglevel = 2
    }

    if ($loglevel -ge $globalloglevel) {
        try {
            $logfile_exists = Test-Path -Path $logfile
            if ($logfile_exists -eq 1) {
                if ((Get-Item $logfile).length/1MB -ge 10) {   # THIS IS THE LOG ROTATION CODE --- UNTESTED!!!!!
                    $logfilename = ((Get-Item $logdetail).Name).ToString()
                    $newfilename = "$($logfilename)"+ (Get-Date -Format "yyyymmddhhmmss").ToString()
                    Rename-Item -Path $logfile -NewName $newfilename
                    New-Item $logfile -ItemType File
                    $this_Date = Get-Date -Format "MM\/dd\/yyyy hh:mm:ss tt"
                    Add-Content -Path $logfile -Value "$this_Date [$env:COMPUTERNAME] $logdetail"
                }
                else {
                    $this_Date = Get-Date -Format "MM\/dd\/yyyy hh:mm:ss tt"
                    Add-Content -Path $logfile -Value "$this_Date [$env:COMPUTERNAME] $logdetail"
                }
            }
            else {
                New-Item $logfile -ItemType File
                $this_Date = Get-Date -Format "MM\/dd\/yyyy hh:mm:ss tt"
                Add-Content -Path $logfile -Value "$this_Date [$env:COMPUTERNAME] $logdetail"
            }
        }
        catch {
            Write-Error "***ERROR*** An error occured writing to the log file: $_"
        }
    }
}


Function Get-LPSData ($lps_data) {

    $log_data = $lps_data

    $matches_1 = $log_data |  Select-String -Pattern $regex_1 -AllMatches
    $matches_2 = $log_data |  Select-String -Pattern $regex_2 -AllMatches
    $matches_3 = $log_data |  Select-String -Pattern $regex_3 -AllMatches
    $matches_4 = $log_data |  Select-String -Pattern $regex_4 -AllMatches


    $all_matches = @()
    For ($i=0; $i -le ($matches_1.Matches.Count -1); $i++) {
        $this_match = New-Object -TypeName psobject
        $this_match | Add-Member -MemberType NoteProperty -Name Index -Value ($i + 1)
        $this_match | Add-Member -MemberType NoteProperty -Name LogSourceType -Value $matches_1.Matches[$i].Groups[1].Value
        $this_match | Add-Member -MemberType NoteProperty -Name MPEPolicy -Value $matches_2.Matches[$i].Groups[1].Value
        $this_match | Add-Member -MemberType NoteProperty -Name TotalCompares -Value $matches_3.Matches[$i].Groups[1].Value
        $this_match | Add-Member -MemberType NoteProperty -Name LogsPerSecond -Value $matches_4.Matches[$i].Groups[1].Value
        $all_matches += $this_match
    }

    Return $all_matches
}

Function Get-Metadata ($lps_data) {
    
    $med_id = $lps_data |  Select-String -Pattern $regex_5 -AllMatches
    $med_ver = $lps_data |  Select-String -Pattern $regex_6 -AllMatches
    $collection_start = $lps_data |  Select-String -Pattern $regex_7 -AllMatches
    $collection_end = $lps_data |  Select-String -Pattern $regex_8 -AllMatches
    
    $dp_metadata = New-Object -TypeName psobject
    $dp_metadata | Add-Member -MemberType NoteProperty -Name MediatorID -Value $med_id.Matches[0].Groups[1].Value
    $dp_metadata | Add-Member -MemberType NoteProperty -Name MediatorVersion -Value $med_ver.Matches[0].Groups[1].Value
    $dp_metadata | Add-Member -MemberType NoteProperty -Name CollectionStartTime -Value $collection_start.Matches[0].Groups[1].Value
    $dp_metadata | Add-Member -MemberType NoteProperty -Name CollectionEndTime -Value $collection_end.Matches[0].Groups[1].Value

    Return $dp_metadata
    

}


Function Get-DPLPS ($parsed_lps_data) {
    $dp_mps_avg = ($parsed_lps_data | Measure-Object -Average LogsPerSecond).Average
    $dp_total_compares = ($parsed_lps_data | Measure-object -Sum TotalCompares).Sum
    $lps_total = 0
    $parsed_lps_data | ForEach-Object {
        $mpe_product = ( [Int]$_.TotalCompares * [Single]$_.LogsPersecond )
        $lps_total += $mpe_product
    }
    $dp_weighted_mps_avg = ( [Single]$lps_total / [Int]$dp_total_compares )
    Return [Single]$dp_weighted_mps_avg, $dp_mps_avg
}

Function Get-WastedTime ($parsed_lps_data, $avgmps) {
    $parsed_lps_data_new = @()
    $parsed_lps_data | ForEach-Object {
        $this_match = New-Object -TypeName psobject
        $this_match | Add-Member -MemberType NoteProperty -Name Index -Value $_.Index
        $this_match | Add-Member -MemberType NoteProperty -Name LogSourceType -Value $_.LogSourceType
        $this_match | Add-Member -MemberType NoteProperty -Name MPEPolicy -Value $_.MPEPolicy
        $this_match | Add-Member -MemberType NoteProperty -Name TotalCompares -Value $_.TotalCompares
        $this_match | Add-Member -MemberType NoteProperty -Name LogsPerSecond -Value $_.LogsPerSecond
        [Single]$wtime = ( ((1 / [Single]$_.LogsPerSecond) - (1 / $avgmps)) * [Int]$_.TotalCompares )
        $this_match | Add-Member -MemberType NoteProperty -Name WastedTime -Value $wtime
        $parsed_lps_data_new += $this_match
    }
    return $parsed_lps_data_new
}

Function Write-ParsedLPSData ($parsed_lps_data, $lps, $lps_weighted, $out_file, $dp_name, $dp_metadata) {
    Write-output "Data Processor: $($dp_name)" | Out-File -FilePath $out_file
    Write-Output "Mediator ID: $($dp_metadata.MediatorID)" | Out-File -FilePath $out_file -Append
    Write-Output "Mediator Version: $($dp_metadata.MediatorVersion)" | Out-File -FilePath $out_file -Append
    Write-Output "Collection Start Time: $($dp_metadata.CollectionStartTime)" | Out-File -FilePath $out_file -Append
    Write-Output "Collection End Time: $($dp_metadata.CollectionEndTime)" | Out-File -FilePath $out_file -Append
    Write-output "Average MPS: $($lps)" | Out-File -FilePath $out_file -Append
    Write-output "Weighted Average MPS: $($lps_weighted)" | Out-File -FilePath $out_file -Append
    $parsed_lps_data | Sort-Object -Property WastedTime -Descending | Format-Table -Property * -AutoSize -Wrap | Out-File -FilePath $out_file -Append
}

Function Process-LPS ($dp_config) {
    $data = Get-Content $dp_config.lps_path -Raw
    $parsed_data = Get-LPSData $data
    $dp_lps, $dp_lps_nonweighted = Get-DPLPS $parsed_data
    $parsed_data_2 = Get-WastedTime $parsed_data $dp_lps
    $dp_metadata = Get-Metadata $data
    Write-ParsedLPSData $parsed_data_2 $dp_lps_nonweighted $dp_lps $dp_config.Output_File $dp_config.name $dp_metadata
}

$dps.config.DPs | ForEach-Object {
    Process-LPS $_
}