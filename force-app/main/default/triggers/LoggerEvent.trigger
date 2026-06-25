// event = log_msg
// ignore general msgs written to Logger object

// supported event types:

// HTTP endpoints: ping.php, retrieve.php
// target object: ClientJob
// event codes: init_jobcode, start_job, job_finished, job_finished_with_error 
//
// HTTP endpoints: logmsg.php
// target object: Client
// update_snapshot

// ! TODO: logger events --> should have Source, TSource, Machinename, fields all populated
// SessionTS not being populated

// https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce.com/
// storagevault941@agentforce.com
// As1df1gh!

// sf org login web --set-default-username --alias storagevault941@agentforce.com
// sf project retrieve start -m ApexTrigger
// sf deploy metadata -m ApexTrigger:LoggerEvent

trigger LoggerEvent on StorageVault__Logger__c (after insert) {
	            
    List<StorageVault__Logger__c> logmsgs = new List<StorageVault__Logger__c>();
    List<StorageVault__ClientJob__c> clientjobsdelta = new List<StorageVault__ClientJob__c>();
        
    for (StorageVault__Logger__c obj : Trigger.new) {
		if ( String.isBlank(obj.StorageVault__Event__c) || obj.StorageVault__Event__c == 'log_msg' )
            continue;
        
        logmsgs.add(obj);
    }
	
    if ( logmsgs.isEmpty() )
        return;
    
    LoggerTriggerHandler.LogSys('trigger start -- records count: ' + String.valueOf(logmsgs.size()));

    for ( StorageVault__Logger__c logmsg : logmsgs ) {
        string event = logmsg.StorageVault__Event__c;
        string logmsgstr = logmsg.StorageVault__LogMsg__c;
        string kvpstr = logmsg.StorageVault__KVP__c;
        string jobrowid = '';
        string jobcode = '';
        string errorcode = '';
        
        if ( String.isBlank(event) ) {
            LoggerTriggerHandler.LogSys('FATAL ERROR');
            // should never reach here
            continue;
        }

        LoggerTriggerHandler.LogSys('[1]logmsg='+logmsg.ID+'|event='+event +'|logmsg='+logmsgstr+'|kvp='+kvpstr);

        if ( event == 'update_snapshot' ) {
        	// this event targets Client object, process in LoggerTriggerHandler    
        	// new_zfei_md5 --> ScriptMD5
            // SnapshotTS
            continue;
        }    
        
        Map<string, string> kvp = String.isBlank(kvpstr) ? new Map<string,string>() : LoggerTriggerHandler.LogMsgToKVP(kvpstr) ;
                
        jobcode = kvp.containsKey('jobcode') ? kvp.get('jobcode') : '';
        jobrowid = kvp.containsKey('jobrowid') ? kvp.get('jobrowid') : '';
        errorcode = kvp.containsKey('errorcode') ? kvp.get('errorcode') : '';
        
        LoggerTriggerHandler.LogSys('[2]logmsg='+logmsg.ID+'|jobcode='+jobcode+'|jobrowid='+jobrowid+'|errorcode='+errorcode);

        if ( String.isBlank(jobcode) && String.isBlank(jobrowid) ) {
            LoggerTriggerHandler.LogSys('[3]logmsg='+logmsg.ID+'|both jobcode and jobrowid are empty -- skipping');

        	continue;    
        }
        
        List<StorageVault__ClientJob__c> clientjobs = [ SELECT ID, StorageVault__ClientID__c, 
                                                       StorageVault__JobCode__c, StorageVault__RetrieveTS__c, StorageVault__Result__c, StorageVault__StartTS__c, StorageVault__EndTS__c
                                                       FROM StorageVault__ClientJob__c 
                                                       WHERE ID = :jobrowid OR StorageVault__JobCode__c = :jobcode 
                                                       LIMIT 1];
        
        StorageVault__ClientJob__c clientjob = null;
        
        if ( clientjobs.isEmpty() ) {
            LoggerTriggerHandler.LogSys('[4]logmsg='+logmsg.ID+'|clientjobs is empty -- skipping');

            continue;
        }
        
        clientjob = clientjobs[0];
		
        LoggerTriggerHandler.LogSys('[5]logmsg='+logmsg.ID+'|clientjob: '+clientjob.ID+'|event='+event);

        // ping.php, retrieve.php
        if ( event == 'init_jobcode' ) {        
            LoggerTriggerHandler.LogSys('[6.1]logmsg='+logmsg.ID+'|processing start_job event');

            clientjob.StorageVault__RetrieveTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
            clientjob.StorageVault__JobCode__c = jobcode;
            clientjob.StorageVault__Result__c = 'JOB_INIT';

        } else if ( event == 'job_started' ) {
            LoggerTriggerHandler.LogSys('[6.2]logmsg='+logmsg.ID+'|processing start_job event');

            clientjob.StorageVault__StartTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
            clientjob.StorageVault__Result__c = 'JOB_STARTED';

        } else if ( event == 'job_finished' ) {
            clientjob.StorageVault__EndTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
            
            clientjob.StorageVault__Result__c = 'JOB_FINISHED_WITH_NO_ERROR';
            
        } else if ( event == 'job_finished_with_error' ) {
            clientjob.StorageVault__EndTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
            
            clientjob.StorageVault__Result__c = 'JOB_FINISHED_WITH_ERROR_CODE='+errorcode;
        } 
        
        clientjobsdelta.add(clientjob);
        
        string jsonstr = 'ERROR_CLIENT_JOB_IS_EMPTY';
        
        try {
            jsonstr = JSON.serialize(clientjob);
        } catch (Exception ex) {
            LoggerTriggerHandler.LogSysEx(ex);
        }
        
        LoggerTriggerHandler.LogSys('[7]logmsg='+logmsg.ID+'|updated clientjob: '+jsonstr);

        LoggerTriggerHandler.LogSys('[8]logmsg='+logmsg.ID+'|clientjobsdelta.size()=' + String.valueOf(clientjobsdelta.size()) + '|finished');
    }
    
    update clientjobsdelta;
    LoggerTriggerHandler.LogSys('[9]Trigger finished');
}