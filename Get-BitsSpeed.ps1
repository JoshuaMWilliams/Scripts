<#
.SYNOPSIS
  Perform a BITS Speed Test between 2 machines
.DESCRIPTION
  This script performs a BITS file transfer between two specified machines. 
.PARAMETER DestinationComputer 
    The hostname of the target computer
.PARAMETER SourceComputer
    Default: localhost
    The hostname of the computer from which a file will be transferred
.PARAMETER TestCount
    Default: 1
    The number of transfers that will be completed
.PARAMETER TransferSize
    Default: 50Mb
    The size of the file that will be transferred


.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Joshua M. Williams (JoshuaMWilliams@ProtonMail.com
  Creation Date:  5/25/18
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

Function Get-BITSSpeed{
    Param(
		[parameter(Mandatory = $True)]
		[string]$DestinationComputer,
        [parameter(Mandatory = $False)]
        [string]$SourceComputer = $env:ComputerName,
        [Parameter(Mandatory = $False)]
        [int]$TestCount = 1,
        [Parameter(Mandatory = $False)]
        [double]$TransferSize = 20mb
	)
    Clear-Host
    Import-Module BitsTransfer

    #Test Connectivity 
    Try{
        Write-Host "Testing Network Connection"
        Test-Connection $DestinationComputer -ErrorAction Stop | Out-Null
        Test-Connection $SourceComputer -ErrorAction Stop | Out-Null
    }Catch{
        Write-Host "$($_.Exception.Message)"
        Break
    }
    
    #Setup objects for multi-test averaging
    $MbpsArray = New-Object System.Collections.Generic.List[System.Object]
   
    #Create Test File
    Write-Host "Creating Text File"
    $TempFile = [System.IO.File]::Create("\\$SourceComputer\C$\Temp\BitsTestFile.txt")
    $TempFile.SetLength($TransferSize)
    $TempFile.Close()   
      
    For($i= 0; $i -lt $TestCount; $i++){
        Write-Host "Running Speed Test"
        #Start Test
        $BitsTransferName = "BITS Speed Test" + (Get-Date)
        Start-BitsTransfer `
            -Source "\\$SourceComputer\C$\Temp\BitsTestFile.txt" `
            -Destination "\\$DestinationComputer\C$\Temp\" `
            -DisplayName $BitsTransferName `
            -Asynchronous | Out-Null
        $BitsJob = Get-BitsTransfer $BitsTransferName
        
        #Wait for Bits to start transfer
        $LastStatus = $BitsJob.JobState 
        Do{
            If ($LastStatus -ne $BitsJob.JobState) {
                $LastStatus = $BitsJob.JobState
            }
            If ($LastStatus -like "*Error*") {
                Remove-BitsTransfer $BitsJob
                Write-Host "Error connecting to download."
			    Break
            }
        }While($LastStatus -ne "Transferring")

        #Transfer Started - Monitor and Time 
        $StartTime = Get-Date
        While($BitsJob.BytesTransferred -lt $BitsJob.BytesTotal){
            $PercentComplete = ($BitsJob.BytesTransferred / $BitsJob.BytesTotal)*100
            Write-Progress -Activity "Transferring Data: Test ($($i+1)/$TestCount)" -Status "$PercentComplete Percent Complete" -PercentComplete $PercentComplete
        }

        $StopTime = Get-Date
        
        #Calculate Data 
        $TotalTime = New-TimeSpan $StartTime $StopTime
        $Mbps = (((($BitsJob.BytesTotal / $TotalTime.TotalSeconds) * 8) / 1024 ) / 1024)
        $MbpsArray += $Mbps


    }

    Write-Host "Mbps:"
    $MbpsArray | Measure -Average -Minimum -Maximum | Select Average,Maximum,Minimum | fl


    #Remove Temp File 
    Write-Host "Removing Test File"
    Remove-Item "\\$SourceComputer\C$\Temp\BitsTestFile.txt"

}
Get-BITSSpeed -DestinationComputer 021WJ6HLV42 -TestCount 2
