// Builds a secret-free Microsoft package. Only an OAuth vault reference is supplied.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const folder = path.join(root, 'appPackage');
fs.mkdirSync(folder, {recursive:true});
const write = (name, value) => fs.writeFileSync(path.join(folder, name), JSON.stringify(value, null, 2)+'\n');
const uri = 'ui://mcp-app-bridge/demo-record-creator/v8/index.html';
const salesforce = 'https://ezform-dev-ed.my.salesforce.com';
const endpoint = salesforce + '/services/apexrest/mcpapp/mcp';
const existingPlugin = path.join(folder, 'ai-plugin.json');
const vault = process.env.MCP_OAUTH_VAULT_ID || (fs.existsSync(existingPlugin) ? JSON.parse(fs.readFileSync(existingPlugin,'utf8')).runtimes[0].auth.reference_id : 'REPLACE_WITH_MICROSOFT_OAUTH_REGISTRATION_ID');
const schema = (properties, required) => ({type:'object',additionalProperties:false,properties,required});
const string = {type:'string'};
const tool = (name, title, description, inputSchema, ui) => ({name,title,description,inputSchema,_meta:{ui},securitySchemes:[{type:'oauth2',scopes:['api']}]});
const xml = fs.readFileSync(path.join(root,'force-app/main/default/customMetadata/MCP_App_Bridge_LO2_Config.demo_record_creator.md-meta.xml'),'utf8');
if (!xml.includes(uri)) throw Error('Record Creator resource URI changed: update the pinned package.');
const schemaValue = xml.match(/<field>Input_Schema_JSON__c<\/field>\s*<value[^>]*>([\s\S]*?)<\/value>/i);
if (!schemaValue) throw Error('Cannot find Record Creator input schema in metadata.');
const decodeXml = s => s.replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
const creator = tool('open_demo_record_creator','Open Demo Record Creator','Open an editable form to create up to three Account or Contact records, then send the results back to the conversation.',JSON.parse(decodeXml(schemaValue[1])),{resourceUri:uri,visibility:['model','app']});
creator._meta['ui/resourceUri'] = uri;
const viewerXml = fs.readFileSync(path.join(root,'force-app/main/default/customMetadata/MCP_App_Bridge_LO2_Config.demo_record_viewer.md-meta.xml'),'utf8');
const field = (xml, name) => {
 const match = xml.match(new RegExp('<field>'+name+'</field>\\s*<value[^>]*>([\\s\\S]*?)</value>'));
 if (!match) throw Error('Missing metadata field '+name);
 return decodeXml(match[1]);
};
const viewerUri = field(viewerXml,'Resource_Uri__c');
const viewer = tool('open_demo_record_viewer','Open Demo Record Viewer',field(viewerXml,'Description__c'),JSON.parse(field(viewerXml,'Input_Schema_JSON__c')),{resourceUri:viewerUri,visibility:['model','app']});
viewer._meta['ui/resourceUri'] = viewerUri;
// Subscriber tool: pinned from the EZ Form tools/list trace supplied by the user.
const adminUri = 'ui://xdemo/mcp-admin-friend/v1/index.html';
const admin = tool('open_mcp_admin_friend','Open MCP Admin Friend','Read-only Salesforce administration explorer with optional initial object selection and JSON action events.',{type:'object',additionalProperties:false,properties:{objectApiName:{type:'string',minLength:1,description:'Optional API name of an accessible Salesforce object to select when the widget opens.'}}},{resourceUri:adminUri,visibility:['model','app']});
admin._meta['ui/resourceUri'] = adminUri;
const tools = [creator,viewer,admin,
 tool('bootstrap_lightning_out','Create Lightning Out session','Create a fresh, single-use Salesforce Lightning Out session for the mounted app.',schema({configKey:string},['configKey']),{visibility:['app']}),
 tool('bridge_event','Route component event','Validate and route an event from a configured Lightning Out component.',schema({configKey:string,mappingKey:string,payload:{}},['configKey','mappingKey','payload']),{visibility:['app']}),
 tool('log_bridge_diagnostic','Record bridge diagnostic','Record a sanitized lifecycle milestone from the mounted MCP App.',schema({configKey:string,stage:string,outcome:{type:'string',enum:['SUCCEEDED','FAILED']},message:{type:'string',maxLength:255}},['configKey','stage','outcome']),{visibility:['app']})];
write('ai-plugin.json',{$schema:'https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json',schema_version:'v2.4',name_for_human:'MCP App Bridge',description_for_human:'Create and view Salesforce records and explore administration metadata.',namespace:'MCPAppBridge',functions:tools.map(t=>({name:t.name,description:t.description})),runtimes:[{type:'RemoteMCPServer',spec:{url:endpoint,mcp_tool_description:{tools}},run_for_functions:tools.map(t=>t.name),auth:{type:'OAuthPluginVault',reference_id:vault}}]});
write('declarativeAgent.json',{$schema:'https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.6/schema.json',version:'v1.6',name:'MCP App Bridge',description:'Create and view Salesforce records and explore metadata through three authenticated interfaces.',instructions:'Help the user work with EZ Form Salesforce. Use open_demo_record_viewer to display Account or Contact records when record IDs are supplied; ask for IDs when missing. Use open_mcp_admin_friend for the read-only administration explorer, optionally selecting objectApiName. Call open_demo_record_creator to display the interactive form, using objectApiName and recordCount (1 to 3). Default recordCount to 1 when unspecified. Let the user review and save records in the form. Do not claim records were saved until the application reports success. bootstrap_lightning_out, bridge_event, and log_bridge_diagnostic are application-only callbacks; do not call them yourself.',conversation_starters:[{title:'Create an Account',text:'Open a form to create one Account.'},{title:'View records',text:'Help me display Account records using their Salesforce IDs.'},{title:'Explore Salesforce',text:'Open MCP Admin Friend for Contact.'}],actions:[{id:'mcpAppBridge',file:'ai-plugin.json'}]});
write('manifest.json',{$schema:'https://developer.microsoft.com/en-us/json-schemas/teams/v1.24/MicrosoftTeams.schema.json',manifestVersion:'1.24',version:'1.0.3',id:'6fd0c816-4c64-4828-8a4e-5a76a3d8d91a',developer:{name:'EZ Form',websiteUrl:salesforce,privacyUrl:salesforce,termsOfUseUrl:salesforce},name:{short:'MCP App Bridge',full:'MCP App Bridge for EZ Form'},description:{short:'Create and view records and explore Salesforce metadata.',full:'Three authenticated Salesforce interfaces: Record Creator, Record Viewer, and MCP Admin Friend, using MCP Apps and Lightning Out.'},icons:{outline:'outline.png',color:'color.png'},accentColor:'#0176D3',composeExtensions:[],permissions:['identity','messageTeamMembers'],validDomains:['oauth-proxy.jsts.dev','ezform-dev-ed.my.salesforce.com','ezform-dev-ed.lightning.force.com','ezform-dev-ed.file.force.com'],copilotAgents:{declarativeAgents:[{id:'mcpAppBridge',file:'declarativeAgent.json'}]}});
console.log('Generated appPackage for EZ Form. OAuth registration '+(vault.startsWith('REPLACE_')?'is still required.':'reference configured.'));
