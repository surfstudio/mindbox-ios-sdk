//
//  DITest.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 28.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//


import XCTest
@testable import MindBox

class DITestCase: XCTestCase {

    override func setUp() {

        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOnInitCase() {

        let extractor = DIExtractor()

        let opExtractor = DIExtractorOptionals()

        XCTAssert(opExtractor.logger != nil)
        XCTAssert(opExtractor.fetchUtilities != nil)
        XCTAssert(opExtractor.persistenceStorage != nil)
        XCTAssert(opExtractor.networkFetcher != nil)
        XCTAssert(opExtractor.eventRepository != nil)
        XCTAssert(opExtractor.authorizationStatusProvider != nil)
        XCTAssert(opExtractor.dataBaseLoader != nil)
        XCTAssert(opExtractor.databaseRepository != nil)
        XCTAssert(opExtractor.gdManager != nil)

        extractor.persistenceStorage.apnsToken = UUID().uuidString

        XCTAssert(opExtractor.persistenceStorage.apnsToken == extractor.persistenceStorage.apnsToken)

    }

    class DIExtractor {
        @Injected var logger: ILogger
        @Injected var fetchUtilities: UtilitiesFetcher
        @Injected var persistenceStorage: PersistenceStorage
        @Injected var networkFetcher: NetworkFetcher
        @Injected var eventRepository: EventRepository
        @Injected var authorizationStatusProvider: UNAuthorizationStatusProviding
        @Injected var dataBaseLoader: DataBaseLoader
        @Injected var databaseRepository: MBDatabaseRepository
        @Injected var gdManager: GuaranteedDeliveryManager

        init() {
        }
    }

    class DIExtractorOptionals {
        @InjectedOptional var logger: ILogger!
        @InjectedOptional var fetchUtilities: UtilitiesFetcher!
        @InjectedOptional var persistenceStorage: PersistenceStorage!
        @InjectedOptional var networkFetcher: NetworkFetcher!
        @InjectedOptional var eventRepository: EventRepository!
        @InjectedOptional var authorizationStatusProvider: UNAuthorizationStatusProviding!
        @InjectedOptional var dataBaseLoader: DataBaseLoader!
        @InjectedOptional var databaseRepository: MBDatabaseRepository!
        @InjectedOptional var gdManager: GuaranteedDeliveryManager!

        init() {
        }
    }
}
