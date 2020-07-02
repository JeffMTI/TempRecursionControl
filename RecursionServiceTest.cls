@IsTest
private class RecursionServiceTest {

    @IsTest
    static void batchTest() {

        String settingName = 'Test';

        RecursionControl__c txnSetting = new RecursionControl__c(Name = settingName);
        insert txnSetting;

        System.assertNotEquals(null, RecursionControl__c.getInstance(settingName), 'RecursionControl setting was not created.');

        RecursionService r = new RecursionService();
        r.str_SOQL = 'SELECT Id from RecursionControl__c ';

        Test.startTest();
        Database.executeBatch(r);
        Test.stopTest();

        System.assertEquals(null, RecursionControl__c.getInstance(settingName), 'RecursionControl setting was not deleted.');
    }

    @IsTest
    static void schedulableTest(){

        String settingName = 'Test';

        RecursionControl__c txnSetting = new RecursionControl__c(Name = settingName);
        insert txnSetting;

        Test.setCreatedDate(txnSetting.Id, DateTime.now().addDays(-2));

        System.assertNotEquals(null, RecursionControl__c.getInstance(settingName), 'RecursionControl setting was not created.');

        Test.startTest();
            Datetime dt = Datetime.now().addMinutes(1);
            String sch = '0 '+ dt.minute() + ' * ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
            RecursionService rs = new RecursionService();
            System.schedule('RecursionService Cleanup', sch, rs);
            System.assertEquals(1, [SELECT count() FROM CronTrigger], 'A job should have been scheduled');

            // now call the batch to see if the hardcoded SOQL works
            rs.execute(null);
        Test.stopTest();

        System.assertEquals(null, RecursionControl__c.getInstance(settingName), 'RecursionControl setting was not deleted.');

    }
}