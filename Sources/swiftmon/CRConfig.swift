struct CRConfig : Decodable {
//    var config: [String: AnyObject]
    var contentServers: [String: CRConfigServer] = [:]
    // var contentRouters: [String: CRConfigRouter]
    // var deliveryServices: [String: CRConfigDeliveryService]
    // var edgeLocations: [String: CRConfigLatLon]
    // var routerLocations: [String: CRConfigLatLon]
    // var monitors: [String: CRConfigMonitor]
    // var stats: CRConfigStats
//    var topologies: [String: CRConfigTopology]
}


struct CRConfigServer : Decodable {
    var cacheGroup:       String = ""
    var capabilities:     [String]? = []
    var fqdn:             String = ""
    var hashCount:        Int? = nil
    var hashId:           String? = nil
    var httpsPort:        Int = 0
    var interfaceName:    String = ""
    var ip:               String = ""
    var ip6:              String? = nil
    var locationId:       String = ""
    var port:             Int = 0
    var profile:          String = ""
    var status:           String
    var type:             String = ""
    var deliveryServices: [String: [String]]? = [:]
    var routingDisabled:  Int? = nil
}
