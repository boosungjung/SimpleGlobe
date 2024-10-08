//
//  GlobeAttachmentView.swift
//  Globes
//
//  Created by Bernhard Jenny on 28/5/2024.
//

import SwiftUI

struct GlobeAttachmentView: View {
    @Environment(ViewModel.self) var model
    @Environment(\.openWindow) private var openWindow
    
    let globe: Globe
    
    @MainActor
    private var globeEntity: GlobeEntity? {
        model.globeEntity
    }
    
    // MARK: - Timer
    
    /// The attachment view is shown for 10 seconds, unless the user interacts with any control
    private let durationVisible: TimeInterval = 10
    
    /// Timer for hiding the view after `durationVisible` seconds
    @State private var timer: Timer? = nil
    
    /// Progress of timer for hiding the view
    @State private var timerProgress = Double.zero
    
    /// Update interval for smooth animation of the progress bar
    private let timerInterval: TimeInterval = 1 / 20
    
    @MainActor
    private func resetAttachmentTimer() {
        timer?.invalidate()
        timerProgress = 0
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            Task { @MainActor in
                if timerProgress + timerInterval > durationVisible {
                    timer?.invalidate()
                    hideAttachmentView()
                }
                timerProgress += timerInterval
            }
        }
        timer?.tolerance = timerInterval / 2
    }
    
    @MainActor
    private func stopAttachmentTimer() {
        timer?.invalidate()
        timerProgress = 0
    }
    
    @MainActor
    private func hideAttachmentView() {
        model.configuration.showAttachment = false
    }
    
    // MARK: - View State
    
    private enum ViewState {
        case controls, info, custom
    }
    
    @State private var show = ViewState.controls
    
    private let cornerRadius: Double = 8
    
    // MARK: -
    
    var body: some View {
        VStack {
            ZStack {
                titlePlate
                closeButton
                // place close button in top-left corner
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: -32)
            }
            // force constant width of containing ZStack, such that the close button does not move when the info view becomes visible.
            .frame(width: scaledInfoTextWidth)
            
            topButtons
            
            switch show {
            case .controls:
                Circle() // empty space at the center
                    .frame(height: 300)
                    .hidden()
                bottomButtons
                    .padding(.bottom, 40) // padding to give the bottom section the height of the top section, such that poles appear centered between the top and bottom sections.
            case .info:
                if globe.description != nil || globe.infoURL != nil {
                    infoView
                }
            case .custom:
                EmptyView()
                // EditGlobeView(globe: customGlobeBinding)
            }
        }
        .controlSize(.small)
        .animation(.default, value: globe)
        .animation(.default, value: show)
        .fixedSize()
        .onChange(of: model.configuration.showAttachment, initial: true) {_, showAttachment in
            if showAttachment == true, show == .controls {
                resetAttachmentTimer()
            }
        }
    }
    
    @MainActor
    @ViewBuilder var titlePlate: some View {
        VStack(spacing: 2) {
            if let date = globe.date, !date.isEmpty {
                Text(date)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Text(globe.name)
                .font(.headline)
            
            if !globe.author.isEmpty {
                Text(globe.author)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }
    
    @MainActor
    @ViewBuilder var closeButton: some View {
        Button(action: hideAttachmentView, label: {
            Image(systemName: "xmark")
        })
        .buttonBorderShape(.circle)
        .overlay {
            ProgressView(
                value: min(timerProgress, durationVisible),
                total: durationVisible
            )
            .progressViewStyle(GaugeProgressStyle())
        }
        .help("Close")
        .padding(8)
        .glassBackgroundEffect()
    }
    
    @MainActor
    @ViewBuilder var topButtons: some View {
        HStack(spacing: 16) {
            switch show {
            case .controls:
                if globe.description != nil || globe.infoURL != nil {
                    Button(action: {
                        show = .info
                        stopAttachmentTimer()
                    }) {
                        ButtonImage(name: "info.circle")
                    }
                    .buttonStyle(.plain)
                }
            case .info, .custom:
                Button(action: {
                    show = .controls
                    resetAttachmentTimer()
                }) {
                    ButtonImage(name: "chevron.left")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .glassBackgroundEffect()
    }
    
    @MainActor
    @ViewBuilder var bottomButtons: some View {
        VStack {
            HStack(spacing: 16) {
                rotationButton
                orientButton
                northPoleButton
                southPoleButton
                resetSizeButton
            }
            .padding(8)
            .glassBackgroundEffect()
            
            Button(action: {
                model.hideGlobe()
            }) {
                Label("Hide Globe", image: "globe.slash")
            }
            .padding(8)
            .glassBackgroundEffect()
        }
    }
    
    @ScaledMetric private var scaledInfoTextWidth = 370.0
    
    @MainActor
    @ViewBuilder var infoView: some View {
        VStack {
            if let description = globe.description {
                ScrollView(.vertical, showsIndicators: true) {
                    HStack {
                        Text(description)
                            .multilineTextAlignment(.leading)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
                .scrollIndicators(.visible, axes: .vertical)
                .frame(width: scaledInfoTextWidth)
                .frame(maxHeight: 400)
                .padding()
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            }
            
            if globe.infoURL != nil {
                Button("Open Webpage") {
                    openWindow(id: "info", value: globe.id)
                }
                .padding(8)
                .glassBackgroundEffect()
            }
        }
    }
    
    // MARK: - Buttons
    
    @MainActor
    @ViewBuilder private var rotationButton: some View {
        Button(action: toggleRotation) {
            if model.configuration.isRotationPaused {
                ButtonImage(name: "rotate.3d.slash", isSystemImage: false)
            } else {
                ButtonImage(name: "rotate.3d")
            }
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
    }
    
    @MainActor
    @ViewBuilder private var rotationToggle: some View {
        let isRotationPausedBinding: Binding<Bool> = Binding(
            get: { model.configuration.isRotationPaused },
            set: {
                model.configuration.isRotationPaused = $0
                resetAttachmentTimer()
            }
        )
        
        Toggle(isOn: isRotationPausedBinding) {
            if isRotationPausedBinding.wrappedValue {
                Label("Rotate", image: "rotate.3d.slash")
            } else {
                Label("Rotate", systemImage: "rotate.3d")
            }
        }
        .toggleStyle(.switch)
        .help("Globe Rotation")
    }
    
    @MainActor
    private func toggleRotation() {
        model.configuration.isRotationPaused.toggle()
        resetAttachmentTimer()
    }
    
    @MainActor
    @ViewBuilder private var resetSizeButton: some View {
        Button(action: resetGlobeSize) {
            ButtonImage(name: "circle.circle")
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .disabled(globeEntity?.isAtOriginalSize(radius: globe.radius) == true)
        .help("Reset Size")
    }
    
    @MainActor
    private func resetGlobeSize() {
        globeEntity?.scaleAndAdjustDistanceToCamera(
            newScale: 1,
            radius: model.globe.radius,
            duration: GlobeEntity.transformAnimationDuration
        )
        
        resetAttachmentTimer()
    }
    
    @MainActor
    @ViewBuilder private var orientButton: some View {
        Button(action: {
            globeEntity?.orientToNorth(radius: model.globe.radius)
            resetAttachmentTimer()
        }) {
            ButtonImage(name: "location.north.line")
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.plain)
        .disabled(globeEntity?.isNorthOriented == true)
        .help("Orient to North")
    }
    
    @MainActor
    @ViewBuilder private var northPoleButton: some View {
        Button(action: {
            globeEntity?.rotate(to: [0, 1, 0], radius: model.globe.radius)
            resetAttachmentTimer()
        }) {
            ButtonImage(name: "n.circle")
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.plain)
        .help("Show Show North Pole")
    }
    
    @MainActor
    @ViewBuilder private var southPoleButton: some View {
        Button(action: {
            globeEntity?.rotate(to: [0, -1, 0], radius: model.globe.radius)
            resetAttachmentTimer()
        }) {
            ButtonImage(name: "s.circle")
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.plain)
        .help("Show South Pole")
    }
}

#if DEBUG
#Preview {
    GlobeAttachmentView(globe: Globe.preview)
        .environment(ViewModel.preview)
}
#endif
