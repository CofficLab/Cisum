/// Extension that provides additional utility methods for Collection types
extension Collection {
    /// A Boolean value indicating whether the collection contains any elements.
    ///
    /// This is the inverse of `isEmpty` property. Use this property to check if a collection has at least one element.
    ///
    /// - Returns: `true` if the collection contains at least one element; otherwise, `false`.
    ///
    /// - Complexity: O(1)
    ///
    /// # Example
    /// ```swift
    /// let array = [1, 2, 3]
    /// print(array.isNotEmpty) // Prints: true
    ///
    /// let emptyArray: [Int] = []
    /// print(emptyArray.isNotEmpty) // Prints: false
    /// ```
    public var isNotEmpty: Bool {
        self.isEmpty == false
    }
}
