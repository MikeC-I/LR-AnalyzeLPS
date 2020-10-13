$lps_threshold = 500
$logs_threshold = 100000
$input_file = "C:\LogRhythm\Scripts\LR-AnalyzeLPS\lps_detail.log"
$regex_1 = "Log Source Type\:\s+(?<logsourcetype>.*)"
$regex_2 = "MPE Policy\:\s+(?<mpe>.*)"
$regex_3 = "Total Compares\:\s+(?<compares>.*)"
$regex_4 = "LPS\-Policy\-Total\:\s+(?<lps>.*)"

$log_data = Get-Content $input_file -Raw

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

$all_matches | ForEach-Object {
    $bad_types = @()
    $compares = [Int]$_.TotalCompares
    $lps = [Single]$_.LogsPerSecond
    if (($compares -ge $logs_threshold) -and ($lps -le $lps_threshold)) {
        $bad_types += $_
    }
    $bad_types | Format-Table
}