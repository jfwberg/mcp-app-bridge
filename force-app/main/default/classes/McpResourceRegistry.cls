/** Publishes the packaged MCP App HTML resource. */
public with sharing class McpResourceRegistry {
    public static Map<String,Object> listResources(){
        List<Object> resources=new List<Object>();
        List<McpLightningOutConfig> configs=McpLightningOutConfig.listEnabled();
        String orgOrigin=URL.getOrgDomainUrl().toExternalForm();
        String lightningOrigin=orgOrigin.replace('.my.salesforce.com','.lightning.force.com');
        Set<String> assetNames=new Set<String>();
        for(McpLightningOutConfig config:configs){ assetNames.add(config.staticResourceName); }
        Map<String,Integer> assetSizes=new Map<String,Integer>();
        for(StaticResource asset:[SELECT Name,BodyLength FROM StaticResource WHERE Name IN :assetNames WITH USER_MODE]){
            assetSizes.put(asset.Name,asset.BodyLength);
        }
        for(McpLightningOutConfig config:configs){
            Map<String,Object> resource=new Map<String,Object>{'uri'=>config.resourceUri,'name'=>config.key,'title'=>config.displayName,'description'=>config.description,'mimeType'=>'text/html;profile=mcp-app','size'=>assetSizes.get(config.staticResourceName),'_meta'=>resourceMetadata(orgOrigin,lightningOrigin,config.description)};
            // Embedded response size differs from the template's static-resource size.
            if(McpBridgeCoreConfig.get().lo2JsFromStaticResource) resource.remove('size');
            resources.add(resource);
        }
        return new Map<String,Object>{'resources'=>resources};
    }
    public static Map<String,Object> readResource(Map<String,Object> params){
        String uri=(String)params.get('uri');
        McpLightningOutConfig lightningConfig=McpLightningOutConfig.getByResourceUri(uri);
        List<StaticResource> assets=[SELECT Body FROM StaticResource WHERE Name=:lightningConfig.staticResourceName WITH USER_MODE LIMIT 1];
        if(assets.isEmpty()) {
            throw new McpProtocolException(-32603,503,'Configured UI resource is unavailable.');
        }
        StaticResource asset=assets[0];
        String orgOrigin=URL.getOrgDomainUrl().toExternalForm();
        String lightningOrigin=orgOrigin.replace('.my.salesforce.com','.lightning.force.com');
        String html=asset.Body.toString()
            .replace('__MCPAPP_CONFIG_KEY__',JSON.serialize(lightningConfig.key));
        html=embedLoader(html);
        Map<String,Object> metadata=resourceMetadata(orgOrigin,lightningOrigin,lightningConfig.description);
        return new Map<String,Object>{'contents'=>new List<Object>{new Map<String,Object>{'uri'=>uri,'mimeType'=>'text/html;profile=mcp-app','text'=>html,'_meta'=>metadata}}};
    }

    // Execute the packaged loader after bootstrap, without an unauthenticated browser fetch.
    @TestVisible private static String embedLoader(String html){
        String marker='/*__MCPAPP_EMBEDDED_LOADER__*/';
        if(!html.contains(marker)) return html;
        String loader='';
        if(McpBridgeCoreConfig.get().lo2JsFromStaticResource){
            List<StaticResource> assets=[SELECT Body FROM StaticResource WHERE Name='McpLo2Modified' WITH USER_MODE LIMIT 1];
            if(assets.isEmpty()) throw new McpProtocolException(-32603,503,'Configured Lightning Out loader is unavailable.');
            // Prevent resource text from terminating the containing HTML script element.
            loader=assets[0].Body.toString().replaceAll('(?i)</script','<\\/script')+'\nreturn true;\n';
        }
        return html.replace(marker,loader);
    }

    @TestVisible private static Map<String,Object> resourceMetadata(String orgOrigin,String lightningOrigin,String description){
        String fileOrigin='https://'+System.DomainCreator.getContentHostname();
        List<String> resourceDomains=new List<String>{orgOrigin,fileOrigin};
        if(McpBridgeCoreConfig.get().lo2JsFromStaticResource){
            // The resource redirect may pass through Lightning's /visualforce/session endpoint.
            resourceDomains.add(lightningOrigin);
            String typeName=MCP_App_Bridge_Core_Config__mdt.SObjectType.getDescribe().getName();
            String prefix=typeName.substringBefore('MCP_App_Bridge_Core_Config__mdt');
            String packageName=String.isBlank(prefix)?'c':prefix.removeEnd('__');
            // Static resource requests can redirect from My Domain to the package's VF host.
            resourceDomains.add('https://'+System.DomainCreator.getVisualforceHostname(packageName));
        }
        Map<String,Object> csp=new Map<String,Object>{
            'connectDomains'=>new List<String>{orgOrigin,lightningOrigin},
            'resourceDomains'=>resourceDomains,
            'frameDomains'=>new List<String>{orgOrigin,lightningOrigin,fileOrigin}
        };
        return new Map<String,Object>{'ui'=>new Map<String,Object>{'prefersBorder'=>true,'csp'=>csp}};
    }
}
