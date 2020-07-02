global class RecursionService implements Schedulable, Database.Batchable<SObject> {

    //// Static single-pass recursion control

    private static Set<String> flags = new Set<String>();

    public static void setFlag(String theFlag){
        flags.add(theFlag.toUpperCase());
    }

    public static Boolean isFlagSet(String theFlag){
        return flags.contains(theFlag.toUpperCase());
    }

    public static void clearFlag(String theFlag){
        flags.remove(theFlag.toUpperCase());
    }

    //// END Static single-pass recursion control

    /// For Batchable execution of this class
    public String str_SOQL;
    private Datetime cutOff;

    global RecursionService(){
        cutOff = Datetime.now().addHours(-24);
        str_SOQL = 'SELECT Id from RecursionControl__c WHERE CreatedDate < :cutOff ';
    }

    /// END For Batchable execution of this class

    ////// Multi-pass RecursionService methods

    private static String txnKey;
    private static String txnKeyCheckValue;
    private static Map<String, Set<Id>> scopeToPrevIDs = new Map<String, Set<Id>> ();

    /***
     * The main entry to get a list of record IDs that have not yet passed through this code path
     *
     * @param txnScopeTag - a String to categorize the code path
     * @param currentIds - a Set of Ids that the code is being asked to process
     *
     * @return - a Set of Ids from the proposed IDs that this code path has not seen yet
     */
    public static Set<Id> getIdsToProcess(String txnScopeTag, Set<Id> currentIds) {

        confirmTxn();

        if (scopeToPrevIDs.containsKey(txnScopeTag.toUpperCase())) {

            // get a short list of the currentIDs we've never seen before
            Set<Id> newIds = new Set<Id>(currentIds);
            newIds.removeAll(scopeToPrevIDs.get(txnScopeTag.toUpperCase()));

            // add the new ones to the scope
            scopeToPrevIDs.get(txnScopeTag).addAll(newIds);

            // return just the new ones
            return newIds;
        } else {
            scopeToPrevIDs.put(txnScopeTag.toUpperCase(),new set<Id>(currentIds));
            return currentIds;
        }
    }

    /***
     * To determine if a single recordID has been processed by a code path
     *
     * @param txnScopeTag - a String to categorize the code path
     * @param recId - the record ID to check
     *
     * @return - TRUE if the record has been processed by the code path, FALSE otherwise
     */
    public static Boolean thisIdHasBeenProcessed(String txnScopeTag, Id recId){

        return (scopeToPrevIDs.containsKey(txnScopeTag.toUpperCase())
                && scopeToPrevIDs.get(txnScopeTag.toUpperCase()).contains(recId));
    }

    private static void confirmTxn() {
        if (txnKeyCheckValue == null || (RecursionControl__c.getInstance(txnKeyCheckValue) == null)) {
            initTxn();
        }
    }

    // This DML will get rolled back in an AllOrNone = false if there are failures and Platform needs to retry.
    private static void initTxn(){
        scopeToPrevIDs.clear();
        txnKeyCheckValue = getTxnKey();
        RecursionControl__c txnSetting = new RecursionControl__c(Name = txnKeyCheckValue);
        insert txnSetting;
    }

    private static String getTxnKey() {
        return (txnKey != null ? txnKey : (txnKey = (UserInfo.getName() + '-' + String.valueOf(Datetime.now().millisecond()))));
    }


    ////// END RecursionService transaction methods

    ////// Batchable methods

    global database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(str_SOQL);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope){
        delete scope;
    }


    global void finish(Database.BatchableContext BC)
    {
        AsyncApexJob a = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
        FROM AsyncApexJob
        WHERE Id =:BC.getJobId()];

        String emailMessage = 'Your batch job '
                + '[RecursionService Cleanup] '
                + 'has finished.  It executed '
                + a.TotalJobItems
                + ' batches.  ';

        Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {a.CreatedBy.Email};
        mail.setToAddresses(toAddresses);
        mail.setReplyTo('noreply@salesforce.com');
        mail.setSenderDisplayName('Batch Job Summary');
        mail.setSubject('Batch job completed');
        mail.setPlainTextBody(emailMessage);
        mail.setHtmlBody(emailMessage);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>
        { mail });
    }


    ////// END Batchable methods

    ////// Schedulable methods

    global void execute(SchedulableContext ctx) {
        Database.executeBatch(new RecursionService());
    }

    ////// END Schedulable methods

}