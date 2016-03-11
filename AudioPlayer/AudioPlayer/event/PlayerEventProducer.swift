//
//  PlayerEventProducer.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 08/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import AVFoundation

// MARK: - AVPlayer+KVO
private extension AVPlayer {
    /// The list of properties that is observed through KVO.
    static var ap_KVOProperties: [String] {
        return [
            "currentItem.playbackBufferEmpty",
            "currentItem.playbackLikelyToKeepUp",
            "currentItem.duration",
            "currentItem.status",
            "currentItem.loadedTimeRanges"
        ]
    }
}

/**
 *  A `PlayerEventProducer` listens to notifications and observes events generated by an AVPlayer.
 */
class PlayerEventProducer: NSObject, EventProducer {
    /**
       A `PlayerEvent` is an event an player generates over time.

       - StartedBuffering:  The player started buffering the audio file.
       - ReadyToPlay:       The player is ready to play. It buffered enough data.
       - LoadedMoreRange:   The player loaded more range of time.
       - LoadedMetadata:    The player loaded metadata.
       - LoadedDuration:    The player has found audio item duration.
       - Progressed:        The player progressed in its playing.
       - EndedPlaying:      The player ended playing the current item because it went through the
            file or because of an error.
       - InterruptionBegan: The player got interrupted (phone call, Siri, ...).
       - InterruptionEnded: The interruption ended.
       - RouteChanged:      The player's route changed.
       - SessionMessedUp:   The audio session is messed up.
     */
    enum PlayerEvent: Event, Equatable {
        case StartedBuffering
        case ReadyToPlay
        case LoadedMoreRange(CMTime, CMTime)
        case LoadedMetadata([AVMetadataItem])
        case LoadedDuration(CMTime)
        case Progressed(CMTime)
        case EndedPlaying(NSError?)
        case InterruptionBegan
        case InterruptionEnded
        case RouteChanged
        case SessionMessedUp

        private var hash: UInt {
            switch self {
            case .StartedBuffering:
                return 0
            case .ReadyToPlay:
                return 1
            case .LoadedMoreRange:
                return 2
            case .LoadedMetadata:
                return 3
            case .LoadedDuration:
                return 4
            case .Progressed:
                return 5
            case .EndedPlaying(let err):
                if let _ = err {
                    return 6
                }
                return 7
            case .InterruptionBegan:
                return 8
            case .InterruptionEnded:
                return 9
            case .RouteChanged:
                return 10
            case .SessionMessedUp:
                return 11
            }
        }
    }

    /// The player to produce events with.
    /// Note that setting it has the same result as calling `stopProducingEvents`.
    var player: AVPlayer? {
        willSet {
            stopProducingEvents()
        }
    }

    /// The listener that will be alerted a new event occured.
    weak var eventListener: EventListener?

    /// The time observer for the player.
    private var timeObserver: AnyObject?

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
        guard let player = player where !listening else {
            return
        }
        
        //Observing notifications sent through `NSNotificationCenter`
        let center = NSNotificationCenter.defaultCenter()
        #if os(iOS) || os(tvOS)
            center.addObserver(self, selector: "audioSessionGotInterrupted:",
                name: AVAudioSessionInterruptionNotification, object: player)
            center.addObserver(self, selector: "audioSessionRouteChanged:",
                name: AVAudioSessionRouteChangeNotification, object: player)
            center.addObserver(self, selector: "audioSessionMessedUp:",
                name: AVAudioSessionMediaServicesWereLostNotification, object: player)
            center.addObserver(self, selector: "audioSessionMessedUp:",
                name: AVAudioSessionMediaServicesWereResetNotification, object: player)
        #endif
        center.addObserver(self, selector: "playerItemDidEnd:",
            name: AVPlayerItemDidPlayToEndTimeNotification, object: player)

        //Observing AVPlayer's property
        for keyPath in AVPlayer.ap_KVOProperties {
            player.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
        }

        //Observing timing event
        timeObserver = player.addPeriodicTimeObserverForInterval(CMTimeMake(1, 2),
            queue: dispatch_get_main_queue()) { [weak self] time in
                if let strongSelf = self {
                    self?.eventListener?.onEvent(PlayerEvent.Progressed(time),
                        generetedBy: strongSelf)
                }
        }

        listening = true
    }

    /**
     Stops listening to the player events.
     */
    func stopProducingEvents() {
        guard let player = player where listening else {
            return
        }

        //Unobserving notifications sent through `NSNotificationCenter`
        let center = NSNotificationCenter.defaultCenter()
        #if os(iOS) || os(tvOS)
            center.removeObserver(self,
                name: AVAudioSessionInterruptionNotification, object: player)
            center.removeObserver(self,
                name: AVAudioSessionRouteChangeNotification, object: player)
            center.removeObserver(self,
                name: AVAudioSessionMediaServicesWereLostNotification, object: player)
            center.removeObserver(self,
                name: AVAudioSessionMediaServicesWereResetNotification, object: player)
        #endif
        center.removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: player)

        //Unobserving AVPlayer's property
        for keyPath in AVPlayer.ap_KVOProperties {
            player.removeObserver(self, forKeyPath: keyPath)
        }

        //Unobserving timing event
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

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
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?,
        change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
            if let keyPath = keyPath, player = object as? AVPlayer {
                switch keyPath {
                case "currentItem.duration":
                    if let currentItem = player.currentItem {
                        eventListener?.onEvent(PlayerEvent.LoadedDuration(currentItem.duration),
                            generetedBy: self)
                        eventListener?.onEvent(PlayerEvent.LoadedMetadata(currentItem.asset.commonMetadata),
                            generetedBy: self)
                    }

                case "currentItem.playbackBufferEmpty":
                    if let empty = player.currentItem?.playbackBufferEmpty where empty {
                        eventListener?.onEvent(PlayerEvent.StartedBuffering, generetedBy: self)
                    }

                case "currentItem.playbackLikelyToKeepUp":
                    if let keepUp = player.currentItem?.playbackLikelyToKeepUp where keepUp {
                        eventListener?.onEvent(PlayerEvent.ReadyToPlay, generetedBy: self)
                    }

                case "currentItem.status":
                    if let item = player.currentItem where item.status == .Failed {
                        eventListener?.onEvent(PlayerEvent.EndedPlaying(item.error),
                            generetedBy: self)
                    }

                case "currentItem.loadedTimeRanges":
                    if let range = player.currentItem?.loadedTimeRanges.last?.CMTimeRangeValue {
                        eventListener?.onEvent(PlayerEvent.LoadedMoreRange(range.start, range.end),
                            generetedBy: self)
                    }

                default:
                    break
                }
            }
    }

    #if os(iOS) || os(tvOS)
    /**
     Audio session got interrupted by the system (call, Siri, ...). If interruption begins,
     we should ensure the audio pauses and if it ends, we should restart playing if state was
     `.Playing` before.

     - parameter note: The notification information.
     */
    @objc private func audioSessionGotInterrupted(note: NSNotification) {
        if let userInfo = note.userInfo,
            typeInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            type = AVAudioSessionInterruptionType(rawValue: typeInt) {
                if type == .Began {
                    eventListener?.onEvent(PlayerEvent.InterruptionBegan, generetedBy: self)
                }
                else {
                    if let optionInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSessionInterruptionOptions(rawValue: optionInt)
                        if options.contains(.ShouldResume) {
                            eventListener?.onEvent(PlayerEvent.InterruptionEnded, generetedBy: self)
                        }
                    }
                }
        }
    }
    #endif

    /**
     Audio session route changed (ex: earbuds plugged in/out). This can change the player
     state, so we just adapt it.

     - parameter note: The notification information.
     */
    @objc private func audioSessionRouteChanged(note: NSNotification) {
        eventListener?.onEvent(PlayerEvent.RouteChanged, generetedBy: self)
    }

    /**
     Audio session got messed up (media services lost or reset). We gotta reactive the
     audio session and reset player.

     - parameter note: The notification information.
     */
    @objc private func audioSessionMessedUp(note: NSNotification) {
        eventListener?.onEvent(PlayerEvent.SessionMessedUp, generetedBy: self)
    }

    /**
     Playing item did end. We can play next or stop the player if queue is empty.

     - parameter note: The notification information.
     */
    @objc private func playerItemDidEnd(note: NSNotification) {
        eventListener?.onEvent(PlayerEvent.EndedPlaying(nil), generetedBy: self)
    }
}

func ==(lhs: PlayerEventProducer.PlayerEvent, rhs: PlayerEventProducer.PlayerEvent) -> Bool {
    return lhs.hash == rhs.hash
}
