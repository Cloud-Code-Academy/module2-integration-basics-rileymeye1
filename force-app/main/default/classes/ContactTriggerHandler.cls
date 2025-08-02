public with sharing class ContactTriggerHandler {

    public static void beforeInsert(List<Contact> newContacts) {
        Integer min = 0;
        Integer max = 100;

        for (Contact con : newContacts) {
            // if DummyJSON_Id__c is null, generate a random number between 0 and 100 and set this as the contact's DummyJSON_Id__c value
            if (con.DummyJSON_Id__c == null) {
                con.DummyJSON_Id__c = String.valueOf((Integer) Math.floor(Math.random() * (max - min + 1 ) + min));
            }
        }
    }

    public static void afterInsert(List<Contact> newContacts) {
        Set<String> contactsToProcess = new Set<String>();
        for (Contact cont : newContacts) {
            // if DummyJSON_Id__c is less than or equal to 100, call the getDummyJSONUserFromId API
            if (cont.DummyJSON_Id__c != null && Integer.valueOf(cont.DummyJSON_Id__c) <= 100) {
                contactsToProcess.add(cont.DummyJSON_Id__c);
            }
        }

        if (!contactsToProcess.isEmpty()) {
            // This check prevents recursive calls
            if (System.isFuture()) {
                return;
            }

            DummyJSONCallout.processContactsUserIds(contactsToProcess);
        }
    }

    public static void afterUpdate(List<Contact> newContacts) {
        Set<Id> contactIdsToProcess = new Set<Id>();
        for (Contact cont : newContacts) {
            // if DummyJSON_Id__c is greater than 100, call the postCreateDummyJSONUser API
            if (cont.DummyJSON_Id__c != null && Integer.valueOf(cont.DummyJSON_Id__c) > 100) {
                contactIdsToProcess.add(cont.Id);
            }
        }

        if (!contactIdsToProcess.isEmpty()) {
            // This check prevents recursive calls
            if (System.isFuture()) {
                return;
            }

            DummyJSONCallout.createDummyJSONUserFromContId(contactIdsToProcess);
        }
    }
}