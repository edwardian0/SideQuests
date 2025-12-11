import SwiftUI
import Charts

struct RecordPPGView: View {
    
    @State private var model = RecordPPGViewModel()
    
    @State private var showSaveAlert = false
    @State private var showShareSheet = false

    // Added camera configuration view bool and preset selection by preset ID
    @State private var selectedPresetNumber = 1
    @State private var showCameraConfig = false
    
    var body: some View {
            ZStack(alignment: .topLeading) {
                VStack {
                    ZStack(alignment: .center) {
                        GeometryReader { geometry in
                            ViewfinderView(image:  $model.viewfinderImage )
                                .background(.red)
                                .frame(height: geometry.size.height)
                                .clipShape(.circle)
                        }
                        .frame(height: 200)
                    }

                    if model.isRecording{
                        Text(model.recordingTime)
                            .padding(8)
                            .foregroundStyle(.white)
                            .background(Capsule().foregroundStyle(.red))
                            .animation(.linear, value: model.isRecording)
                    }
                    
                    chartView()
                        .padding(.vertical, 20)
                    
                    buttonsView()
                        .padding(.bottom, 20)
                }
            }
            .onAppear {
                startCamera()
            }
            .alert("Save", isPresented: $showSaveAlert) {
                Button("Cancel"){
                    showSaveAlert = false
                    startCamera()
                }
                
                Button("Save"){
                    showSaveAlert = false
                    showShareSheet.toggle()
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                Archiver.clearTempFolder()
                startCamera()
            }) {
                if let item = model.prepareExportZip() {
                    ShareSheet(activityItems: [item])
                }
            }

        
        }
    
    private func startCamera(){
        Task {
            await model.camera.start()
        }
    }
    
    private func chartView() -> some View {
        let minMaxRange = model.livePreviewData.recentMaxValue - model.livePreviewData.recentMinValue
        let plotPadding = abs(minMaxRange / 2)
        
        let chart = Chart() {
            
            ForEach(model.livePreviewData.values, id: \.id) { item in
                LineMark(
                    x: .value("time", item.time),
                    y: .value("value", item.value),
                    series: .value("raw data", "A")
                )
                .foregroundStyle(.accent)
                .interpolationMethod(.cardinal)
            }
        }
            .chartYScale(
                domain: (model.livePreviewData.recentMinValue - plotPadding)...(model.livePreviewData.recentMaxValue + plotPadding)
                
            )
            .chartXScale(
                domain: Date()
                    .addingTimeInterval(-model.livePreviewData.previewTimespanInSeconds)...Date()
            )
            .clipped()
        
        return chart
    }
    
    private func buttonsView() -> some View {
       return HStack(alignment: .center) {
           VStack {

               cameraConfigsButton
                      .sheet(isPresented: $showCameraConfig) {
                          CameraConfigView(
                              show: $showCameraConfig,
                              onPresetSelected: { presetNumber in
                                  selectedPresetNumber = presetNumber
                                  if let preset = model.availablePresets.first(where: {$0.id == presetNumber}) {
                                      model.applyPreset(preset)
                                  }
                                  
                              },
                              viewModel: model
                          )
                          .presentationDetents([.fraction(0.75)])
                          .presentationCornerRadius(32)
                      }
               
               torchLevelButton
                   .frame(width: 100)
               
               switchCameraButton
                   .frame(width: 100)
           }
           
            startStopButton

            actionButton
               .frame(width: 100)
           
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        
    }

    var cameraConfigsButton: some View {
        Button {
            showCameraConfig = true
        } label: {
            VStack(spacing: 5) {
                VStack(spacing: 5) {
                    Image(systemName: "gear")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)
                        .foregroundStyle(.primary)
                    Text("Preset: \(selectedPresetNumber)")
                        .font(.system(size: 12))
                }
            }
        }
        .disabled(model.isRecording)
    }
    
    var actionButton: some View{
        Menu{
            Button("action 1"){
                model.selectCameraResolution(resolution: .hd720)
            }
            
            Button("action 2"){
                model.selectCameraResolution(resolution: .vga)
            }
        }
        label: {
            Image(systemName: "star")
        }
    }
    
    var torchLevelButton: some View {
        Button{
            
        } label: {
            VStack(spacing: 5){
                VStack(spacing: 5){
                    Image(.flashIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)
                        .foregroundStyle(.primary)
                    Text("flash_button")
                        .font(.system(size: 12))
                    
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation {
                model.torchOn.toggle()
            }
        })
        .disabled(model.isRecording)
    }
    
    var switchCameraButton: some View {
        Button {
            model.livePreviewData.clear()
            model.camera.switchCaptureDevice()
        } label: {
            VStack(spacing: 5){
                Image(.lenseSwitchIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .foregroundStyle(.primary)
                Text("Change lens")
                    .font(.system(size: 12))
                
            }
        }
        .disabled(model.isRecording)
    }
    
    var startStopButton: some View {
        Button {
            withAnimation {
                if model.isRecording {
                    let recording = model.stopRecording()
                    model.camera.setTorch(torchLevel: 0.0)
                    model.camera.stop()
                    showSaveAlert.toggle()
                }else{
                    model.startRecording()
                }
            }
        } label: {
            if model.isRecording {
                stopRecordingButtonLabel
            }else{
                startRecordingButtonLabel
            }
        }
    }
    
    var startRecordingButtonLabel: some View {
        ZStack {
            Circle()
                .strokeBorder(.black, lineWidth: 3)
                .frame(width: 90, height: 90)
                .clipShape(.circle)
            Text(
                "start_recording"
            )
            .foregroundStyle(.primary)
        }
    }
    
    var stopRecordingButtonLabel: some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 90, height: 90)
                .background(.red)
                .clipShape(.circle)
            Text(
                "stop_recording"
            )
            .foregroundStyle(.white)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    
}


#Preview {
    RecordPPGView()
}
