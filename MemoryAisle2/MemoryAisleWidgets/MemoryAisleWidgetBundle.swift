import SwiftUI
import WidgetKit

@main
struct MemoryAisleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProteinWidget()
        HydrationWidget()
        NextMealWidget()
    }
}
