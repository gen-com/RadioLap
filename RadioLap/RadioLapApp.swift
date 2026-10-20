//
//  RadioLapApp.swift
//  RadioLap
//
//  Created by 구병조 on 10/14/26.
//

import SwiftUI

@main
struct RadioLapApp: App {
    private let component = AppComponent()

    var body: some Scene {
        WindowGroup {
            RaceListView(dependency: component)
        }
    }
}
