// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd apex run --file F:\WORKING\hacking_WORK\DevOps\git_repo\tplmothership\scripts\apex\anonymous_apex_testing.apex --target-org storagevault941@agentforce.com

// https://orgfarm-bd12a2161b-dev-ed.develop.lightning.force.com/sfc/servlet.shepherd/version/download/<ContentVersion_Id>

Datetime dt = Datetime.now();
System.debug('starting -- ' + dt.format('yyyy-MM-dd HH:mm:ss'));

List<StorageVault__ClientJob__c> jobs = [ SELECT ID FROM StorageVault__ClientJob__c ];

System.debug('number of jobs: ' + jobs.size());

delete jobs;

/*
static List<string> files = FileHelper.GetFilesList();

for (string file : files) {
    System.debug(file);
}
*/

