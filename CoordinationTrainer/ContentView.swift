import SwiftUI
import AVFoundation


// This is the UIView that contains the AVPlayerLayer for rendering the video
class PlayerUIView: UIView {
    private let player: AVPlayer
    private let playerLayer = AVPlayerLayer()
    private let videoPos: Binding<Double>
    private let videoDuration: Binding<Double>
    private let seeking: Binding<Bool>
    private var durationObservation: NSKeyValueObservation?
    private var timeObservation: Any?
    
    init(player: AVPlayer, videoPos: Binding<Double>, videoDuration: Binding<Double>, seeking: Binding<Bool>) {
        self.player = player
        self.videoDuration = videoDuration
        self.videoPos = videoPos
        self.seeking = seeking
        
        super.init(frame: .zero)
        
        backgroundColor = .lightGray
        playerLayer.player = player
        layer.addSublayer(playerLayer)
        
        // Observe the duration of the player's item so we can display it
        // and use it for updating the seek bar's position
        durationObservation = player.currentItem?.observe(\.duration, changeHandler: { [weak self] item, change in
            guard let self = self else { return }
            self.videoDuration.wrappedValue = item.duration.seconds
        })
        
        // Observe the player's time periodically so we can update the seek bar's
        // position as we progress through playback
        timeObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: nil) { [weak self] time in
            guard let self = self else { return }
            // If we're not seeking currently (don't want to override the slider
            // position if the user is interacting)
            guard !self.seeking.wrappedValue else {
                return
            }
            
            // update videoPos with the new video time (as a percentage)
            self.videoPos.wrappedValue = time.seconds / self.videoDuration.wrappedValue
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        playerLayer.frame = bounds
    }
    
    func cleanUp() {
        // Remove observers we setup in init
        durationObservation?.invalidate()
        durationObservation = nil
        
        if let observation = timeObservation {
            player.removeTimeObserver(observation)
            timeObservation = nil
        }
    }
    
}

// This is the SwiftUI view which wraps the UIKit-based PlayerUIView above
struct PlayerView: UIViewRepresentable {
    @Binding private(set) var videoPos: Double
    @Binding private(set) var videoDuration: Double
    @Binding private(set) var seeking: Bool
    
    let player: AVPlayer
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
        // This function gets called if the bindings change, which could be useful if
        // you need to respond to external changes, but we don't in this example
    }
    
    func makeUIView(context: UIViewRepresentableContext<PlayerView>) -> UIView {
        let uiView = PlayerUIView(player: player,
                                  videoPos: $videoPos,
                                  videoDuration: $videoDuration,
                                  seeking: $seeking)
        return uiView
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        guard let playerUIView = uiView as? PlayerUIView else {
            return
        }
        
        playerUIView.cleanUp()
    }
}

// This is the SwiftUI view that contains the controls for the player
struct PlayButton : View {
    @State private var isPressed = false
    let player: AVPlayer
    
    var body: some View {
        let dragGesture = DragGesture(minimumDistance: 0.0).onChanged { _ in
            self.isPressed = true
            print("touch")
            self.player.play()
        }.onEnded {  _ in
            self.isPressed = false
            print("release")
            self.player.pause()
        }
        return Circle()
            .fill(isPressed ? Color.pink : Color.purple)
            .overlay(isPressed ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .frame(width: 100, height: 100, alignment: .center)
            .animation(nil)
            .shadow(radius: isPressed ? 8 : 0)
            .animation(.linear(duration: 0.2))
            .gesture(dragGesture)
    }
}

// This is the SwiftUI view which contains the player and its controls
struct PlayerContainerView : View {
    // The progress through the video, as a percentage (from 0 to 1)
    @State private var videoPos: Double = 0
    // The duration of the video in seconds
    @State private var videoDuration: Double = 0
    // Whether we're currently interacting with the seek bar or doing a seek
    @State private var seeking = false
    
    private let player: AVPlayer
    
    init(url: URL) {
        player = AVPlayer(url: url)
    }
    
    var body: some View {
        VStack {
            PlayerView(videoPos: $videoPos, videoDuration: $videoDuration, seeking: $seeking, player: player).frame(height:300)
            PlayButton(player: player)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

// This is the main SwiftUI view for this app, containing a single PlayerContainerView
struct ContentView: View {
    var body: some View {
        PlayerContainerView(url: URL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
