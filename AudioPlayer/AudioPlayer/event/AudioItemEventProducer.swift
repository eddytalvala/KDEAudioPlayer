//
//  AudioItemEventProducer.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 13/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation

// MARK: - AudioItem+KVO

extension AudioItem {
    //swiftlint:disable variable_name
    /// The list of properties that is observed through KVO.
    fileprivate static var ap_KVOProperties: [String] {
        return ["artist", "title", "album", "trackCount", "trackNumber", "artworkImage"]
    }
}

// MARK: - PlayerEventProducer

/**
 *  An `AudioItemEventProducer` generates event when a property of an `AudioItem` has changed.
 */
class AudioItemEventProducer: NSObject, EventProducer {
    /**
     An `AudioItemEvent` gets generated by `AudioItemEventProducer` when a property of `AudioItem`
     changes.

     - updatedArtist:       `artist` was updated.
     - updatedTitle:        `title` was updated.
     - updatedAlbum:        `album` was updated.
     - updatedTrackCount:   `trackCount` was updated.
     - updatedTrackNumber:  `trackNumber` was updated.
     - updatedArtworkImage: `artworkImage` was updated.
     */
    enum AudioItemEvent: Event {
        case updatedArtist
        case updatedTitle
        case updatedAlbum
        case updatedTrackCount
        case updatedTrackNumber
        case updatedArtworkImage
    }

    /// The player to produce events with.
    /// Note that setting it has the same result as calling `stopProducingEvents`.
    var item: AudioItem? {
        willSet {
            stopProducingEvents()
        }
    }

    /// The listener that will be alerted a new event occured.
    weak var eventListener: EventListener?

    /// A boolean value indicating whether we're currently listening to events on the player.
    private var listening = false

    /**
     Stops producing events on deinitialization.
     */
    deinit {
        stopProducingEvents()
    }

    /**
     Starts listening to the player events.
     */
    func startProducingEvents() {
        guard let item = item, !listening else {
            return
        }

        //Observing AudioItem's property
        for keyPath in AudioItem.ap_KVOProperties {
            item.addObserver(self, forKeyPath: keyPath, options: .new, context: nil)
        }

        listening = true
    }

    /**
     Stops listening to the player events.
     */
    func stopProducingEvents() {
        guard let item = item, listening else {
            return
        }

        //Unobserving AudioItem's property
        for keyPath in AudioItem.ap_KVOProperties {
            item.removeObserver(self, forKeyPath: keyPath)
        }

        listening = false
    }

    /**
     This message is sent to the receiver when the value at the specified key path relative
     to the given object has changed. The receiver must be registered as an observer for the
     specified `keyPath` and `object`.

     - parameter keyPath: The key path, relative to `object`, to the value that has changed.
     - parameter object:  The source object of the key path `keyPath`.
     - parameter change:  A dictionary that describes the changes that have been made to the value
     of the property at the key path `keyPath` relative to `object`. Entries are described in
     Change Dictionary Keys.
     - parameter context: The value that was provided when the receiver was registered to receive
     key-value observation notifications.
     */
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            switch keyPath {
            case "artist":
                eventListener?.onEvent(AudioItemEvent.updatedArtist, generetedBy: self)
            case "title":
                eventListener?.onEvent(AudioItemEvent.updatedTitle, generetedBy: self)
            case "album":
                eventListener?.onEvent(AudioItemEvent.updatedAlbum, generetedBy: self)
            case "trackCount":
                eventListener?.onEvent(AudioItemEvent.updatedTrackCount, generetedBy: self)
            case "trackNumber":
                eventListener?.onEvent(AudioItemEvent.updatedTrackNumber, generetedBy: self)
            case "artworkImage":
                eventListener?.onEvent(AudioItemEvent.updatedArtworkImage, generetedBy: self)
            default:
                break
            }
        }
    }
}
