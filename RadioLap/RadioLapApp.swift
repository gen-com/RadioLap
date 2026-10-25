//
//  RadioLapApp.swift
//  RadioLap

import SwiftUI

@main
struct RadioLapApp: App {
    private let component = AppComponent()

    var body: some Scene {
        WindowGroup {
            RaceListView(dependency: component) { race in
                RaceDetailView(race: race, dependency: component)
            }
        }
    }
}
