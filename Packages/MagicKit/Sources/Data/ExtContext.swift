import Foundation
import SwiftData
import OSLog

/// Extension that provides additional utility methods for SwiftData's ModelContext
extension ModelContext {
    /// Fetches all instances of the specified model type from the persistent store
    ///
    /// - Returns: An array containing all instances of the specified model type
    /// - Throws: An error if the fetch operation fails
    ///
    /// # Example
    /// ```swift
    /// let context = ModelContext(...)
    /// let allBooks: [Book] = try context.all()
    /// ```
    public func all<T: PersistentModel>() throws -> [T] {
        try self.fetch(FetchDescriptor<T>())
    }
    
    /// Fetches a paginated subset of model instances
    ///
    /// - Parameters:
    ///   - page: The page number to fetch (1-based indexing)
    ///   - descriptor: Optional custom fetch descriptor. If nil, a default descriptor will be used
    ///   - pageSize: Number of items per page (defaults to 10)
    /// - Returns: An array containing the requested page of model instances
    /// - Throws: An error if the fetch operation fails
    ///
    /// # Example
    /// ```swift
    /// let context = ModelContext(...)
    /// let page2Books: [Book] = try context.paginate(page: 2, pageSize: 20)
    /// ```
    public func paginate<T: PersistentModel>(page: Int, descriptor: FetchDescriptor<T>? = nil, pageSize: Int = 10) throws -> [T] {
        let offset = (page-1) * pageSize
        var fetchDescriptor: FetchDescriptor<T>
        
        if let descriptor = descriptor {
            fetchDescriptor = descriptor
        } else {
            fetchDescriptor = FetchDescriptor<T>()
        }
        
        fetchDescriptor.fetchLimit = pageSize
        fetchDescriptor.fetchOffset = offset
        
        return try fetch(fetchDescriptor)
    }

    /// Counts the number of model instances matching the specified predicate
    ///
    /// - Parameter predicate: The predicate to filter the models
    /// - Returns: The count of matching model instances
    /// - Throws: An error if the count operation fails
    public func getCount<T: PersistentModel>(for predicate: Predicate<T>) throws -> Int {
        try fetchCount(FetchDescriptor<T>(predicate: predicate))
    }

    /// Fetches model instances matching the specified predicate
    ///
    /// - Parameter predicate: The predicate to filter the models
    /// - Returns: An array of matching model instances
    /// - Throws: An error if the fetch operation fails
    public func get<T: PersistentModel>(for predicate: Predicate<T>) throws -> [T] {
        try fetch(FetchDescriptor<T>(predicate: predicate))
    }

    /// Counts the total number of instances for a specific model type
    ///
    /// - Parameter model: The model type to count
    /// - Returns: The total count of instances
    /// - Throws: An error if the count operation fails
    public func count<T>(for model: T.Type) throws -> Int where T: PersistentModel {
        try fetchCount(FetchDescriptor<T>(predicate: .true))
    }
    
    /// Inserts a model instance and immediately saves the context
    ///
    /// - Parameter model: The model instance to insert
    /// - Throws: An error if the insert or save operation fails
    public func insertAndSave(_ model: any PersistentModel) throws {
        insert(model)
        try save()
    }
    
    /// Deletes all instances of a specific model type
    ///
    /// - Parameter model: The model type to delete
    /// - Throws: An error if the delete operation fails
    public func destroy<T>(for model: T.Type) throws where T: PersistentModel {
        try delete(model: T.self)
    }
}
