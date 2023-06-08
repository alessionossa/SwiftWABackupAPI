//
//  SwiftWABackupAPI.swift
//
//
//  Created by Domingo Gallardo on 24/05/23.
//

import Foundation
import GRDB

public enum ChatType: String {
    case group = "Group"
    case individual = "Individual"
    case unknown
}

public struct ChatInfo: CustomStringConvertible {
    let id: Int
    let contactJid: String
    let name: String
    let numberMessages: Int
    let lastMessageDate: Date

    public var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        let localDateString = dateFormatter.string(from: lastMessageDate)

        return "Chat: ID - \(id), ContactJid - \(contactJid), " 
            + "Name - \(name), Number of Messages - \(numberMessages), "
            + "Last Message Date - \(localDateString)"
        }
}

struct DatabaseUtils {
    static func connectToDatabase(at path: String) -> DatabaseQueue? {
        do {
            let dbQueue = try DatabaseQueue(path: path)
            return dbQueue
        } catch {
            print("Cannot connect to db at path: \(path). Error: \(error)")
            return nil
        }
    }
}

public struct ChatDb {
    let database: DatabaseQueue
    init(database: DatabaseQueue) {
        self.database = database
    }
}

public class WABackup {

    let phoneBackup = BackupManager()

    public init() {}    
    
    // This function checks if any local backups exist at the default backup path.
    public func hasLocalBackups() -> Bool {
        return phoneBackup.hasLocalBackups()
    }

    /* 
     The function needs permission to access ~/Library/Application Support/MobileSync/Backup/
     Go to System Preferences -> Security & Privacy -> Full Disk Access
    */
    public func getLocalBackups() -> [IPhoneBackup] {
        return phoneBackup.getLocalBackups()
    }

    /*
     This function obtain the URL of the ChatStorage.sqlite file in a backup, intializes
     the chatStoragePath variable and connects the chatStorageDb to it.
    */
    public func connectChatStorageDb(from iPhoneBackup: IPhoneBackup) -> ChatDb? {
        guard let chatStorageUrl = phoneBackup.getChatStorageUrl(backupUrl: iPhoneBackup.url) else {
            print("Error: No ChatStorage.sqlite file found in backup")
            return nil
        }

        guard let chatStorageDb = DatabaseUtils.connectToDatabase(at: chatStorageUrl.path) else {
            print("Error: Cannot connect to ChatStorage.sqlite file")
            return nil
        }
        
        return ChatDb(database: chatStorageDb)
    }


    public func getChats(from chatDb: ChatDb) -> [ChatInfo]? {

        let db = chatDb.database

        var chatInfos: [ChatInfo] = []
        
        do {
            try db.read { db in
                let chatSessions = try Row.fetchAll(db, sql: "SELECT * FROM ZWACHATSESSION")
                for session in chatSessions {
                    let chatId = session["Z_PK"] as? Int64 ?? 0
                    let contactJid = session["ZCONTACTJID"] as? String ?? "Unknown"
                    let chatName = session["ZPARTNERNAME"] as? String ?? "Unknown"
                    let lastMessageDate = convertTimestampToDate(timestamp: session["ZLASTMESSAGEDATE"] as Any)
                    let numberChatMessages = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ZWAMESSAGE WHERE ZCHATSESSION = ?", arguments: [chatId]) ?? 0
                    if numberChatMessages != 0 {
                        let chatInfo = ChatInfo(id: Int(chatId), contactJid: contactJid, name: chatName, numberMessages: numberChatMessages, lastMessageDate: lastMessageDate)
                        chatInfos.append(chatInfo)
                    }
                }
            }
            return chatInfos
        } catch {
            print("Database access error: \(error)")
            return nil
        }
    }

    private func convertTimestampToDate(timestamp: Any) -> Date {
        if let timestamp = timestamp as? Double {
            return Date(timeIntervalSinceReferenceDate: timestamp)
        } else if let timestamp = timestamp as? Int64 {
            return Date(timeIntervalSinceReferenceDate: Double(timestamp))
        }
        return Date(timeIntervalSinceReferenceDate: 0)
    }
}
