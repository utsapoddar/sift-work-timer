//
//  SiftWidgetBundle.swift
//  SiftWidget
//
//  Created by Utsa Poddar on 2026-03-22.
//

import WidgetKit
import SwiftUI

@main
struct SiftWidgetBundle: WidgetBundle {
    var body: some Widget {
        SiftWidget()
        if #available(iOSApplicationExtension 18.0, *) {
            SiftWidgetControl()
        }
        if #available(iOSApplicationExtension 16.2, *) {
            SiftWidgetLiveActivity()
        }
    }
}
