//
//  MemoryAisleWidgetsBundle.swift
//  MemoryAisleWidgets
//
//  Created by Kevin Minn on 4/6/26.
//

import WidgetKit
import SwiftUI

@main
struct MemoryAisleWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MemoryAisleWidgets()
        MemoryAisleWidgetsControl()
        MemoryAisleWidgetsLiveActivity()
    }
}
