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
            resources.add(new Map<String,Object>{'uri'=>config.resourceUri,'name'=>config.key,'title'=>config.displayName,'description'=>config.description,'mimeType'=>'text/html;profile=mcp-app','size'=>assetSizes.get(config.staticResourceName),'_meta'=>resourceMetadata(orgOrigin,lightningOrigin,config.description)});
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
        Map<String,Object> metadata=resourceMetadata(orgOrigin,lightningOrigin,lightningConfig.description);
        return new Map<String,Object>{'contents'=>new List<Object>{new Map<String,Object>{'uri'=>uri,'mimeType'=>'text/html;profile=mcp-app','text'=>html,'_meta'=>metadata}}};
    }

    private static Map<String,Object> resourceMetadata(String orgOrigin,String lightningOrigin,String description){
        String fileOrigin=orgOrigin.replace('.my.salesforce.com','.file.force.com');
        Map<String,Object> csp=new Map<String,Object>{
            'connectDomains'=>new List<String>{orgOrigin,lightningOrigin},
            'resourceDomains'=>new List<String>{orgOrigin},
            'frameDomains'=>new List<String>{orgOrigin,lightningOrigin,fileOrigin}
        };
        return new Map<String,Object>{'ui'=>new Map<String,Object>{'prefersBorder'=>true,'csp'=>csp}};
    }
}
