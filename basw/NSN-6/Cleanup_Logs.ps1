<#
---------------------------------------
Synopsis: Disk space cleanup script.
Author: Arun Dhiman
Version: 1.0
Date Modified: December 17, 2018
---------------------------------------
#>

# User input variables
$sLogFolder = "C:\DoNotDelete"
$sLogPathsFile = Join-Path $sLogFolder "Cleanup_Log_Paths.txt" # File that contains all log paths to clean.
$aPathsToClean = Get-Content $sLogPathsFile 		# Paths to include in Clean-up
$sLogFileExtension = "*.log*"  			# Log file extension to include in clean-up
$sZipFileExtension = "CleanUp_*.zip"	# Zip file extension to include in clean-up
$iLogsOlderThan = 32                    # Log file older than given days will be zipped.
$iZipOlderThan = 92						# Zip file older than given days will be zipped.
$dDate = (Get-Date).ToString("yyyyddMM_HHmmss")
$dDateString = [string](get-date)
$sHostname = $env:COMPUTERNAME
$sFailureMessage = "Cleanup_FAIL"
$sSuccessMessage = "Cleanup_SUCCESS"
# Create "C:\DoNotDelete" folder for log files
if (!(Test-Path $sLogFolder)) {
	try {
		Write-Output "`nTRY create folder $sLogFolder"
		&cmd /c "mkdir $sLogFolder"  > $null
		Write-Output "SUCCESS create folder $sLogFolder"
	} catch {
		$sErrorMessage = $_.Exception.Message
		$sFailedItem = $_.Exception.ItemName
		Write-Output "`$sErrorMessage = $sErrorMessage"
		Write-Output "`$sFailedItem = $sFailedItem"
		Write-Output "FAIL create folder $sLogFolder"
		Return $true
	}
} else {
	Write-Output "Exist $sLogFolder"
}
$sCleanupLogs = Join-Path $sLogFolder "CleanupLogs.log"
$sCleanupSplunkLogs = Join-Path $sLogFolder "CleanupSplunkLogs.log"

# start logging everything comes on screen
Start-Transcript -Path $sCleanupLogs -Append -Force

Function Start-ZipFiles {
	
	# check if any path is give for clean-up or not
	if ($aPathsToClean.count -eq 0) {
		Write-Output "EMPTY PATH `$aPathsToClean"
		Return $true > $null
	} else {
		# no comments
	}
	
	# add assembly for dot net compression
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	
	$aTotalLogFilesZipped = @()

	# test each path given for cleanup and get files for clean-up and log it into one output file
	foreach ($sPathValue in $aPathsToClean) {
		
		$sPath = $sPathValue.trim()
	
		if (Test-Path $sPath) {
			
			$aItemsToZip = @()

			# get log files to zip
            $aItemsToZip += Get-ChildItem -Recurse "$sPath\*" -include $sLogFileExtension -Force | Where-Object {$_.psparentpath -match "logs" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$iLogsOlderThan)} | Select-Object -ExpandProperty Fullname
			
			$aTotalLogFilesZipped += $aItemsToZip
			$bProceed = $false

			# check if any file is there to remove or not
			if ($aItemsToZip) {

				$bProceed = $true

				# conditional variables
				
				$sLogArchivePath = Join-Path $sPath "LogArchiveFolder"
				$sLogArchiveFileFullName = "$sPath\CleanUp_"+$dDate+".zip"

				# move all listed log files one by one
                foreach ($sItem in $aItemsToZip) {
					#$aRemoveColon = $sItem -Replace (':','')
					#$aSplitPath = $aRemoveColon.Split("\").trim()
					#$sFilename = $aSplitPath[-1]
					#$aJoinPath = $aSplitPath[0..($aSplitPath.length - 2)] -join '\'
					#$sMoveLogsTo = $sLogArchivePath +"\"+ $aJoinPath
					$aSplitPath = $sItem.split("\").trim()
					$sFilename = $aSplitPath[-1]
					$sCompletePath = $aSplitPath[0..($aSplitPath.length - 2)] -join '\'
					$sRelativePath = $sCompletePath -Replace (':','')
					$sMoveLogsTo = Join-Path $sLogArchivePath $sRelativePath

					if (!(Test-Path $sMoveLogsTo)) {

						&cmd /c "mkdir $sMoveLogsTo" > $null

					} else {
						# Do nothing and move forward
					}

					try {
						#$sItem | Copy-Item -Destination $sMoveLogsTo
						#$sItem | Remove-Item -Force
						Robocopy.exe $sCompletePath $sMoveLogsTo $sFilename /mov > $null
					} catch {
						$sErrorMessage = $_.Exception.Message
						$sFailedItem = $_.Exception.ItemName
						Write-Output "`$sErrorMessage = $sErrorMessage"
						Write-Output "`$sFailedItem = $sFailedItem"
					}

					
			    }
			} else {
				Write-Output "No file(s) found for cleanup at $sPath"
				#Write-Output "$dDateString ServerName = $Hostname; Message = $SuccessMessage; TotalFilesCleaned = $($TotalLogFilesZipped.count);" | Tee-Object -FilePath $sCleanupSplunkLogs -Append
				#Return $true > $null
			}

			if ($bProceed -eq $true) {
				# Start Clean-up
				# one-by-one moving files to $sLogArchivePath and zip them
				try {
					Write-Output "`nTRY zip"
					[io.compression.zipfile]::CreateFromDirectory($sLogArchivePath, $sLogArchiveFileFullName)
					Write-Output "Zip created - $sLogArchiveFileFullName"
					Write-Output "SUCCESS zip"
				} catch {
					$sErrorMessage = $_.Exception.Message
					$sFailedItem = $_.Exception.ItemName
					Write-Output "`$sErrorMessage = $sErrorMessage"
					Write-Output "`$sFailedItem = $sFailedItem"
					Write-Output "FAIL zip"
					Write-Output "$dDateString ServerName = $sHostname; Message = $sFailureMessage; TotalFilesCleaned = $($aTotalLogFilesZipped.count);" | Tee-Object -FilePath $sCleanupSplunkLogs -Append
					Return $true
				}

				# Removing $sLogArchivePath
				try {
					Write-Output "`nTRY remove $sLogArchivePath"
					&cmd /c "rmdir $sLogArchivePath /s /q"
					Write-Output "SUCCESS remove $sLogArchivePath"
				} catch {
					$sErrorMessage = $_.Exception.Message
					$sFailedItem = $_.Exception.ItemName
					Write-Output "`$sErrorMessage = $sErrorMessage"
					Write-Output "`$sFailedItem = $sFailedItem"
					Write-Output "FAIL remove $sLogArchivePath"
					Write-Output "$dDateString ServerName = $sHostname; Message = $sFailureMessage; Total files cleaned = $($aTotalLogFilesZipped.count);" | Tee-Object -FilePath $sCleanupSplunkLogs -Append
					Return $true
				}
			} else {
				# Do Nothing
			}
	    } else {
			Write-Output "Does Not Exist $sPath"
		}
	}
	
	Write-Output "$dDateString; ServerName = $sHostname; Message = $sSuccessMessage; TotalFilesCleaned = $($aTotalLogFilesZipped.count);" | Tee-Object -FilePath $sCleanupSplunkLogs -Append
}


Function Start-RemoveZipFile {
	
	# check if any path is given for clean-up or not
	if ($aPathsToClean.count -eq 0) {
		Write-Output "EMPTY PATH `$aFilesToClean"
		Return $true
	} else {
		# no comments
	}
	
	# test each path given for cleanup and get files for clean-up and log it into one output file
	foreach ($sPathValue in $aPathsToClean) {
	
		$sPath = $sPathValue.trim()

		if (!(Test-Path $sPath)) {
			Write-Output "Does Not Exist $sPath"
		} else {
			$aZipToRemove = @()

			# get zip files to remove
            $aZipToRemove = Get-ChildItem -Recurse "$sPath\*" -include $sZipFileExtension -Force | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$iZipOlderThan)} | Select-Object -ExpandProperty Fullname

			# check if any zip file is there to remove or not
			if (!$aZipToRemove) {
				Write-Output "No zip file(s) found for cleanup"
				Return $true

			} else {
				try {
					Write-Output "TRY Remove zip"
					$aZipToRemove | Remove-Item -Force
					Write-Output "SUCCESS Remove zip"
				} catch {
					$sErrorMessage = $_.Exception.Message
					$sFailedItem = $_.Exception.ItemName
					Write-Output "`$sErrorMessage = $sErrorMessage"
					Write-Output "`$sFailedItem = $sFailedItem"
					Write-Output "FAIL Remove zip"
				}
			}
		}
	}
}


# call Start-CleanUp function
Write-Output "`n---------------------------------------------"`
Write-Output "START cleanup - $dDateString"
Write-Output "START zipping logs"
Start-ZipFiles 
Write-Output "END zipping logs"
Write-Output "START remove zips"
Start-RemoveZipFile 
Write-Output "END remove zips"
Write-Output "FINISH cleanup - $([string](Get-Date))"
Write-Output "---------------------------------------------"

Stop-Transcript