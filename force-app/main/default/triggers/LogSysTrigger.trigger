trigger LogSysTrigger on StorageVault__LogEvent__e (after insert) {
    List<StorageVault__LogSys__c> logmsgs = new List<StorageVault__LogSys__c>();

    for (StorageVault__LogEvent__e event : Trigger.New) {
        StorageVault__LogSys__c logmsg = new StorageVault__LogSys__c();
        logmsg.StorageVault__LogMsg__c = event.StorageVault__Payload__c;
        logmsgs.add(logmsg);
    }

    if (!logmsgs.isEmpty()) {
        insert logmsgs;
    }

}