import { api, LightningElement } from 'lwc';
import viewRecords from '@salesforce/apex/McpDemoRecordController.viewRecords';

/** Reference viewer used as the second step of the record-creation demo. */
export default class LwcRecordViewer extends LightningElement {
    _objectApiName = 'Account';
    _recordIds = [];
    _fieldNames = [];
    columns = [];
    records = [];
    activity = [];
    errorMessage;
    dispatchMessage;
    _connected = false;
    _reloadScheduled = false;
    _loadVersion = 0;

    @api get objectApiName() { return this._objectApiName; }
    set objectApiName(value) { this._objectApiName = value || 'Account'; this.scheduleReload(); }
    @api get recordIds() { return this._recordIds; }
    set recordIds(value) { this._recordIds = this.parseJson(value, []); this.scheduleReload(); }
    @api get fieldNames() { return this._fieldNames; }
    set fieldNames(value) { this._fieldNames = this.parseJson(value, []); this.scheduleReload(); }
    get hasRecords() { return this.records.length > 0; }
    get hasActivity() { return this.activity.length > 0; }

    async connectedCallback() {
        this._connected = true;
        this.log('Inbound MCP inputs', { objectApiName: this._objectApiName, recordIds: this._recordIds, fieldNames: this._fieldNames });
        await this.loadRecords();
    }

    // Re-query when an MCP host supplies or updates inputs after connection.
    scheduleReload() {
        if (!this._connected || this._reloadScheduled) return;
        this._reloadScheduled = true;
        Promise.resolve().then(() => {
            this._reloadScheduled = false;
            this.log('Updated MCP inputs', { objectApiName: this._objectApiName, recordIds: this._recordIds, fieldNames: this._fieldNames });
            this.loadRecords();
        });
    }

    async loadRecords() {
        const loadVersion = ++this._loadVersion;
        this.errorMessage = undefined;
        try {
            const result = await viewRecords({
                objectApiName: this._objectApiName,
                recordIds: this._recordIds,
                requestedFields: this._fieldNames.length ? this._fieldNames : null
            });
            if (loadVersion !== this._loadVersion) return;
            this.columns = result.columns;
            this.records = result.records;
            this.log('Salesforce records loaded', { count: this.records.length, records: this.records });
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'The records could not be loaded.';
            this.log('Error', { message: this.errorMessage });
        }
    }

    sendToChat() {
        // Apex results can be wrapped by Lightning Web Security. A JSON
        // round-trip makes the event payload plain cross-frame data.
        const payload = JSON.parse(JSON.stringify({
            objectApiName: this._objectApiName,
            records: this.records
        }));
        this.log('Outgoing records_viewed event', payload);
        this.dispatchEvent(new CustomEvent('records_viewed', {
            detail: JSON.stringify(payload), bubbles: true, composed: true
        }));
        this.dispatchMessage = 'The records_viewed event was dispatched to the MCP bridge.';
    }

    parseJson(value, fallback) {
        if (value == null || value === '') return fallback;
        if (typeof value === 'object') return value;
        try { return JSON.parse(value); } catch { return fallback; }
    }
    log(label, value) {
        this.activity = [...this.activity, { id: `${Date.now()}-${this.activity.length}`, label, detail: JSON.stringify(value, null, 2) }];
    }
}
