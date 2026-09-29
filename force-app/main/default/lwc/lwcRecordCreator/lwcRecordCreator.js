import { api, LightningElement } from 'lwc';
import describeDemo from '@salesforce/apex/McpDemoRecordController.describeDemo';
import createRecords from '@salesforce/apex/McpDemoRecordController.createRecords';

/** Reference LWC showing how MCP tool inputs become editable Salesforce data. */
export default class LwcRecordCreator extends LightningElement {
    _objectApiName = 'Account';
    _recordCount = 1;
    _fieldValues = {};
    _fieldNames = [];
    _allowEditing = true;
    _heading = 'MCP Record Creator';
    configuration;
    rows = [];
    activity = [];
    errorMessage;
    saving = false;
    _connected = false;
    _reloadScheduled = false;
    _loadVersion = 0;

    @api get objectApiName() { return this._objectApiName; }
    set objectApiName(value) { this._objectApiName = value || 'Account'; this.scheduleReload(); }
    @api get recordCount() { return this._recordCount; }
    set recordCount(value) { this._recordCount = Math.max(1, Math.min(3, Number(value) || 1)); this.scheduleReload(); }
    @api get fieldValues() { return this._fieldValues; }
    set fieldValues(value) { this._fieldValues = this.parseJson(value, {}); this.scheduleReload(); }
    @api get fieldNames() { return this._fieldNames; }
    set fieldNames(value) { this._fieldNames = this.parseJson(value, []); this.scheduleReload(); }
    @api get allowEditing() { return this._allowEditing; }
    set allowEditing(value) { this._allowEditing = value !== false && value !== 'false'; this.scheduleReload(); }
    @api get heading() { return this._heading; }
    set heading(value) { this._heading = value || 'MCP Record Creator'; }

    get headingText() { return this._heading; }
    get hasActivity() { return this.activity.length > 0; }

    async connectedCallback() {
        this._connected = true;
        this.log('Inbound MCP inputs', {
            objectApiName: this._objectApiName, recordCount: this._recordCount,
            fieldValues: this._fieldValues, fieldNames: this._fieldNames,
            allowEditing: this._allowEditing, heading: this._heading
        });
        await this.loadConfiguration();
    }

    // MCP hosts may deliver opening tool arguments after the custom element is
    // connected. Coalesce the public-property setters into one form rebuild.
    scheduleReload() {
        if (!this._connected || this._reloadScheduled) return;
        this._reloadScheduled = true;
        Promise.resolve().then(() => {
            this._reloadScheduled = false;
            this.log('Updated MCP inputs', {
                objectApiName: this._objectApiName, recordCount: this._recordCount,
                fieldValues: this._fieldValues, fieldNames: this._fieldNames,
                allowEditing: this._allowEditing, heading: this._heading
            });
            this.loadConfiguration();
        });
    }

    async loadConfiguration() {
        const loadVersion = ++this._loadVersion;
        this.errorMessage = undefined;
        try {
            const configuration = await describeDemo({
                objectApiName: this._objectApiName,
                requestedFields: this._fieldNames.length ? this._fieldNames : null
            });
            if (loadVersion !== this._loadVersion) return;
            this.configuration = configuration;
            this.rows = Array.from({ length: this._recordCount }, (_, index) => ({
                key: `row-${index}`,
                number: index + 1,
                fields: this.configuration.fields.map(field => ({
                    ...field,
                    key: `${index}-${field.apiName}`,
                    rowIndex: index,
                    value: this._fieldValues[field.apiName] ?? '',
                    disabled: !this._allowEditing
                }))
            }));
            this.log('Salesforce metadata validated', {
                object: this.configuration.objectApiName,
                fields: this.configuration.fields.map(field => field.apiName)
            });
        } catch (error) {
            this.showError(error);
        }
    }

    handleValueChange(event) {
        const rowIndex = Number(event.target.dataset.rowIndex);
        const fieldName = event.target.dataset.fieldName;
        const value = event.detail?.value ?? event.target.value;
        this.rows = this.rows.map((row, index) => index !== rowIndex ? row : ({
            ...row,
            fields: row.fields.map(field => field.apiName === fieldName ? { ...field, value } : field)
        }));
        this.log('Form value changed', { row: rowIndex + 1, field: fieldName, value });
    }

    async save() {
        this.errorMessage = undefined;
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
        if (!inputs.reduce((valid, input) => input.reportValidity() && valid, true)) return;
        const records = this.rows.map(row => Object.fromEntries(row.fields.map(field => [field.apiName, field.value])));
        this.log('Save request', { objectApiName: this._objectApiName, records });
        this.saving = true;
        try {
            const result = await createRecords({ objectApiName: this._objectApiName, recordsJson: JSON.stringify(records) });
            this.log('Salesforce records created', result);
            const payload = {
                objectApiName: result.objectApiName,
                recordIds: result.records.map(record => record.Id),
                records: result.records,
                fieldNames: this.configuration.fields.map(field => field.apiName)
            };
            this.log('Outgoing records_created event', payload);
            this.dispatchEvent(new CustomEvent('records_created', {
                detail: JSON.stringify(payload), bubbles: true, composed: true
            }));
        } catch (error) {
            this.showError(error);
        } finally {
            this.saving = false;
        }
    }

    parseJson(value, fallback) {
        if (value == null || value === '') return fallback;
        if (typeof value === 'object') return value;
        try { return JSON.parse(value); } catch { return fallback; }
    }
    showError(error) {
        this.errorMessage = error?.body?.message || error?.message || 'The demo request could not be completed.';
        this.log('Error', { message: this.errorMessage });
    }
    log(label, value) {
        this.activity = [...this.activity, {
            id: `${Date.now()}-${this.activity.length}`,
            label,
            detail: JSON.stringify(value, null, 2)
        }];
    }
}
