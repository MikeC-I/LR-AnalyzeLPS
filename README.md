# LR-AnalyzeLPS

Powershell script to provide additional insight into log processing performance by analyzing lps_detail and lps_detail_snapshot logs and applying weighting to performance metrics to help you determine which log source types and log processing policies are impacted performance the most.

### Overview

The script reads data from the lps_details_snapshot.log file for data processors, parses the data, and outputs a list of Log Source Types/MPE Policies sorted by total Wasted Time.

But what is Wasted Time?
Wasted Time is a metric that attempts to capture the performance impact of a given MPE Policy on the data processor's overall performance.
Wasted Time is calculated first by finding the overall weighted MPS for the data processor (MPE Polic LPS weighted by total compares), then determine for each MPE Policy how much longer it takes to parse a single log than the average,
then multiplting this by the total compares for the MPE policy.

What do I do with this information?
Once you've identified the MPE Policies with the most amount of Wasted Time, the next step is generally to open the lps_detail_snapshot.log file from the relevant DP and look at the specific MPE Policy.
You may be able to identify particular MPE rules that are causing performance impact by looking at the LPS-Regex-Total column. If the poor performing rules are custom rules, you may want to try to improve the regula expression.
If the poor performing rules are system rules, you will need to determine if the logs being captured by this rule are confirming to the expected formatting.  It may be prudent to create a new MPE Policy for this log source type
and disable some of the poor performing rules if they are not important logs. 
    
## Getting Started

1. Copy LR-AnalyzeLPS.ps1 and lps_files.json into C:\LogRhythm\Scripts\LR-AnalyzeLPS\ (this is necessary as path to lps_files.json is hard coded).
2. Edit lps_files.json to reflect your deployment. Values provided in the lps_files.json reflect the default file path for the lps_detail_snapshot.log file. (Note: if you have a deployment with multiple DPs, you can include more than one and use a network path for the 'lps_path' file, just makes sure the 'name' is different for each DP)

## Usage

After editing the lps_files.json, you can run the script with two optional parameters:

-ExportCSV
    
    Use this to export the data as a raw CSV in addition to to formatted text file

-AppendDate
    
    Use this to append the date to the filename

Once the script is a run, a file will be output to the folder specified in the "output_path" variable for each DP in the lps_files.json config file.

## Authors

* **Mike Contasti-Isaac** - [GitHub](https://github.com/MikeC-I)

## License

This script isn't really licensed, and also USE AT YOUR OWN RISK, the author is not responsible for any loss or damage that may occur to relevant systems as a result of usin this script.

## Acknowledgments

* You know, my employer who's on-the-clock time I spent developing this
