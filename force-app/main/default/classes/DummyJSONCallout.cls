public with sharing class DummyJSONCallout {

	@future(callout=true) // Bulk method for Triggers
	public static void processContactsUserIds(Set<String> dummyJSONUserIds) {
		for (String dummyUserId : dummyJSONUserIds) {
			getDummyJSONUserFromId(dummyUserId);
		}
	}

	public static void getDummyJSONUserFromId(String dummyUserId) {
		// Attempt to retrieve a User by id from the DummyJSON API
		HttpResponse res = sendDummyJSONCallout(dummyUserId, 'GET', '');

		if (res.getStatusCode() >= 200 && res.getStatusCode() <= 299) {
			// If the response is successful, create a Contact record & populate it with data from the Dummy JSON API response
			Contact cont = createContactFromJson(res.getBody());
			cont.DummyJSON_Id__c = dummyUserId;

			// Upsert the Contact using the DummyJSON_Id__c field as the External ID to avoid creating duplicate Contacts
			Schema.SObjectField externalIdField = Contact.Fields.DummyJSON_Id__c;
			Database.upsert(cont, externalIdField, AccessLevel.SYSTEM_MODE);
		} else if (res.getStatusCode() == 404) {
			throw new DummyJSONUserException('DummyJSON UserId Not Found (ID: ' + dummyUserId + ')');
		} else if (res.getStatusCode() >= 500) {
			throw new DummyJSONUserException('Server error occurred. Please try again later.');
		} else {
			throw new DummyJSONUserException('Request failed. Status: ' + res.getStatusCode() + ' - ' + res.getStatus());
		}
	}

	@TestVisible
	private static Contact createContactFromJson(String jsonResponse) {
		// Deserialize the JSON string into an object using the DummyJSONUser wrapper class
		DummyJSONUser newUser = (DummyJSONUser) JSON.deserialize(jsonResponse, DummyJSONUser.class);
		
		// Create a Contact object and populate it with data from the Dummy JSON API response
		Contact newContact = new Contact(
			FirstName = newUser.firstname,
			LastName = newUser.lastname,
			Email = newUser.email,
			Phone = newUser.phone,
			Birthdate = Date.valueOf(newUser.birthDate),
			MailingStreet = newUser.address.address,
			MailingCity = newUser.address.city,
			MailingState = newUser.address.state,
			MailingPostalCode = newUser.address.postalCode,
			MailingCountry = newUser.address.country
		);

		return newContact;
	}

	@future(callout=true) // Bulk method for Triggers
	public static void createDummyJSONUserFromContId(Set<Id> contactIds) {
		for (Id contactId : contactIds) {
			postCreateDummyJSONUser(contactId);
		}
	}

	public static void postCreateDummyJSONUser(Id contactId) {
		// Generate the JSON string from the Contact record data
		String body = generateDummyJsonUserPayload(contactId);
		// Attempt to create the Dummy JSON User from the generated JSON string
		HttpResponse res = sendDummyJSONCallout('add', 'POST', body);

		if (res.getStatusCode() >= 200 && res.getStatusCode() <= 299) {
			// If the HTTP response code is successful, update the contact.
			Contact cont = new Contact(
				Id = contactId,
				DummyJSON_Last_Updated__c = Datetime.now()
			);

			Database.update(cont, AccessLevel.SYSTEM_MODE);
		} else if (res.getStatusCode() >= 500) {
			throw new DummyJSONUserException('Server error occurred. Please try again later.');
		} else {
			throw new DummyJSONUserException('Request failed. Status: ' + res.getStatusCode() + ' - ' + res.getStatus());
		}
	}

	@TestVisible
	private static String generateDummyJsonUserPayload(Id contactId) {
		// Retrieve the Contact record details
		Contact cont = [SELECT Id, FirstName, LastName, Email, Phone FROM Contact WHERE Id = :contactId WITH SYSTEM_MODE LIMIT 1];
		
		// Create a DummyJSONUser object and populate it with data from the retrieved Contact record
		DummyJSONUser newUser = new DummyJSONUser();
		newUser.salesforceId = cont.Id;
		newUser.firstName = String.isNotBlank(cont.FirstName) ? cont.FirstName : 'Unknown';
		newUser.lastname = String.isNotBlank(cont.LastName) ? cont.LastName : 'Unknown';
		newUser.email = String.isNotBlank(cont.Email) ? cont.Email : 'unknown@unknown.com';
		newUser.phone = String.isNotBlank(cont.Phone) ? cont.Phone : '000-000-0000';
		
		// Serialize the DummyJSONUser object to be used in the body of the request
		String body = JSON.serialize(newUser);

		return body;
	}

	// Helper method to centralize HTTP request configuration and execution
	// Implements DRY principle to reduce code duplication
	public static HttpResponse sendDummyJSONCallout(String path, String method, String body) {
		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:DummyJsonUser/' + path);
		req.setMethod(method);
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('Accept', 'application/json');
		req.setTimeout(10000); // 10 seconds

		if (String.isNotBlank(body)) {
			req.setBody(body);
		}

		return http.send(req);
	}

	/**********CUSTOM EXCEPTION CLASSES**********/
	public class DummyJSONUserException extends Exception {}

	/**********WRAPPER CLASSES**********/
	public class DummyJSONUser {
		public Integer id;
		public String firstName;
		public String lastName;
		public String email;
		public String phone;
		public String birthDate;
		public Address address;
		public Id salesforceId;
	}

	public class Address {
		public String address;
		public String city;
		public String state;
		public String postalCode;
		public String country;
	}
}