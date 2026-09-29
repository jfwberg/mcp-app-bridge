/**
 * Simple reference controller for the MCP record creator/viewer demo.
 *
 * The explicit allowlist is intentional: the example demonstrates dynamic
 * metadata without turning the package into an unrestricted data API.
 */
public with sharing class McpDemoRecordController {
    private static final Map<String, List<String>> ALLOWED_FIELDS = new Map<String, List<String>>{
        'Account' => new List<String>{'Name', 'Industry', 'Type', 'Phone', 'Website', 'BillingCity'},
        'Contact' => new List<String>{'FirstName', 'LastName', 'Email', 'Phone', 'Title'}
    };

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) { this.label = label; this.value = value; }
    }
    public class FieldInfo {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String dataType;
        @AuraEnabled public Boolean required;
        @AuraEnabled public List<Option> options = new List<Option>();
    }
    public class Configuration {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public List<FieldInfo> fields = new List<FieldInfo>();
    }
    public class SaveResult {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public List<Map<String,Object>> records = new List<Map<String,Object>>();
    }
    public class ViewerResult {
        @AuraEnabled public List<Map<String,Object>> columns = new List<Map<String,Object>>();
        @AuraEnabled public List<Map<String,Object>> records = new List<Map<String,Object>>();
    }

    @AuraEnabled(cacheable=true)
    public static Configuration describeDemo(String objectApiName, List<String> requestedFields) {
        Schema.SObjectType objectType = requireAllowedObject(objectApiName);
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        if (!objectDescribe.isAccessible()) throw new AuraHandledException('You do not have access to ' + objectApiName + '.');

        List<String> fields = requestedFields == null || requestedFields.isEmpty()
            ? ALLOWED_FIELDS.get(objectApiName)
            : requestedFields;
        Configuration result = new Configuration();
        result.objectApiName = objectApiName;
        result.objectLabel = objectDescribe.getLabel();
        Map<String, Schema.SObjectField> available = objectDescribe.fields.getMap();
        for (String fieldName : fields) {
            validateAllowedField(objectApiName, fieldName, available);
            Schema.DescribeFieldResult fieldDescribe = available.get(fieldName).getDescribe();
            if (!fieldDescribe.isAccessible()) throw new AuraHandledException('You do not have access to field ' + objectApiName + '.' + fieldName + '.');
            FieldInfo field = new FieldInfo();
            field.apiName = fieldName;
            field.label = fieldDescribe.getLabel();
            field.dataType = fieldDescribe.getType() == Schema.DisplayType.PICKLIST ? 'picklist' :
                fieldDescribe.getType() == Schema.DisplayType.BOOLEAN ? 'checkbox' :
                fieldDescribe.getType() == Schema.DisplayType.EMAIL ? 'email' :
                fieldDescribe.getType() == Schema.DisplayType.PHONE ? 'tel' :
                fieldDescribe.getType() == Schema.DisplayType.URL ? 'url' : 'text';
            field.required = !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate();
            if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST) {
                for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                    if (entry.isActive()) field.options.add(new Option(entry.getLabel(), entry.getValue()));
                }
            }
            result.fields.add(field);
        }
        return result;
    }

    @AuraEnabled
    public static SaveResult createRecords(String objectApiName, String recordsJson) {
        Schema.SObjectType objectType = requireAllowedObject(objectApiName);
        if (!objectType.getDescribe().isCreateable()) throw new AuraHandledException('You do not have permission to create ' + objectApiName + ' records.');
        List<Object> submitted = (List<Object>)JSON.deserializeUntyped(recordsJson);
        if (submitted == null || submitted.isEmpty() || submitted.size() > 3) throw new AuraHandledException('Create between one and three records.');

        Map<String, Schema.SObjectField> available = objectType.getDescribe().fields.getMap();
        List<SObject> records = new List<SObject>();
        for (Object item : submitted) {
            Map<String,Object> values = (Map<String,Object>)item;
            SObject record = objectType.newSObject();
            for (String fieldName : values.keySet()) {
                validateAllowedField(objectApiName, fieldName, available);
                Schema.DescribeFieldResult fieldDescribe = available.get(fieldName).getDescribe();
                if (!fieldDescribe.isCreateable()) throw new AuraHandledException('Field is not writable: ' + objectApiName + '.' + fieldName + '.');
                Object value = values.get(fieldName);
                if (value != null && String.valueOf(value).trim() != '') record.put(fieldName, value);
            }
            records.add(record);
        }
        Database.SaveResult[] saved = Database.insert(records, false, AccessLevel.USER_MODE);
        SaveResult result = new SaveResult();
        result.objectApiName = objectApiName;
        for (Integer index = 0; index < saved.size(); index++) {
            if (!saved[index].isSuccess()) throw new AuraHandledException(saved[index].getErrors()[0].getMessage());
            String nameField = objectApiName == 'Contact' ? 'LastName' : 'Name';
            result.records.add(new Map<String,Object>{
                'Id' => saved[index].getId(),
                'Name' => records[index].get(nameField)
            });
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static ViewerResult viewRecords(String objectApiName, List<Id> recordIds, List<String> requestedFields) {
        Schema.SObjectType objectType = requireAllowedObject(objectApiName);
        if (recordIds == null || recordIds.isEmpty()) throw new AuraHandledException('At least one record ID is required.');
        Configuration configuration = describeDemo(objectApiName, requestedFields);
        List<String> fields = new List<String>{'Id'};
        for (FieldInfo field : configuration.fields) if (!fields.contains(field.apiName)) fields.add(field.apiName);
        String query = 'SELECT ' + String.join(fields, ',') + ' FROM ' + objectApiName + ' WHERE Id IN :recordIds ORDER BY CreatedDate DESC';
        List<SObject> queried = Database.queryWithBinds(query, new Map<String,Object>{'recordIds' => recordIds}, AccessLevel.USER_MODE);

        ViewerResult result = new ViewerResult();
        for (String fieldName : fields) {
            String label = fieldName == 'Id' ? 'Record ID' : objectType.getDescribe().fields.getMap().get(fieldName).getDescribe().getLabel();
            result.columns.add(new Map<String,Object>{'label' => label, 'fieldName' => fieldName, 'type' => 'text'});
        }
        for (SObject record : queried) result.records.add(record.getPopulatedFieldsAsMap());
        return result;
    }

    private static Schema.SObjectType requireAllowedObject(String objectApiName) {
        Map<String, Schema.SObjectType> objects = Schema.getGlobalDescribe();
        if (String.isBlank(objectApiName) || !objects.containsKey(objectApiName)) throw new AuraHandledException('Configured Salesforce object does not exist: ' + objectApiName + '.');
        if (!ALLOWED_FIELDS.containsKey(objectApiName)) throw new AuraHandledException('Object is not enabled for this demo: ' + objectApiName + '.');
        return objects.get(objectApiName);
    }

    private static void validateAllowedField(String objectApiName, String fieldName, Map<String, Schema.SObjectField> available) {
        if (String.isBlank(fieldName) || !available.containsKey(fieldName)) throw new AuraHandledException('Configured field does not exist: ' + objectApiName + '.' + fieldName + '.');
        if (!ALLOWED_FIELDS.get(objectApiName).contains(fieldName)) throw new AuraHandledException('Field is not enabled for this demo: ' + objectApiName + '.' + fieldName + '.');
    }
}
