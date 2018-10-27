// SplashBuddy

/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

protocol InsiderProtocol {
    func run() throws
}

protocol InsiderLineChecker {
    func check(line: String) throws -> Software.SoftwareStatus?
}

class GenericInsider: InsiderProtocol {
    internal let userDefaults: UserDefaults
    
    let logFileHandle: FileHandle?
    let logPath: String
    
    class GenericLineChecker: InsiderLineChecker {
        func check(line: String) throws -> Software.SoftwareStatus? {
            assertionFailure("You must implement your own GenericLineChecker")
            return nil
        }
    }
    
    init(userDefaults: UserDefaults, withLogPath logPath: String) {
        self.userDefaults = userDefaults
        self.logPath = logPath
        
        // TSTJamfLog is meant for unit testing only.
        do {
            self.logFileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: logPath, isDirectory: false))
        } catch {
            Log.write(string: "Cannot read \(logPath), error: \(error)",
                cat: "Preferences",
                level: .error)
            self.logFileHandle = nil
        }
    }
    
    convenience init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.init(userDefaults: userDefaults, withLogPath: "")
    }
    
    func run() throws {
        guard let logFileHandle = self.logFileHandle else {
            Log.write(string: "Cannot check logFileHandle", cat: "Preferences", level: .error)
            return
        }
        
        let lineChecker = try self.lineChecker()
        
        logFileHandle.readabilityHandler = { fileHandle in
            let data = fileHandle.readDataToEndOfFile()
            
            guard let string = String(data: data, encoding: .utf8) else {
                return
            }
            
            for line in string.split(separator: "\n") {
                for name in SoftwareArray.sharedInstance.softwareByNames.keys {
                    if line.contains(name) {
                        do {
                            if let status = try lineChecker.check(line: String(line)) {
                                DispatchQueue.main.async {
                                    if let software = SoftwareArray.sharedInstance.softwareByNames[name] {
                                        software.status = status
                                        SoftwareArray.sharedInstance.array.updateInfo(for: software)
                                    }
                                }
                            }
                        } catch {
                            Preferences.sharedInstance.insiderErrorMessage = "Line check failure"
                            Preferences.sharedInstance.insiderErrorInfo = "\(error.localizedDescription)"
                            Preferences.sharedInstance.insiderError = true
                            break
                        }
                    }
                }
            }
        }
    }
    
    func lineChecker() throws -> InsiderLineChecker {
        return GenericLineChecker()
    }
}
