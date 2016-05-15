//
//  RetryEventProducer_Tests.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 15/04/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import XCTest
@testable import AudioPlayer

class RetryEventProducer_Tests: XCTestCase {
    var listener: FakeEventListener!
    var producer: RetryEventProducer!

    override func setUp() {
        super.setUp()
        listener = FakeEventListener()
        producer = RetryEventProducer()
        producer.eventListener = listener
    }

    override func tearDown() {
        listener = nil
        producer.stopProducingEvents()
        producer = nil
        super.tearDown()
    }

    func testEventListenerGetsCalledUntilMaximumRetryCountHit() {
        var receivedRetry = 1
        let maximumRetryCount = 3

        let expectation = expectationWithDescription("Waiting for `onEvent` to get called")
        listener.eventClosure = { event, producer in
            if let event = event as? RetryEventProducer.RetryEvent {
                if event == .RetryAvailable {
                    receivedRetry += 1
                } else if event == .RetryFailed && receivedRetry == maximumRetryCount {
                    expectation.fulfill()
                } else {
                    XCTFail()
                    expectation.fulfill()
                }
            }
        }

        producer.retryTimeout = 1
        producer.maximumRetryCount = maximumRetryCount
        producer.startProducingEvents()

        waitForExpectationsWithTimeout(5) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }
}
