//
//  FontManager.swift
//  KeymanEngine
//
//  Created by Gabriel Wong on 2017-11-30.
//  Copyright © 2017 SIL International. All rights reserved.
//

import CoreText
import Foundation

public class FontManager {
  public static let shared = FontManager()

  public private(set) var fonts: [URL: RegisteredFont] = [:]

  public func fontName(at url: URL) -> String? {
    if let font = fonts[url] {
      return font.name
    }
    guard let name = readFontName(at: url) else {
      return nil
    }
    fonts[url] = RegisteredFont(name: name, isRegistered: false)
    return name
  }

  /// Registers all new fonts found in the font path. Call this after you have preloaded all your font files
  /// with `preloadFontFile(atPath:shouldOverwrite:)`
  public func registerCustomFonts() {
    guard let customFonts = customFonts() else {
      return
    }

    for fontURL in customFonts {
      _ = registerFont(at: fontURL)
    }
  }

  /// Unregisters all registered fonts in the font path.
  public func unregisterCustomFonts() {
    guard let customFonts = customFonts() else {
      return
    }

    for fontURL in customFonts {
      _ = unregisterFont(at: fontURL)
    }
  }

  private func customFonts() -> [URL]? {
    let urls: [URL]
    do {
      urls = try FileManager.default.contentsOfDirectory(at: Storage.active.fontDir,
                                                         includingPropertiesForKeys: nil)
    } catch {
      log.error("Failed to list font dir contents: \(error)")
      return nil
    }
    return urls.filter { $0.lastPathComponent.hasFontExtension }
  }

  private func readFontName(at url: URL) -> String? {
    guard let provider = CGDataProvider(url: url as CFURL) else {
      log.error("Failed to open \(url)")
      return nil
    }
    guard let font = CGFont(provider),
      let name = font.postScriptName
    else {
      log.error("Failed to read font at \(url)")
      return nil
    }
    return name as String
  }

  /// - Parameters:
  ///   - url: URL of the font to register
  /// - Returns: Font is registered.
  public func registerFont(at url: URL) -> Bool {
    let fontName: String
    if let font = fonts[url] {
      if font.isRegistered {
        return true
      }
      fontName = font.name
    } else {
      guard let name = readFontName(at: url) else {
        return false
      }
      fontName = name
    }

    let didRegister: Bool
    if !fontExists(fontName) {
      var errorRef: Unmanaged<CFError>?
      didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .none, &errorRef)
      let error = errorRef?.takeRetainedValue() // Releases errorRef
      if !didRegister {
        log.error("Failed to register font at \(url) reason: \(String(describing: error))")
      } else {
        log.info("Registered font at \(url)")
      }
    } else {
      didRegister = false
      log.info("Did not register font at \(url) because font name \(fontName) is already registered")
    }
    let font = RegisteredFont(name: fontName, isRegistered: didRegister)
    fonts[url] = font
    return didRegister
  }

  /// - Parameters:
  ///   - url: URL of the font to unregister
  ///   - fromSystemOnly: Do not remove the font from the list that `FontManager` maintains.
  /// - Returns: Font is no longer registered.
  public func unregisterFont(at url: URL, fromSystemOnly: Bool = true) -> Bool {
    guard var font = fonts[url] else {
      return true
    }

    if font.isRegistered {
      var errorRef: Unmanaged<CFError>?
      let didUnregister = CTFontManagerUnregisterFontsForURL(url as CFURL, .none, &errorRef)
      let error = errorRef?.takeRetainedValue() // Releases errorRef
      if didUnregister {
        log.info("Unregistered font at \(url)")
        font.isRegistered = false
        fonts[url] = font
      } else {
        log.error("Failed to unregister font at \(url) reason: \(String(describing: error))")
      }
    }

    if !font.isRegistered && !fromSystemOnly {
      fonts[url] = nil
    }

    return font.isRegistered
  }

  private func fontExists(_ fontName: String) -> Bool {
    return UIFont.familyNames.contains { familyName in
      UIFont.fontNames(forFamilyName: familyName).contains(fontName)
    }
  }
}