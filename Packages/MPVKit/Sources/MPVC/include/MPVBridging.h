// MPVBridging.h
// C bridging header for libmpv client and render APIs.

#ifndef MPVBRIDGING_H
#define MPVBRIDGING_H

// Disable deprecation warnings for mpv API
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"

// Import local headers (already copied to include/)
#import "client.h"
#import "render.h"
#import "render_gl.h"

#pragma clang diagnostic pop

#endif /* MPVBRIDGING_H */