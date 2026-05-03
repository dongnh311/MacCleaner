import Foundation

let listener = NSXPCListener.service()
listener.resume()

RunLoop.main.run()
