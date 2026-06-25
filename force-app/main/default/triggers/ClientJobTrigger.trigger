trigger ClientJobTrigger on StorageVault__ClientJob__c (before insert, before update) {
    for (StorageVault__ClientJob__c obj : Trigger.new) {
        obj.StorageVault__CreateTS__c = Datetime.now().format('yyyyMMddHHmmssSSS');
    }
}