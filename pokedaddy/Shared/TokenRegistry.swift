//
//  TokenRegistry.swift
//  PokeDaddy
//
//  Stores a mapping from bundle ID -> ApplicationToken in the App Group,
//  populated by the Shield Action extension when the user taps on a blocked app.
//

import Foundation
// Placeholder file retained to keep project references stable.
// Token -> bundle mapping across app/extension is not supported because ApplicationToken
// isn’t encodable or archivable. The flow now relies on AppGroupBridge.allowedBundles
// and shield exceptions set by the action extension.
import Foundation

enum TokenRegistry {}
