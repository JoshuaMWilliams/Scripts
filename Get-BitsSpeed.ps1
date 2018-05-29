<#
.SYNOPSIS
  Perform a BITS Speed Test between 2 machines
.DESCRIPTION
  This script performs a BITS file transfer between two specified machines. 
.PARAMETER DestinationComputer 
    The hostname of the target computer
.PARAMETER TestCount
    Default: 1
    The number of transfers that will be completed
.PARAMETER TransferSize
    Default: 50Mb
    The size of the file that will be transferred
.NOTES
  Version:        1.0
  Author:         Joshua M. Williams (JoshuaMWilliams@ProtonMail.com
  Creation Date:  5/25/18
  
.EXAMPLE
  Get-BitsSpeed -DestinationComputer hostname123 -TestCount 2
  	Performs 2 tests to hostname123
  Get-BitsSpeed -DestinationComputer hostname123 -TestCount 2 -Size 1Gb
  	Performs 2 tests with a 1Gb file to hostname123
#>

Function Get-BITSSpeed{
    Param(
	[parameter(Mandatory = $True)]
	[string]$DestinationComputer,
        [Parameter(Mandatory = $False)]
        [int]$TestCount = 1,
        [Parameter(Mandatory = $False)]
        [double]$TransferSize = 20mb
	)
    [string]$SourceComputer = $env:ComputerName
    Import-Module BitsTransfer

    #Test Connectivity 
    Try{
        Write-Host "Testing Network Connection"
        Test-Connection $DestinationComputer -ErrorAction Stop | Out-Null
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
      
    1..$TestCount | %{
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
            Write-Progress -Activity "Transferring Data: Test ($($_)/$TestCount)" -Status "$PercentComplete Percent Complete" -PercentComplete $PercentComplete
        }

        $StopTime = Get-Date
        Write-Progress -completed -Activity "Transferring Data: Test ($($_)/$TestCount)" 
        #Calculate Data 
        $TotalTime = New-TimeSpan $StartTime $StopTime
        $Mbps = (((($BitsJob.BytesTotal / $TotalTime.TotalSeconds) * 8) / 1024 ) / 1024)
        $MbpsArray += $Mbps

	Complete-BitsTransfer $BitsJob
    }

    Write-Host "Mbps:"
    $MbpsArray | Measure -Average -Minimum -Maximum | Select Average,Maximum,Minimum | fl


    #Remove Temp File 
    Write-Host "Removing Test File"
    Remove-Item "\\$SourceComputer\C$\Temp\BitsTestFile.txt"
    Remove-Item "\\$DestinationComputer\C$\Temp\BitsTestFile.txt"
}

