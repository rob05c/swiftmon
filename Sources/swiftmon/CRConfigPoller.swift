import Foundation

func loadFileFromLocalPath(_ localFilePath: String) throws -> Data {
    return try Data(contentsOf: URL(fileURLWithPath: localFilePath))
}

// TODO encapsulate somehow
// This is the global shared CRConfig.
// The pointer is updated periodically by the CRConfig Poller.
// Things using its data must always copy the pointer to a new variable (pointer) with crConfigLock.
var crConfig: CRConfig = CRConfig()
let crConfigLock: NSLock = NSLock() // change to read-write lock (pthread_wrlock_t)

func getCRConfig() -> CRConfig {
    crConfigLock.lock()
    defer {
        crConfigLock.unlock()
    }
    var localCRConfig = crConfig
    return localCRConfig
}

func getAndParseCRConfig(fileName: String) {
    var localCRConfig: CRConfig = CRConfig()
    do {
        // TODO change to request from TO
        let data = try loadFileFromLocalPath(fileName)
        let decoder = JSONDecoder()
        localCRConfig = try decoder.decode(CRConfig.self, from: data)
    } catch {
        print("error reading crconfig: \(error)")
        return
    }

//    print("parsed CRConfig: '''\(crConfig)'''")
//    print("parsed CRConfig.")

    crConfigLock.lock()
    defer {
        crConfigLock.unlock()
    }
    crConfig = localCRConfig
    print("refreshed CRConfig")
}


// pollCRConfig starts an infinite CRConfig poller, updating crConfig.
// Does not return.
// TODO return mechanism to stop the poll
func pollCRConfig(fileName: String, queue: DispatchQueue, interval: DispatchTimeInterval) {
    getAndParseCRConfig(fileName: fileName)
    queue.asyncAfter(deadline: DispatchTime.now() + interval) {
        pollCRConfig(fileName: fileName, queue: queue, interval: interval)
    }
}
