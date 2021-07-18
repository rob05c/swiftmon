import Foundation
//import FoundationNetworking

enum PollErr : Error {
    case ParseErr(bits: Data)
    case GenericRespErr
    case BadMime(mime: String)
    case RespErr(details: Error)
    case NilData
    case NilResp
    case NilURL
    case BadCode(code: Int)
    case NilMime
    case BadParseErr
}

typealias PollObj = [PollObjSingle]

struct PollObjSingle: Decodable {
    let id: String
    let product_title: String
    let product_price: String
    let product_image: String
    let product_description: String
    let created_at: String
    let updated_at: String
}

func getHealth(obj: PollObj) -> Bool {
  // debug - TODO change to real health, when PollObj is real
  // TODO change to take threshold data, when we have that from TO
  return obj[0].product_title.hasPrefix("J")
}

func getAllHealth(pollResults: [(PollCache, PollObj)]) -> [PollCache: Bool] {
  var allHealth: [PollCache: Bool] = [:]
  for cacheObj in pollResults {
    allHealth[cacheObj.0] = getHealth(obj: cacheObj.1)
  }
  return allHealth
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
       throw PollErr.RespErr(details: error!)
    }

    guard let resp = response as? HTTPURLResponse else {
        throw PollErr.NilResp
    }

    guard (200...299).contains(resp.statusCode) else {
        throw PollErr.BadCode(code: resp.statusCode)
    }

    guard let mime = resp.mimeType else {
        throw PollErr.NilMime
    }

    /* let expectedMime = "text/html" */
    let expectedMime = "application/json"

    guard mime == expectedMime else {
        throw PollErr.BadMime(mime: mime)
    }

    guard let dat = data else {
        throw PollErr.NilData
    }

        /* guard let datStr = String(data: dat, encoding: String.Encoding.utf8) else { */
        /*     print("Server returned data that was malformed utf8") */
        /*     return */
        /* } */

        /* print("got data: '''\(datStr)'''") */

//    do {
//        let json = try JSONSerialization.jsonObject(with: dat, options: [])
//        print("got data: '''\(json)'''")
//        print(json)]

    let pollRes = try JSONDecoder().decode(PollObj.self, from: dat)

    /* let jsonRaw = try JSONSerialization.jsonObject(with: dat, options: []) */
    /*     print("json ser parse err") */
    /*     throw PollErr.BadParseErr */
    /* } */


    /* guard let jsonResult = jsonRaw as? NSDictionary  else { */
    /*     print("json type parse err: type \(type(of: jsonRaw))") */
    /*     throw PollErr.BadParseErr */
    /* } */

//    let jsonResult = try JSONSerialization.jsonObject(with: dat, options: []) as? NSDictionary  // {

    /* let datStr = String(decoding: dat, as: UTF8.self) */
    /* print("dat: '''\(datStr)'''") */

    /* guard let jsonRes = jsonResult else { */
    /*     /\* throw PollErr.GenericRespErr *\/ */
    /*     throw PollErr.ParseErr(bits: dat) */
    /* } */

//            print(jsonResult)
//        }
    return pollRes
//    } catch {
//        throw PollErr.ParseErr(error.localizedDescription)
//    }
}


// pollCaches polls all URLs in parallel, waits for them all to finish, and returns the results
func pollCaches(caches: [PollCache], session: URLSession) throws -> [(PollCache, PollObj)] {
    var pollObjs: [(PollCache, PollObj)] = []
    var errs: [String] = []
    let lock: NSLock = NSLock() // change to read-write lock (pthread_wrlock_t)

     // TODO get and pass path and scheme from TO
    let path = "/products"
    let scheme = "http"

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

            var pollResult: PollObj = PollObj()
            do {
                let url = scheme + "://" + cache.fqdn + path
                pollResult = try pollURL(urlStr: url, session: session)
            } catch {
                lock.lock()
                errs.append("poll cache '\(cache.name)' error: \(error.localizedDescription)")
                lock.unlock()
                return
            }
            lock.lock()
            pollObjs.append( (cache, pollResult) )
            lock.unlock()
        }
    }

    group.wait()
    return pollObjs
}

class HealthData {
  var cacheHealth: [String: Bool] = [:]
  var lock: NSLock = NSLock() // change to read-write lock (pthread_wrlock_t)
}

struct CacheHealth: Decodable {
    let id: String
    let product_title: String
    let product_price: String
    let product_image: String
    let product_description: String
    let created_at: String
    let updated_at: String
}

func poll(healthData: HealthData) {
    let cachesToPoll = getCachesToPoll()

    var pollResults: [(PollCache, PollObj)] = []

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

    print("got allHealth: \(allHealth)")

    healthData.lock.lock()
    for (_, cacheHealth) in allHealth.enumerated() {
      healthData.cacheHealth[cacheHealth.key.name] = cacheHealth.value
    }
    healthData.lock.unlock()
}

struct PollCache: Hashable {
    let name: String
    let fqdn: String

    static func == (lhs: PollCache, rhs: PollCache) -> Bool {
        return lhs.name == rhs.name && lhs.fqdn == rhs.fqdn
    }
}

// debug - TODO replace with getting the real caches from TO
func getCachesToPoll() -> [PollCache] {
    var caches: [PollCache] = []

    let cache0 = PollCache(name: "my-cache-0", fqdn: "www.testjsonapi.com")
    caches.append(cache0)

    let cache1 = PollCache(name: "my-cache-1", fqdn: "www.testjsonapi.com")
    caches.append(cache1)

    let cache2 = PollCache(name: "my-cache-2", fqdn: "www.testjsonapi.com")
    caches.append(cache2)

    return caches
}
