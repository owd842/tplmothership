// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd apex run --file F:\WORKING\hacking_WORK\DevOps\git_repo\tplmothership\scripts\apex\anonymous_apex_testing.apex --target-org storagevault941@agentforce.com

// https://orgfarm-bd12a2161b-dev-ed.develop.lightning.force.com/sfc/servlet.shepherd/version/download/<ContentVersion_Id>

Datetime dt = Datetime.now();
System.debug('starting -- ' + dt.format('yyyy-MM-dd HH:mm:ss'));

Map<string, string> res = null;

PubNub pb = new PubNub();

System.debug('publishing');
res = pb.publishMessage('test 12341234');

String tt = (string) res.get('timetoken');

System.debug(JSON.serialize(res));

System.debug('receiving');
List<Map<string, string>> rest = pb.receiveMessages(tt);
System.debug('size: ' + rest.size());
System.debug(JSON.serialize(rest));

// System.debug('Response Body: ' + res.getBody());
// System.debug('Serialized Response: ' + JSON.serialize(res));

System.debug('finished');

/*
static List<string> files = FileHelper.GetFilesList();

for (string file : files) {
    System.debug(file);
}
*/


