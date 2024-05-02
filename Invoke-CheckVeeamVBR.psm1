
function Invoke-CheckVeeamVBR ()
{
  [CmdletBinding()]
  param(
    [Parameter()]

    [switch]$NoPerfData = $FALSE,
    [switch]$RequireAgentService = [System.Convert]::ToBoolean($env:requireAgentService)
  )



    # Enumerate all of the enabled jobs
    $JobNames = Get-VBRJob -WarningAction:SilentlyContinue | Sort-Object -Propert TypeToString;
    # Flag to create a new check package
    $LastType = "";
    # Create the overarching check result
    $CheckPackage = New-IcingaCheckPackage -Name "Veeam VBR Jobs" -OperatorAnd;

    # Loop through each job
    foreach ($JobName in $JobNames) {
        # If this is an agent backup job, use a different call
        if ($JobName.JobType -eq "EpAgentPolicy") {
            $Job = Get-VBRComputerBackupJob -name $JobName.Name;
            $Type = "Agent Backup";
         } else {
            $Job = Get-VBRJob -name $JobName.Name;
            $Type = $Job.TypeToString;
        }

        # Build the rest of the job details
        $Name = $Job.Name;
        $Result = [Veeam.Backup.Core.CBackupJob]::FindLastSession($Job.Id).Result;
        $Status = [Veeam.Backup.Core.CBackupJob]::GetLastState($Job.Id);

        # If this is a new job type, add the previoius results if any to the 
        # overarching check package.  Create a new check package for this new
        # type
        if ($Type -ne $LastType) {
            if ($LastType -ne "") {
                $CheckPackage.AddCheck($JobPackage);
            }
            $JobPackage = New-IcingaCheckPackage -Name "Job Type: $($Type)" -OperatorAnd;
            $LastType = $Type;
        }

        # Look at the job results and add that check to the package
        $JobCheck = New-IcingaCheck -Name "$($Name) [$($Status)] " -Value $Result -NoPerfData;
        $JobCheck.WarnIfMatch("Warning").CritIfMatch("Failed") | Out-Null;
        $JobPackage.AddCheck($JobCheck);
    }

    # Pick up the last package created
    $CheckPackage.AddCheck($JobPackage);

    # Compile and return the results
    return (New-IcingaCheckresult -Check $CheckPackage -Compile);
}