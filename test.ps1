
<#
    .NOTES
    --------------------------------------------------------------------------------
     
     Written by:       MNRaju
    --------------------------------------------------------------------------------
#>


#----------------------------------------------
#region Application Functions
#----------------------------------------------

#endregion Application Functions

#----------------------------------------------
# Generated Form Function
#----------------------------------------------
function Show-rest_psf {

	#----------------------------------------------
	#region Import the Assemblies
	#----------------------------------------------
	[void][reflection.assembly]::Load('System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	[void][reflection.assembly]::Load('System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	#endregion Import Assemblies

	#----------------------------------------------
	#region Generated Form Objects
	#----------------------------------------------
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$form1 = New-Object 'System.Windows.Forms.Form'
	$buttonStartJob = New-Object 'System.Windows.Forms.Button'
	$imagelistButtonBusyAnimation = New-Object 'System.Windows.Forms.ImageList'
	$timerJobTracker = New-Object 'System.Windows.Forms.Timer'
	$InitialFormWindowState = New-Object 'System.Windows.Forms.FormWindowState'
	#endregion Generated Form Objects

	#----------------------------------------------
	# User Generated Script
	#----------------------------------------------
	
	$form1_Load={
		#TODO: Initialize Form Controls here
		
	}
	
	$buttonStartJob_Click={
		
		$buttonStartJob.Enabled = $false
		
		#Create a New Job using the Job Tracker
		$paramAddJobTracker = @{
			Name	  = 'JobName'
			JobScript = {
				#--------------------------------------------------
				#TODO: Set a script block
				#Important: Do not access form controls from this script block.
				
				Param ($Argument1) #Pass any arguments using the ArgumentList parameter
				
				for ($i = 0; $i -lt 50; $i++) { Start-Sleep -Milliseconds 1000 }
				
				#--------------------------------------------------
			}
			ArgumentList = $null
			CompletedScript = {
				Param ([System.Management.Automation.Job]$Job)
				#$results = Receive-Job -Job $Job 
				#Enable the Button
				$buttonStartJob.ImageIndex = -1
				$buttonStartJob.Enabled = $true
			}
			UpdateScript = {
				Param ([System.Management.Automation.Job]$Job)
				#$results = Receive-Job -Job $Job -Keep
				#Animate the Button
				if ($null -ne $buttonStartJob.ImageList)
				{
					if ($buttonStartJob.ImageIndex -lt $buttonStartJob.ImageList.Images.Count - 1)
					{
						$buttonStartJob.ImageIndex += 1
					}
					else
					{
						$buttonStartJob.ImageIndex = 0
					}
				}
			}
		}
		
		Add-JobTracker @paramAddJobTracker
	}
	
	$jobTracker_FormClosed=[System.Windows.Forms.FormClosedEventHandler]{
	#Event Argument: $_ = [System.Windows.Forms.FormClosedEventArgs]
		#Stop any pending jobs
		Stop-JobTracker
	}
	
	$timerJobTracker_Tick={
		Update-JobTracker
	}
	
	#region Job Tracker
	$JobTrackerList = New-Object System.Collections.ArrayList
	function Add-JobTracker
	{
		<#
			.SYNOPSIS
				Add a new job to the JobTracker and starts the timer.
		
			.DESCRIPTION
				Add a new job to the JobTracker and starts the timer.
		
			.PARAMETER  Name
				The name to assign to the job.
		
			.PARAMETER  JobScript
				The script block that the job will be performing.
				Important: Do not access form controls from this script block.
		
			.PARAMETER ArgumentList
				The arguments to pass to the job.
			.PARAMETER  CompletedScript
				The script block that will be called when the job is complete.
				The job is passed as an argument. The Job argument is null when the job fails.
		
			.PARAMETER  UpdateScript
				The script block that will be called each time the timer ticks.
				The job is passed as an argument. Use this to get the Job's progress.
		
			.EXAMPLE
				Add-JobTracker -Name 'JobName' `
				-JobScript {	
					Param($Argument1)#Pass any arguments using the ArgumentList parameter
					#Important: Do not access form controls from this script block.
					Get-WmiObject Win32_Process -Namespace "root\CIMV2"
				}`
				-CompletedScript {
					Param($Job)		
					$results = Receive-Job -Job $Job
				}`
				-UpdateScript {
					Param($Job)
					#$results = Receive-Job -Job $Job -Keep
				}
		
			.LINK
				
		#>
		
		Param(
		[ValidateNotNull()]
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[ValidateNotNull()]
		[Parameter(Mandatory=$true)]
		[ScriptBlock]$JobScript,
		$ArgumentList = $null,
		[ScriptBlock]$CompletedScript,
		[ScriptBlock]$UpdateScript)
		
		#Start the Job
		$job = Start-Job -Name $Name -ScriptBlock $JobScript -ArgumentList $ArgumentList
		
		if($null -ne $job)
		{
			#Create a Custom Object to keep track of the Job & Script Blocks
			$members = @{	'Job' = $Job;
							'CompleteScript' = $CompletedScript;
							'UpdateScript' = $UpdateScript}
			
			$psObject = New-Object System.Management.Automation.PSObject -Property $members
			
			[void]$JobTrackerList.Add($psObject)
			
			#Start the Timer
			if(-not $timerJobTracker.Enabled)
			{
				$timerJobTracker.Start()
			}
		}
		elseif($null -ne $CompletedScript)
		{
			#Failed
			Invoke-Command -ScriptBlock $CompletedScript -ArgumentList $null
		}
	
	}
	
	function Update-JobTracker
	{
		<#
			.SYNOPSIS
				Checks the status of each job on the list.
		#>
		
		#Poll the jobs for status updates
		$timerJobTracker.Stop() #Freeze the Timer
		
		for($index = 0; $index -lt $JobTrackerList.Count; $index++)
		{
			$psObject = $JobTrackerList[$index]
			
			if($null -ne $psObject) 
			{
				if($null -ne $psObject.Job)
				{
					if ($psObject.Job.State -eq 'Blocked')
	                {
	                    #Try to unblock the job
	                    Receive-Job $psObject.Job | Out-Null
	                }
	                elseif($psObject.Job.State -ne 'Running')
					{				
						#Call the Complete Script Block
						if($null -ne $psObject.CompleteScript)
						{
							#$results = Receive-Job -Job $psObject.Job
							Invoke-Command -ScriptBlock $psObject.CompleteScript -ArgumentList $psObject.Job
						}
						
						$JobTrackerList.RemoveAt($index)
						Remove-Job -Job $psObject.Job
						$index-- #Step back so we don't skip a job
					}
					elseif($null -ne $psObject.UpdateScript)
					{
						#Call the Update Script Block
						Invoke-Command -ScriptBlock $psObject.UpdateScript -ArgumentList $psObject.Job
					}
				}
			}
			else
			{
				$JobTrackerList.RemoveAt($index)
				$index-- #Step back so we don't skip a job
			}
		}
		
		if($JobTrackerList.Count -gt 0)
		{
			$timerJobTracker.Start()#Resume the timer
		}
	}
	
	function Stop-JobTracker
	{
		<#
			.SYNOPSIS
				Stops and removes all Jobs from the list.
		#>
		#Stop the timer
		$timerJobTracker.Stop()
		
		#Remove all the jobs
		while($JobTrackerList.Count -gt 0)
		{
			$job = $JobTrackerList[0].Job
			$JobTrackerList.RemoveAt(0)
			Stop-Job $job
			Remove-Job $job
		}
	}
	#endregion
	
	# --End User Generated Script--
	#----------------------------------------------
	#region Generated Events
	#----------------------------------------------
	
	$Form_StateCorrection_Load=
	{
		#Correct the initial state of the form to prevent the .Net maximized form issue
		$form1.WindowState = $InitialFormWindowState
	}
	
	$Form_Cleanup_FormClosed=
	{
		#Remove all event handlers from the controls
		try
		{
			$buttonStartJob.remove_Click($buttonStartJob_Click)
			$form1.remove_FormClosed($jobTracker_FormClosed)
			$form1.remove_Load($form1_Load)
			$timerJobTracker.remove_Tick($timerJobTracker_Tick)
			$form1.remove_Load($Form_StateCorrection_Load)
			$form1.remove_FormClosed($Form_Cleanup_FormClosed)
		}
		catch { Out-Null <# Prevent PSScriptAnalyzer warning #> }
	}
	#endregion Generated Events

	#----------------------------------------------
	#region Generated Form Code
	#----------------------------------------------
	$form1.SuspendLayout()
	#
	# form1
	#
	$form1.Controls.Add($buttonStartJob)
	$form1.AutoScaleDimensions = '6, 13'
	$form1.AutoScaleMode = 'Font'
	$form1.ClientSize = '489, 363'
	$form1.Name = 'form1'
	$form1.Text = 'Form'
	$form1.add_FormClosed($jobTracker_FormClosed)
	$form1.add_Load($form1_Load)
	#
	# buttonStartJob
	#
	$buttonStartJob.ImageList = $imagelistButtonBusyAnimation
	$buttonStartJob.Location = '170, 67'
	$buttonStartJob.Name = 'buttonStartJob'
	$buttonStartJob.Size = '75, 23'
	$buttonStartJob.TabIndex = 0
	$buttonStartJob.Text = 'Start'
	$buttonStartJob.UseCompatibleTextRendering = $True
	$buttonStartJob.UseVisualStyleBackColor = $True
	$buttonStartJob.add_Click($buttonStartJob_Click)
	#
	# imagelistButtonBusyAnimation
	#
	$Formatter_binaryFomatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
	#region Binary Data
	$System_IO_MemoryStream = New-Object System.IO.MemoryStream (,[byte[]][System.Convert]::FromBase64String('
AAEAAAD/////AQAAAAAAAAAMAgAAAFdTeXN0ZW0uV2luZG93cy5Gb3JtcywgVmVyc2lvbj00LjAu
MC4wLCBDdWx0dXJlPW5ldXRyYWwsIFB1YmxpY0tleVRva2VuPWI3N2E1YzU2MTkzNGUwODkFAQAA
ACZTeXN0ZW0uV2luZG93cy5Gb3Jtcy5JbWFnZUxpc3RTdHJlYW1lcgEAAAAERGF0YQcCAgAAAAkD
AAAADwMAAAB2CgAAAk1TRnQBSQFMAgEBCAEAATgBAAE4AQABEAEAARABAAT/ASEBAAj/AUIBTQE2
BwABNgMAASgDAAFAAwABMAMAAQEBAAEgBgABMP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/
AP8AugADwgH/Az0B/wM9Af8DwgH/MAADwgH/A10B/wOCAf8DwgH/sAADPQH/AwAB/wMAAf8DPQH/
MAADggH/Az0B/wM9Af8DXQH/gAADwgH/Az0B/wM9Af8DwgH/IAADPQH/AwAB/wMAAf8DPQH/A8IB
/wNdAf8DggH/A8IB/xAAA8IB/wM9Af8DPQH/A8IB/wNdAf8DPQH/Az0B/wNdAf8EAAOSAf8DkgH/
A8IB/3AAAz0B/wMAAf8DAAH/Az0B/yAAA8IB/wM9Af8DPQH/A8IB/wOCAf8DPQH/Az0B/wOCAf8Q
AAM9Af8DAAH/AwAB/wM9Af8DwgH/A10B/wOCAf8DwgH/A5IB/wOCAf8DggH/A5IB/3AAAz0B/wMA
Af8DAAH/Az0B/zAAA10B/wM9Af8DPQH/A10B/xAAAz0B/wMAAf8DAAH/Az0B/xAAA5IB/wOSAf8D
kgH/A8IB/3AAA8IB/wM9Af8DPQH/A8IB/zAAA8IB/wNdAf8DggH/A8IB/xAAA8IB/wM9Af8DPQH/
A8IB/xAAA8IB/wOSAf8DkgH/A8IB/zgAA8IB/wM9Af8DPQH/A8IB/zAAA8IB/wOCAf8DXQH/A8IB
/zAAA8IB/wPCAf8DkgH/A8IB/zQAA8IB/wPCAf80AAM9Af8DAAH/AwAB/wM9Af8wAANdAf8DPQH/
Az0B/wNdAf8wAAOSAf8DggH/A4IB/wOSAf8wAAPCAf8DwgH/A8IB/wPCAf8wAAM9Af8DAAH/AwAB
/wM9Af8wAAOCAf8DPQH/Az0B/wOCAf8wAAPCAf8DggH/A5IB/wOSAf8wAAPCAf8DwgH/A8IB/wPC
Af8wAAPCAf8DPQH/Az0B/wPCAf8wAAPCAf8DggH/A10B/wPCAf8wAAPCAf8DkgH/A5IB/wPCAf80
AAPCAf8DwgH/EAADwgH/A8IB/xQAA8IB/wOCAf8DXQH/A8IB/zAAA8IB/wOSAf8DkgH/A8IB/zQA
A8IB/wPCAf9UAAPCAf8DwgH/A8IB/wPCAf8QAANdAf8DPQH/Az0B/wNdAf8wAAOSAf8DggH/A5IB
/wOSAf8wAAPCAf8DwgH/A8IB/wPCAf9QAAPCAf8DwgH/A8IB/wPCAf8DwgH/A8IB/wOSAf8DwgH/
A4IB/wM9Af8DPQH/A4IB/yQAA8IB/wPCAf8EAAPCAf8DggH/A5IB/wOSAf8wAAPCAf8DwgH/A8IB
/wPCAf9UAAPCAf8DwgH/BAADkgH/A4IB/wOCAf8DkgH/A8IB/wOCAf8DXQH/A8IB/yAAA8IB/wPC
Af8DwgH/A8IB/wPCAf8DkgH/A5IB/wPCAf80AAPCAf8DwgH/ZAADkgH/A5IB/wOSAf8DkgH/MAAD
wgH/A8IB/wPCAf8DwgH/sAADwgH/A5IB/wOSAf8DwgH/NAADwgH/A8IB/7QAA8IB/wPCAf8DkgH/
A8IB/zQAA8IB/wPCAf+0AAOSAf8DggH/A4IB/wOSAf8wAAPCAf8DwgH/A8IB/wPCAf+gAAPCAf8D
XQH/A4IB/wPCAf8DkgH/A5IB/wOSAf8DwgH/BAADwgH/A8IB/xQAA8IB/wPCAf8DkgH/A8IB/wPC
Af8DwgH/A8IB/wPCAf8kAAPCAf8DwgH/dAADggH/Az0B/wM9Af8DggH/A8IB/wOSAf8DkgH/A8IB
/wPCAf8DwgH/A8IB/wPCAf8QAAOSAf8DggH/A4IB/wOSAf8EAAPCAf8DwgH/JAADwgH/A8IB/wPC
Af8DwgH/cAADXQH/Az0B/wM9Af8DggH/EAADwgH/A8IB/wPCAf8DwgH/EAADkgH/A5IB/wOSAf8D
kgH/MAADwgH/A8IB/wPCAf8DwgH/cAADwgH/A10B/wNdAf8DwgH/FAADwgH/A8IB/xQAA8IB/wOS
Af8DkgH/A8IB/zQAA8IB/wPCAf9sAAPCAf8DPQH/Az0B/wPCAf8wAAPCAf8DXQH/A4IB/wPCAf8w
AAPCAf8DwgH/A5IB/wPCAf80AAPCAf8DwgH/NAADPQH/AwAB/wMAAf8DPQH/MAADggH/Az0B/wM9
Af8DXQH/MAADkgH/A4IB/wOCAf8DkgH/MAADwgH/A8IB/wPCAf8DwgH/MAADPQH/AwAB/wMAAf8D
PQH/MAADXQH/Az0B/wM9Af8DggH/MAADkgH/A5IB/wOSAf8DkgH/MAADwgH/A8IB/wPCAf8DwgH/
MAADwgH/Az0B/wM9Af8DwgH/MAADwgH/A10B/wNdAf8DwgH/MAADwgH/A5IB/wOSAf8DwgH/NAAD
wgH/A8IB/3wAA8IB/wM9Af8DPQH/A8IB/zAAA8IB/wNdAf8DggH/A8IB/zAAA8IB/wPCAf8DkgH/
A8IB/xAAA8IB/wM9Af8DPQH/A8IB/1AAAz0B/wMAAf8DAAH/Az0B/zAAA4IB/wM9Af8DPQH/A10B
/zAAA5IB/wOCAf8DggH/A5IB/xAAAz0B/wMAAf8DAAH/Az0B/1AAAz0B/wMAAf8DAAH/Az0B/zAA
A10B/wM9Af8DPQH/A4IB/wOSAf8DPQH/Az0B/wPCAf8gAAOSAf8DkgH/A5IB/wOSAf8DwgH/A10B
/wOCAf8DwgH/Az0B/wMAAf8DAAH/Az0B/1AAA8IB/wM9Af8DPQH/A8IB/zAAA8IB/wOCAf8DXQH/
A8IB/wM9Af8DAAH/AwAB/wM9Af8gAAPCAf8DkgH/A5IB/wPCAf8DggH/Az0B/wM9Af8DXQH/A8IB
/wM9Af8DPQH/A8IB/6AAAz0B/wMAAf8DAAH/Az0B/zAAA10B/wM9Af8DPQH/A4IB/7AAA8IB/wM9
Af8DPQH/A8IB/zAAA8IB/wOCAf8DXQH/A8IB/xgAAUIBTQE+BwABPgMAASgDAAFAAwABMAMAAQEB
AAEBBQABgAEBFgAD/4EABP8B/AE/AfwBPwT/AfwBPwH8AT8D/wHDAfwBAwHAASMD/wHDAfwBAwHA
AQMD/wHDAf8DwwP/AcMB/wPDAf8B8AH/AfAB/wHwAf8B+QH/AfAB/wHwAf8B8AH/AfAB/wHwAf8B
8AH/AfAB/wHwAf8B8AH/AfAB/wHwAf8B+QHnAcMB/wHDAf8B5wL/AsMB/wHDAf8BwwL/AcABAwH+
AUMB/wHDAv8B5AEDAfwBAwH/AecC/wH8AT8B/AE/BP8B/AE/Af4BfwT/AfwBPwH+AX8E/wH8AT8B
/AE/BP8BwAEnAcABPwHnA/8BwAEDAcIBfwHDA/8DwwH/AcMD/wHDAecBwwH/AecD/wEPAf8BDwH/
AQ8B/wGfAf8BDwH/AQ8B/wEPAf8BDwH/AQ8B/wEPAf8BDwH/AQ8B/wEPAf8BDwH/AQ8B/wGfA/8B
wwH/AcMB/wLDAv8BwwH/AcMB/wLDAv8BwwH/AcABPwHAAQMC/wHDAf8BwAE/AcABAwT/AfwBPwH8
AT8E/wH8AT8B/AE/Cw=='))
	#endregion
	$imagelistButtonBusyAnimation.ImageStream = $Formatter_binaryFomatter.Deserialize($System_IO_MemoryStream)
	$Formatter_binaryFomatter = $null
	$System_IO_MemoryStream = $null
	$imagelistButtonBusyAnimation.TransparentColor = 'Transparent'
	#
	# timerJobTracker
	#
	$timerJobTracker.add_Tick($timerJobTracker_Tick)
	$form1.ResumeLayout()
	#endregion Generated Form Code

	#----------------------------------------------

	#Save the initial state of the form
	$InitialFormWindowState = $form1.WindowState
	#Init the OnLoad event to correct the initial state of the form
	$form1.add_Load($Form_StateCorrection_Load)
	#Clean up the control events
	$form1.add_FormClosed($Form_Cleanup_FormClosed)
	#Show the Form
	return $form1.ShowDialog()

} #End Function

#Call the form
Show-rest_psf | Out-Null
