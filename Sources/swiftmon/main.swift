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

let urlStrs = [
    "https://www.testjsonapi.com/products",
    "https://www.testjsonapi.com/products",
    "https://www.testjsonapi.com/products",
]

let session = URLSession.shared

func doPoll() {
    let healthData = HealthData()

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

doPoll()

//Thread.sleep(forTimeInterval: 300)


//let url = URL(string: urlStr)!

// group is used to wait for the task to finish before existing the program
// a real app polling wouldn't use a DispatchGroup (Barrier), or would use it very differently
/* let group = DispatchGroup() */
/* group.enter() */

/*
let task = session.dataTask(with: url) { data, response, error in
    defer {
        group.leave()
    }

    if let err = error {
        print("Client error! \(err)")
        return
    }

    if data == nil {
        print("Client error! Data was nil!")
        return
    }


    guard let response = response as? HTTPURLResponse else {
        print("Server error! Server returned a nil response!")
        return
    }

    guard (200...299).contains(response.statusCode) else {
        print(String(format: "Server error! Server returned code %d", response.statusCode))
        return
    }

    guard let mime = response.mimeType else {
        print("Server returned nil mime type!")
        return
    }

//    let expectedMime = "text/html"
    let expectedMime = "application/json"

    guard mime == expectedMime else {
        print("Wrong MIME type! got '\(mime)'")
        return
    }

    guard let dat = data else {
        print("Server returned nil data!")
        return
    }

//    guard let datStr = String(data: dat, encoding: String.Encoding.utf8) else {
//        print("Server returned data that was malformed utf8")
//        return
//    }

    // print("got data: '''\(datStr)'''")

    do {
        let json = try JSONSerialization.jsonObject(with: dat, options: [])
        print("got data: '''\(json)'''")
//        print(json)

        if let jsonResult = try JSONSerialization.jsonObject(with: dat, options: []) as? NSDictionary {
            print(jsonResult)
        }

    } catch {
        print("JSON error: \(error.localizedDescription)")
    }
}
*/

//print("Resuming task")
//task.resume()
//print("Resumed task")
//// wait for http request task to finish
//group.wait()
//print("Finished task")
