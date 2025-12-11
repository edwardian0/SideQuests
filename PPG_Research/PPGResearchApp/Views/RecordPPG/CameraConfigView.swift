import SwiftUI


struct CameraConfigView: View {
    
    
    enum preserSelection: String, CaseIterable, Identifiable {
        case preset1 = "preset1"
        case preset2 = "preset2"
        case preset3 = "preset3"
        case preset4 = "preset4"
        case preset5 = "preset5"
        case preset6 = "preset6"
        case preset7 = "preset7"
        case preset8 = "preset8"
        case preset9 = "preset9"
        case preset10 = "preset10"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .preset1:
                return "Preset 1"
            case .preset2:
                return "Preset 2"
            case .preset3:
                return "Preset 3"
            case .preset4:
                return "Preset 4"
            case .preset5:
                return "Preset 5"
            case .preset6:
                return "Preset 6"
            case .preset7:
                return "Preset 7"
            case .preset8:
                return "Preset 8"
            case .preset9:
                return "Preset 9"
            case .preset10:
                return "Preset 10"
            }
        }
        
        var presetNumber: Int {
            switch self {
            case .preset1: return 1
            case .preset2: return 2
            case .preset3: return 3
            case .preset4: return 4
            case .preset5: return 5
            case .preset6: return 6
            case .preset7: return 7
            case .preset8: return 8
            case .preset9: return 9
            case .preset10: return 10
            }
        }
    }
    
    @State private var selection: preserSelection = .preset1
    @Binding var show: Bool
    
    // Add these parameters to receive the callback and viewModel
    let onPresetSelected: (Int) -> Void
    let viewModel: RecordPPGViewModel
    
    @State private var availablePresets: [CameraPreset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Camera Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select camera preset and ROI mode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                .padding(.bottom, 20)
                
                // Form with ROI Section
                Form {
                    Section {
                        // Picker for preset mode
                        Picker("Camera Preset", selection: $selection) {
                            ForEach(preserSelection.allCases) { mode in
                                Text(mode.displayName)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        // Selected option details
                        HStack {
                            Image(systemName: "circle.inset.filled")
                                .foregroundColor(.indigo)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selection.displayName)
                                    .font(.headline)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        
                    } header: {
                        Text("ROI Mode")
                    } footer: {
                        Text("Choose camera preset for camera capture.")
                    }
                    
                    // Camera Settings Preview Section
                    if let preset = availablePresets.first(where: { $0.id == selection.presetNumber }) {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                SettingRow(title: "ISO", value: "\(preset.ISO)")
                                SettingRow(title: "Exposure", value: String(format: "%.3f s", preset.ExposureSeconds))
                                SettingRow(title: "White Balance", value: "\(preset.WhiteBalance)K")
                                SettingRow(title: "Focus", value: String(format: "%.2f", preset.Focus))
                            }
                        } header: {
                            Text("Camera Settings Preview")
                        } footer: {
                            Text("These settings will be applied when you tap 'Apply Configuration'.")
                        }
                    }
                    
                    // Error message if any
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                // Apply Button
                VStack {
                    Button {
                        applyConfiguration()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(isLoading ? "Applying..." : "Apply Configuration")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isLoading ? .gray : .indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    .padding(.vertical)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.snappy) {
                            show = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                loadPresets()
            }
        }
    }
    
    private func loadPresets() {
        availablePresets = viewModel.loadAllPresets()
        if availablePresets.isEmpty {
            errorMessage = "Failed to load camera presets"
        }
    }
    
    private func applyConfiguration() {
        guard let preset = availablePresets.first(where: { $0.id == selection.presetNumber }) else {
            errorMessage = "Selected preset not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Apply the preset
        viewModel.applyPreset(preset)
        // Call the callback to update the parent view
        onPresetSelected(selection.presetNumber)
        
        // Simulate a brief delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            withAnimation(.snappy) {
                show = false
            }
        }
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    CameraConfigView(
        show: .constant(false),
        onPresetSelected: { _ in },
        viewModel: RecordPPGViewModel()
    )
}
