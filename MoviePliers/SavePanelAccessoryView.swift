import SwiftUI

struct Option: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

let saveAsSelfContainedOptions = [
    Option(name: "Save normally (allowing dependencies)"),
    Option(name: "Make movie self-contained")
]

struct SavePanelAccessoryView: View {
    @Binding var saveAsSelfContained: Bool
    @State var selectedOption: Option = saveAsSelfContainedOptions[0]

    var body: some View {
        Picker("Select an option", selection: $selectedOption) {
            ForEach(saveAsSelfContainedOptions, id: \.id) { option in
                Text(option.name).tag(option) // Tag each option
            }
        }
        .pickerStyle(.radioGroup) // Apply the macOS radioGroup style
        .padding()
        .frame(width: 400) // Set a reasonable width
        .onChange(of: selectedOption) { oldState, newState in
            saveAsSelfContained = newState.name == "Make movie self-contained"
        }
    }
}
