import Foundation
//import FoundationNetworking

enum PollErr : Error {
    case ParseErr(bits: Data)
    case BadMime(mime: String)
    case RespErr(details: Error)
    case NilData
    case NilResp
    case NilURL
    case BadCode(code: Int)
    case NilMime
    case BadProcNetDevFields(count: Int)
    case BadLoadAvgFields(count: Int)
    case BadLoadAvgEntityFields(count: Int)
}

extension PollErr: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .ParseErr(let bits):
            let str = String(decoding: bits, as: UTF8.self)
            return NSLocalizedString(
                "couldn't parse data \(str)",
                comment: ""
            )
        case .BadMime(let mime):
            return NSLocalizedString(
                "Unacceptable mime '\(mime)'",
                comment: ""
            )
        case .RespErr(let details):
            return NSLocalizedString(
                "response error: '\(details)'",
                comment: ""
            )
        case .NilData:
            return NSLocalizedString(
                "response had no data",
                comment: ""
            )
        case .NilResp:
            return NSLocalizedString(
                "response was nil",
                comment: ""
            )
        case .NilURL:
            return NSLocalizedString(
                "URL was nil",
                comment: ""
            )
        case .BadCode(let code):
            return NSLocalizedString(
                "Unacceptable response code \(code)",
                comment: ""
            )
        case .NilMime:
            return NSLocalizedString(
                "Response had no mime type",
                comment: ""
            )
        case .BadProcNetDevFields(let count):
            return NSLocalizedString(
                "proc.net.dev malformed, field count \(count)",
                comment: ""
            )
        case .BadLoadAvgFields(let count):
            return NSLocalizedString(
                "proc.loadavg malformed, field count \(count)",
                comment: ""
            )
        case .BadLoadAvgEntityFields(let count):
            return NSLocalizedString(
                "proc.loadavg entity malformed, field count \(count)",
                comment: ""
            )
        }
    }
}

enum PollResult {
    case success(PollObj)
    case error(String)
}

struct PollObj: Decodable {
    let ats: PollObjAts
    let system: PollObjSystem
    enum CodingKeys: String, CodingKey {
        case ats = "ats"
        case system = "system"
    }
}

struct PollObjAts: Decodable {
    let server: String
}

struct PollObjSystem: Decodable {
    let procLoadAvg: String
    let procNetDev: String
    let infSpeed: Int
    let infName: String
    let configReloadRequests: Int

    enum CodingKeys: String, CodingKey {
        case procLoadAvg = "proc.loadavg"
        case procNetDev = "proc.net.dev"
        case infSpeed = "inf.speed"
        case infName = "inf.name"
        case configReloadRequests = "configReloadRequests"
    }
}

// TODO create session, don't use shared? Test performance? Timeouts etc?
func pollURL(urlStr: String, session: URLSession) throws -> PollObj {

    let maybeURL = URL(string: urlStr)

    guard let url = maybeURL else {
        throw PollErr.NilURL
    }

    // TODO catch and add context to exception

    var data: Data?
    var response: URLResponse?
    var error: Error?
    let group = DispatchGroup()
    group.enter()

    print("pollURL doing dataTask '\(urlStr)'")

    let task = session.dataTask(with: url) { tData, tResponse, tError in
        defer {
            group.leave()
        }

        data = tData
        response = tResponse
        error = tError
    }
    task.resume()
    group.wait()


    guard error == nil else {
       print("pollURL doing '\(urlStr)' err \(error!)")
       throw PollErr.RespErr(details: error!)
    }

    guard let resp = response as? HTTPURLResponse else {
       print("pollURL doing '\(urlStr)' nil resp")
        throw PollErr.NilResp
    }

    guard (200...299).contains(resp.statusCode) else {
       print("pollURL doing '\(urlStr)' code \(resp.statusCode)")
        throw PollErr.BadCode(code: resp.statusCode)
    }

    guard let mime = resp.mimeType else {
        print("pollURL doing '\(urlStr)' nil mime")
        throw PollErr.NilMime
    }

   // let expectedMime = "text/html"
   let expectedMime = "text/json"
   // let expectedMime = "application/json"

    guard mime == expectedMime else {
        print("pollURL doing '\(urlStr)' bad mime '\(mime)'")
        throw PollErr.BadMime(mime: mime)
    }

    guard let dat = data else {
        throw PollErr.NilData
    }

    var pollRes: PollObj
    do {
        // let datStr = String(decoding: dat, as: UTF8.self)
        // print("got data '\(datStr)'")
        let decoder = JSONDecoder()
        pollRes = try decoder.decode(PollObj.self, from: dat)
        print("got pollRes '\(pollRes)'")
     } catch {
        print("pollURL JSON error '\(urlStr)' error '\(error.localizedDescription)'")
        throw PollErr.ParseErr(bits: dat)
    }
    // print("pollURL '\(urlStr)' got pollRes")
    return pollRes
}

// pollCaches polls all URLs in parallel, waits for them all to finish, and returns the results
func pollCaches(caches: [PollCache], session: URLSession) throws -> [(PollCache, PollResult)] {
    var pollObjs: [(PollCache, PollResult)] = []
    let lock: NSLock = NSLock() // change to read-write lock (pthread_wrlock_t)

     // TODO get and pass path and scheme from TO
//    let path = "/products"
    let queue = DispatchQueue(label: "com.mytask", attributes: .concurrent)

    let group = DispatchGroup()
    for cache in caches {
        group.enter()
    }

    for cache in caches {
        queue.async {
            defer {
                group.leave()
            }

            // TODO read monitoring.json param for path
            let path = "/_astats?application=system&inf.name=" + cache.interface
            let scheme = "http"

            var pollResult: PollObj
            let url = scheme + "://" + cache.fqdn + path
            do {
                print("polling '\(url)'")
                pollResult = try pollURL(urlStr: url, session: session)

                lock.lock()
                pollObjs.append( (cache, PollResult.success(pollResult)) )
                lock.unlock()

                print("polled '\(url)': success")
            } catch {
                let errStr = "poll cache '\(cache.name)' error: \(error.localizedDescription)"
                print("error polling '\(url)': \(errStr)")
                lock.lock()
                pollObjs.append( (cache, PollResult.error(errStr)) )
                lock.unlock()
            }
        }
    }

    print("pollCaches waiting")
    group.wait()
    print("pollCaches waited")
    return pollObjs
}

struct CacheHealth: Decodable {
    let system: CacheHealthSystem
}
struct CacheHealthSystem: Decodable {
    let procLoadAvg: String
    let procNetDev: String
    let infSpeed: Int

    enum CodingKeys: String, CodingKey {
        case procLoadAvg = "proc.loadavg"
        case procNetDev = "proc.net.dev"
        case infSpeed = "inf.speed"
    }
}

func poll(healthData: HealthData) {
    let cachesToPoll = getCachesToPoll()

    var pollResults: [(PollCache, PollResult)] = []

    do {
        pollResults = try pollCaches(caches: cachesToPoll, session: session)
    } catch {
        print("poll error: \(error.localizedDescription)")
        return
    }

    print("got pollResults: \(pollResults)")

    // TODO this polls all caches, then sums all their health.
    //      change to sum as we get health, for efficiency.

    let allHealth = getAllHealth(pollResults: pollResults)

//    print("got allHealth: \(allHealth)")

    healthData.lock.lock()
    print("locked healthData")
    for (_, cacheHealth) in allHealth.enumerated() {
      healthData.cacheHealth[cacheHealth.key.name] = cacheHealth.value
    }
    healthData.lock.unlock()
    print("unlocked healthData")

    print("updated healthData: \(healthData)")

}

struct PollCache: Hashable {
    let name: String
    let fqdn: String
    let interface: String

    static func == (lhs: PollCache, rhs: PollCache) -> Bool {
        return lhs.fqdn == rhs.fqdn
    }
}

func getCachesToPoll() -> [PollCache] {
    var caches: [PollCache] = []
    let crc = getCRConfig()

    // debug
    let maxCaches = 10
    var numCaches = 0

    for hostCache in crc.contentServers {
        let cache = hostCache.value
        let name = hostCache.key

        if !typeIsCache(typeStr: cache.type) ||
           !statusIsMonitored(statusStr: cache.status) {
            continue
            }

        // TODO add "distributed tm" cg selection logic here
        caches.append(crcToPollCache(name: name, server: cache))

        print("getCachesToPoll adding cache: '\(cache.fqdn)'")
        numCaches = numCaches + 1
        if numCaches > maxCaches {
            break
        }
    }
    return caches
}

func crcToPollCache(name: String, server: CRConfigServer) -> PollCache {
    return PollCache(name: name, fqdn: server.fqdn, interface: server.interfaceName)
}

func typeIsCache(typeStr: String) -> Bool {
    return typeStr.hasPrefix("EDGE") ||
        typeStr.hasPrefix("MID") ||
        typeStr.hasPrefix("CACHE") // not used yet, but might as well start
}

func statusIsMonitored(statusStr: String) -> Bool {
    return statusStr == "ONLINE" ||
        statusStr != "REPORTED" ||
        statusStr != "ADMIN_DOWN" // we still monitor down caches; just not offline
}

func getCachesToPollDebug() -> [PollCache] {
    var caches: [PollCache] = []

    let cache0 = PollCache(name: "my-cache-0", fqdn: "www.testjsonapi.com", interface: "foo")
    caches.append(cache0)

    let cache1 = PollCache(name: "my-cache-1", fqdn: "www.testjsonapi.com", interface: "foo")
    caches.append(cache1)

    let cache2 = PollCache(name: "my-cache-2", fqdn: "www.testjsonapi.com", interface: "foo")
    caches.append(cache2)

    return caches
}
