import SwiftUI
import WidgetKit

// @main is added when this moves to the widget extension target
struct MemoryAisleWidgets: WidgetBundle {
    var body: some Widget {
        ProteinWidget()
        HydrationWidget()
        TodaysMealWidget()
    }
}
