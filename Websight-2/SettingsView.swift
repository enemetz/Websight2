//
//  SettingsView.swift
//  websight
//
//  Created by Evan Nemetz on 3/4/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("openUrlsInApp") private var openUrlsInApp: Bool = false
    @AppStorage("openMapsInApp") private var openMapsInApp: Bool = false
    @AppStorage("openMailInApp") private var openMailInApp: Bool = false
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Action Settings")) {
                    Toggle("Open URLs in App", isOn: $openUrlsInApp)
                    Toggle("Open Maps in App", isOn: $openMapsInApp)
                    Toggle("Open Mail in App", isOn: $openMailInApp)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button("", systemImage: "xmark", action:  {
                        dismiss()
                    })
                })
            }
        }
    }
}

#Preview {
    SettingsView()
}
