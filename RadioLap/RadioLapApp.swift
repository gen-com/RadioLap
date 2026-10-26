//
//  RadioLapApp.swift
//  RadioLap

import SwiftUI

@main
struct RadioLapApp: App {
    private let component = AppComponent()

    var body: some Scene {
        WindowGroup {
            RaceListView(component: component.raceListComponent)
        }
    }
}
