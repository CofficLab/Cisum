# PluginBookDBData

`PluginBookDBData` is the audiobook database layer for Cisum.

It owns the SwiftData container, `BookDB`, the cached `BookRepo`, and the
storage-location lifecycle. Other plugins access the book database through
`ProviderBook.BookDatabaseProviding` registered in the Kernel.

The audiobook UI lives in `PluginBookDB`; this package intentionally has no
SwiftUI views or settings contributions.
