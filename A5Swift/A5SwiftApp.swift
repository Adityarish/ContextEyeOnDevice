import SwiftUI

@main
struct A5SwiftApp: App {
    private let environment = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            ModelListView(environment: environment)
        }
    }
}
