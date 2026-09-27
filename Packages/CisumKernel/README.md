# Kernel ownership

Cisum does not define a private kernel package. All plugin lifecycle, provider registration, and service resolution use the pinned `KernelCore` product from the shared `LumiKernel` package, matching the sibling applications.

`FactoryCisum` is the app's only composition root: it registers Cisum providers and plugins with the shared kernel. `Provider*` packages own app-facing services and UI integration, `Plugin*` packages own feature behavior, and `Kit*` packages hold reusable foundations. This directory is documentation only; it is not a Swift package.
