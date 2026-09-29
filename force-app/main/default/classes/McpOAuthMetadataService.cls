/** Produces RFC 9728 protected-resource metadata. */
public with sharing class McpOAuthMetadataService {
    public static Map<String,Object> getMetadata(){ McpBridgeCoreConfig config=McpBridgeCoreConfig.get(); return new Map<String,Object>{'resource'=>config.endpointUrl,'authorization_servers'=>new List<String>{config.authorizationIssuer},'scopes_supported'=>config.requiredScopes.split('[, ]+')}; }
}
