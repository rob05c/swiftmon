import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let foo = 42

print(String(format: "Hallo, Welt! foo is %d", foo))

if CommandLine.arguments.count != 2 {
    print("Usage: hello NAME")
    exit(-1)
}

let name = CommandLine.arguments[1]
sayHello(name: name)

let crConfigFileName = "./crc.json"

//let session = URLSession.shared

// TODO make configurable
let sessionConfig = URLSessionConfiguration.default
sessionConfig.timeoutIntervalForRequest = 2.0
sessionConfig.timeoutIntervalForResource = 5.0
let session = URLSession(configuration: sessionConfig)

func doPoll() {
    poll(healthData: healthData)

    var encodedData: Data
    // debug - object to json string
    do {
        encodedData = try JSONEncoder().encode(healthData.cacheHealth)
    } catch {
        print("json encoding error: \(error.localizedDescription)")
        exit(-2)
    }

    let jsonStringMaybe = String(data: encodedData, encoding: .utf8)

    guard let jsonString = jsonStringMaybe else {
        print("json encoding error: got nil string")
        exit(-2)
    }

    print("healthData: \(jsonString)")
}

let crConfigPollQueue = DispatchQueue(label: "com.swiftmon.crconfig-poll-queue", attributes: .concurrent)
let crConfigPollIntervalSeconds: DispatchTimeInterval = DispatchTimeInterval.seconds(5)
pollCRConfig(fileName: crConfigFileName, queue: crConfigPollQueue, interval: crConfigPollIntervalSeconds)

doPoll()

// TODO change to poll for config file changes, or sleep forever, or something
//Thread.sleep(forTimeInterval: 300)

let httpPort = 8080

serveHttp(port: httpPort)
