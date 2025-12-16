//
//  Actor.swift
//  iOSExample
//
//  Created by Om More on 16/10/25.
//

import Foundation
import SwiftData

@ModelActor
public actor SwiftDataActor: ObservableObject {

    private func insert_<T: PersistentModel>(_ m: T) {
        modelContext.insert(m)
    }

    private func save_() throws {
        try modelContext.save()
    }

    private func fetch_<T: PersistentModel>(_ d: FetchDescriptor<T>) throws -> [T] {
        return try modelContext.fetch(d)
    }

    private func delete_<T: PersistentModel>(_ m: T) {
        modelContext.delete(m)
    }

    private func deleteAll_<T: PersistentModel>(_ type: T.Type) throws {
        try modelContext.delete(model: type)
    }


    nonisolated func insert<T: PersistentModel>(_ m: T) {
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            await self.insert_(m)
            semaphore.signal()
        }

        semaphore.wait()
    }

    nonisolated func save() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var thrownError: Error?

        Task {
            do {
                try await self.save_()
            } catch {
                thrownError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = thrownError {
            throw error
        }
    }

    nonisolated func fetch<T: PersistentModel>(
        _ d: FetchDescriptor<T>
    ) throws -> [T] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [T]?
        var thrownError: Error?

        Task {
            do {
                result = try await self.fetch_(d)
            } catch {
                thrownError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = thrownError {
            throw error
        }

        guard let result = result else {
            fatalError("fetch_ completed but returned no result")
        }

        return result
    }

    nonisolated func delete<T: PersistentModel>(_ m: T) {
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            await self.delete_(m)
            semaphore.signal()
        }

        semaphore.wait()
    }

    nonisolated func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var thrownError: Error?

        Task {
            do {
                try await self.deleteAll_(type)
            } catch {
                thrownError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = thrownError {
            throw error
        }
    }
}

// Public convenience initializer for previews/tests that forwards to the
// synthesized @ModelActor initializer without shadowing it.
public extension SwiftDataActor {
    nonisolated init(previewModelContainer container: ModelContainer) {
        self.init(modelContainer: container)
    }
}


/*

 // From synchronous context (like gomobile callbacks):

 let actor = SwiftDataActor(modelContainer: container)

 // Insert (blocking)
 let message = ChatMessage(...)
 actor.insert_(message)

 // Save (blocking, throws)
 try actor.save_()

 // Fetch (blocking, returns result, throws)
 let descriptor = FetchDescriptor<ChatMessage>(
     predicate: #Predicate { $0.id == messageId }
 )
 let messages = try actor.fetch_(descriptor)

 // Delete (blocking)
 actor.delete_(message)

 */
