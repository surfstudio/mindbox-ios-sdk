//
//  MBDatabaseRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBDatabaseRepository {

    enum MetadataKey: String {
        case install = "ApplicationInstalledVersion"
        case infoUpdate = "ApplicationInfoUpdatedVersion"
        case instanceId = "ApplicationInstanceId"
    }
    
    let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let store: NSPersistentStore
    
    let limit = 10000
    let deprecatedLimit = 500
    
    var onObjectsDidChange: (() -> Void)?
    
    var lifeLimitDate: Date? {
        let calendar: Calendar = .current
        guard let monthLimitDate = calendar.date(byAdding: .month, value: -6, to: Date()) else {
            return nil
        }
        return monthLimitDate
    }

    var infoUpdateVersion: Int? {
        get { getMetadata(forKey: .infoUpdate) }
        set { setMetadata(newValue, forKey: .infoUpdate) }
    }

    var installVersion: Int? {
        get { getMetadata(forKey: .install) }
        set { setMetadata(newValue, forKey: .install) }
    }

    var instanceId: String? {
        get { getMetadata(forKey: .instanceId) }
        set { setMetadata(newValue, forKey: .instanceId) }
    }

    init(persistentContainer: NSPersistentContainer) throws {
        self.persistentContainer = persistentContainer
        if let store = persistentContainer.persistentStoreCoordinator.persistentStores.first {
            self.store = store
        } else {
            Logger.common(message: MBDatabaseError.persistentStoreURLNotFound.errorDescription, level: .error, category: .database)
            throw MBDatabaseError.persistentStoreURLNotFound
        }
        self.context = persistentContainer.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        _ = try countEvents()
    }

    // MARK: - CRUD operations
    func create(event: Event) throws {
        try context.performAndWait {
            let entity = CDEvent(context: context)
            entity.transactionId = event.transactionId
            entity.timestamp = Date().timeIntervalSince1970
            entity.type = event.type.rawValue
            entity.body = event.body
            Logger.common(message: "Creating event with transactionId: \(event.transactionId)", level: .info, category: .database)
            try saveEvent(withContext: context)
        }
    }
    
    func read(by transactionId: String) throws -> CDEvent? {
        try context.performAndWait {
            Logger.common(message: "Reading event with transactionId: \(transactionId)", level: .info, category: .database)
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: transactionId)
            guard let entity = try findEvent(by: request) else {
                Logger.common(message: "Unable to find event with transactionId: \(transactionId)", level: .error, category: .database)
                return nil
            }
            Logger.common(message: "Did read event with transactionId: \(entity.transactionId ?? "undefined")", level: .info, category: .database)
            return entity
        }
    }
    
    func update(event: Event) throws {
        try context.performAndWait {
            Logger.common(message: "Updating event with transactionId: \(event.transactionId)", level: .info, category: .database)
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findEvent(by: request) else {
                Logger.common(message: "Unable to find event with transactionId: \(event.transactionId)", level: .error, category: .database)
                return
            }
            entity.retryTimestamp = Date().timeIntervalSince1970
            try saveEvent(withContext: context)
        }
    }
    
    func delete(event: Event) throws {
        try context.performAndWait {
            Logger.common(message: "Deleting event with transactionId: \(event.transactionId)", level: .info, category: .database)
            let request = CDEvent.fetchRequest(by: event.transactionId)
            guard let entity = try findEvent(by: request) else {
                Logger.common(message: "Unable to find event with transactionId: \(event.transactionId)", level: .error, category: .database)
                return
            }
            context.delete(entity)
            try saveEvent(withContext: context)
        }
    }
    
    func query(fetchLimit: Int, retryDeadline: TimeInterval = 60) throws ->  [Event] {
        try context.performAndWait {
            Logger.common(message: "Quering events with fetchLimit: \(fetchLimit)", level: .info, category: .database)
            let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequestForSend(lifeLimitDate: lifeLimitDate, retryDeadLine: retryDeadline)
            request.fetchLimit = fetchLimit
            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Logger.common(message: "Unable to find events", level: .info, category: .delivery)
                return []
            }
            Logger.common(message: "Did query events count: \(events.count)", level: .info, category: .database)
            return events.compactMap {
                Logger.common(message: "Event with transactionId: \(String(describing: $0.transactionId))", level: .info, category: .database)
                return Event($0)
            }
        }
    }
    
    func query(by request: NSFetchRequest<CDEvent>) throws ->  [CDEvent] {
        try context.fetch(request)
    }
    
    func removeDeprecatedEventsIfNeeded() throws {
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        let context = persistentContainer.newBackgroundContext()
        try delete(by: request, withContext: context)
    }
    
    func countDeprecatedEvents() throws -> Int {
        let context = persistentContainer.newBackgroundContext()
        let request: NSFetchRequest<CDEvent> = CDEvent.deprecatedEventsFetchRequest(lifeLimitDate: lifeLimitDate)
        return try context.performAndWait {
            Logger.common(message: "Counting deprecated elements", level: .info, category: .database)
            do {
                let count = try context.count(for: request)
                Logger.common(message: "Deprecated Events did count: \(count)", level: .info, category: .database)
                return count
            } catch {
                Logger.common(message: "Counting events failed with error: \(error.localizedDescription)", level: .error, category: .database)
                throw error
            }
        }
    }
    
    func erase() throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDEvent")
        let eraseRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        infoUpdateVersion = nil
        installVersion = nil
        try context.performAndWait {
            try context.execute(eraseRequest)
            try saveEvent(withContext: context)
            try countEvents()
        }
    }
    
    @discardableResult
    func countEvents() throws -> Int {
        let request: NSFetchRequest<CDEvent> = CDEvent.countEventsFetchRequest()
        return try context.performAndWait {
            Logger.common(message: "Events count limit: \(limit)", level: .info, category: .database)
            Logger.common(message: "Counting events...", level: .info, category: .database)
            do {
                let count = try context.count(for: request)
                Logger.common(message: "Events count: \(count)", level: .info, category: .database)
                cleanUp(count: count)
                return count
            } catch {
                Logger.common(message: "Counting events failed with error: \(error.localizedDescription)", level: .error, category: .database)
                throw error
            }
        }
    }
    
    private func cleanUp(count: Int) {
        let fetchLimit = count - limit
        guard fetchLimit > .zero else { return }

        let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequestForDelete()
        request.fetchLimit = fetchLimit
        do {
            try delete(by: request, withContext: context)
        } catch {
            Logger.common(message: "Unable to remove elements", level: .error, category: .database)
        }
    }

    private func delete(by request: NSFetchRequest<CDEvent>, withContext context: NSManagedObjectContext) throws {
        try context.performAndWait {
            Logger.common(message: "Finding elements to remove", level: .info, category: .database)

            let events = try context.fetch(request)
            guard !events.isEmpty else {
                Logger.common(message: "Elements to remove not found", level: .info, category: .database)
                return
            }
            events.forEach {
                Logger.common(message: "Remove element with transactionId: \(String(describing: $0.transactionId)) and timestamp: \(Date(timeIntervalSince1970: $0.timestamp))", level: .info, category: .database)
                context.delete($0)
            }
            try saveEvent(withContext: context)
        }
    }

    private func findEvent(by request: NSFetchRequest<CDEvent>) throws -> CDEvent? {
        try context.registeredObjects
            .compactMap { $0 as? CDEvent }
            .filter { !$0.isFault }
            .filter { request.predicate?.evaluate(with: $0) ?? false }
            .first
        ?? context.fetch(request).first
    }

}

// MARK: - ManagedObjectContext save processing
private extension MBDatabaseRepository {

    func saveEvent(withContext context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }

        try saveContext(context)
        onObjectsDidChange?()
    }

    func saveContext(_ context: NSManagedObjectContext) throws {
        do {
            try context.save()
            Logger.common(message: "Context did save", level: .info, category: .database)
        } catch {
            switch error {
            case let error as NSError where error.domain == NSSQLiteErrorDomain && error.code == 13:
                Logger.common(message: "Context did save failed with SQLite Database out of space error: \(error)", level: .error, category: .database)
                fallthrough
            default:
                context.rollback()
                Logger.common(message: "Context did save failed with error: \(error)", level: .error, category: .database)
            }
            throw error
        }
    }

}

// MARK: - Metadata processing
private extension MBDatabaseRepository {

    func getMetadata<T>(forKey key: MetadataKey) -> T? {
        let value = store.metadata[key.rawValue] as? T
        Logger.common(message: "Fetch metadata for key: \(key.rawValue) with value: \(String(describing: value))", level: .info, category: .database)
        return value
    }

    func setMetadata<T>(_ value: T?, forKey key: MetadataKey) {
        store.metadata[key.rawValue] = value
        persistentContainer.persistentStoreCoordinator.setMetadata(store.metadata, for: store)
        do {
            try context.performAndWait {
                try saveContext(context)
                Logger.common(message: "Did save metadata of \(key.rawValue) to: \(String(describing: value))", level: .info, category: .database)            }
        } catch {
            Logger.common(message: "Did save metadata of \(key.rawValue) failed with error: \(error.localizedDescription)", level: .error, category: .database)
        }
    }

}
