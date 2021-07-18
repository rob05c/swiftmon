import Foundation

func getAllHealth(pollResults: [(PollCache, PollResult)]) -> [PollCache: Bool] {
  var allHealth: [PollCache: Bool] = [:]
  for cacheObj in pollResults {
    let pollCache = cacheObj.0
    let pollResult = cacheObj.1
    allHealth[cacheObj.0] = getHealth(cacheName: pollCache.name, obj: pollResult)
  }
  return allHealth
}

func getHealth(cacheName: String, obj: PollResult) -> Bool {
    // TODO change to take threshold data, when we have that from TO
    switch obj {
    case .error(let errStr):
        print("getHealth cache '\(cacheName)' unhealthy: poll error '\(errStr)'")
        return false
    case .success(let obj):
        do {
            return try calcHealth(cacheName: cacheName, obj: obj)
        } catch {
            print("getHealth cache '\(cacheName)' unhealthy: calc error '\(error.localizedDescription)'")
            return false
        }
    }
}


// TODO needs to take the previous object, to calculate kbps
// TODO change to return/log reason for mark down / up
func calcHealth(cacheName: String, obj: PollObj) throws -> Bool {
    let loadAvg = try parseLoadAvg(loadAvg: obj.system.procLoadAvg)

    // TODO change to read param
    let Max1MLoadAvg = 5.0

    if loadAvg.Avg1Min > Max1MLoadAvg {
        print("calcHealth cache '\(cacheName)' unhealthy: loadAvg 1m \(loadAvg.Avg1Min) > max \(Max1MLoadAvg)")
        return false
    }

    // TODO change to kbps, with threshold
    let maxTxBytes = 1000000000000000 // debug

    let procNetDev = try parseProcNetDev(pnd: obj.system.procNetDev)
    if procNetDev.TransmitBytes > maxTxBytes {
        print("calcHealth cache '\(cacheName)' unhealthy: transmit bytes \(procNetDev.TransmitBytes) > max \(maxTxBytes)")
        return false
    }

    print("calcHealth cache '\(cacheName)' healthy: within thresholds")
    return true
}

struct ProcNetDev {
    let Interface: String
    let ReceiveBytes: Int
    let ReceivePackets: Int
    let ReceiveErrors: Int
    let ReceiveDropped: Int
    let ReceiveFifoErrors: Int
    let ReceiveLengthErrors: Int
    let ReceivedCompressed: Int
    let Multicast: Int
    let TransmitBytes: Int
    let TransmitPackets: Int
    let TransmitErrors: Int
    let TransmitDropped: Int
    let TransmitFifoErrors: Int
    let Collisions: Int
    let TransmitOtherErrors: Int
    let TransmitCompressed: Int
}

func parseProcNetDev(pnd: String) throws -> ProcNetDev {
  let fields = pnd.split(separator: " ")
  if fields.count != 17 {
      throw PollErr.BadProcNetDevFields(count: fields.count)
  }
  var colonCharSet = CharacterSet.init()
  colonCharSet.insert(":")
  return ProcNetDev(
    Interface: String(fields[0]).trimmingCharacters(in: colonCharSet),
    ReceiveBytes: Int(fields[1])!,
    ReceivePackets: Int(fields[2])!,
    ReceiveErrors: Int(fields[3])!,
    ReceiveDropped: Int(fields[4])!,
    ReceiveFifoErrors: Int(fields[5])!,
    ReceiveLengthErrors: Int(fields[6])!,
    ReceivedCompressed: Int(fields[7])!,
    Multicast: Int(fields[8])!,
    TransmitBytes: Int(fields[9])!,
    TransmitPackets: Int(fields[10])!,
    TransmitErrors: Int(fields[11])!,
    TransmitDropped: Int(fields[12])!,
    TransmitFifoErrors: Int(fields[13])!,
    Collisions: Int(fields[14])!,
    TransmitOtherErrors: Int(fields[15])!,
    TransmitCompressed: Int(fields[16])!
  )
}

// See https://linux.die.net/man/5/proc
struct LoadAvg {
    let Avg1Min: Double
    let Avg5Min: Double
    let Avg15Min: Double
    let ExecutingEntities: Int
    let TotalEntities: Int
    let LatestPID: Int
}

func parseLoadAvg(loadAvg: String) throws -> LoadAvg {
    let fields = loadAvg.split(separator: " ")
    if fields.count != 5 {
        throw PollErr.BadLoadAvgFields(count: fields.count)
    }
    let avg1M = Double(fields[0])!
    let avg5M = Double(fields[1])!
    let avg15M = Double(fields[2])!

    let entityFieldStr = fields[3]
    let entityFields = entityFieldStr.split(separator: "/")
    if entityFields.count != 2 {
        throw PollErr.BadLoadAvgEntityFields(count: fields.count)
    }

    let executingEntities = Int(entityFields[0])!
    let totalEntities = Int(entityFields[1])!

    let latestPID = Int(fields[4])!

    return LoadAvg(
        Avg1Min: avg1M,
        Avg5Min: avg5M,
        Avg15Min: avg15M,
        ExecutingEntities: executingEntities,
        TotalEntities: totalEntities,
        LatestPID: latestPID
    )
}
