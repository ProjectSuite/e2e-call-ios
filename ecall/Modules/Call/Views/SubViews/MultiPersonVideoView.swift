import SwiftUI
import WebRTC
import AVFoundation

struct MultiPersonVideoView: View {
    @ObservedObject private var publisherRtc = WebRTCManager.publisher
    @ObservedObject private var subscriberRtc = WebRTCManager.subscriber

    let participants: [Participant]
    let callStatus: CallStatus
    let callDuration: TimeInterval
    let isMuted: Bool

    // Focused participant index for fullscreen mode
    @State private var focusedIndex: Int?

    // Rearrange the participant list so that:
    // - The local device is always in the first 4 cells of the 2x2 grid
    // - When there are more than 4 people, the local device is always in the 4th position (last cell of the grid) on the current device
    private var displayParticipants: [Participant] {
        guard participants.count > 1 else { return participants }

        // Tìm index của local participant
        guard let localIndex = participants.firstIndex(where: { $0.isLocal }) else {
            return participants
        }

        // With a 2x2 grid, the 3rd index (0-based) is the 4th cell (bottom right corner)
        let desiredIndex = min(3, participants.count - 1)

        // If the locale is already in the correct position, keep it as is.
        if localIndex == desiredIndex {
            return participants
        }

        // Move the local character to the desired location, maintaining the relative order of the other participants.
        var reordered = participants
        let localParticipant = reordered.remove(at: localIndex)
        if desiredIndex <= reordered.count {
            reordered.insert(localParticipant, at: desiredIndex)
        } else {
            reordered.append(localParticipant)
        }
        return reordered
    }

    private var mainGridParticipants: [Participant] {
        Array(displayParticipants.prefix(4))
    }

    private var extraParticipants: [Participant] {
        Array(displayParticipants.dropFirst(4))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let idx = focusedIndex, idx < displayParticipants.count { // focus mode
                let participant = displayParticipants[idx]
                Group {
                    if let track = getVideoTrack(for: participant) {
                        VideoTrackRendererView(
                            videoTrack: track,
                            isMirrored: participant.isLocal && publisherRtc.currentCameraPosition == .front
                        )
                        .id(participant.userId)

                    } else {
                        AudioParticipantTileView(participant: participant)
                            .id(("\(participant.userId)") + "_placeholder")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedIndex = nil
                }

                // Thumbnails at bottom-left
                thumbnailsStrip
                    .padding(.leading, 6)
                    .padding(.bottom, 6)

            } else {
                VStack(spacing: 16) {
                    // Main 2x2 grid for up to 4 participants
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ],
                        spacing: 6
                    ) {
                        ForEach(0..<4, id: \.self) { index in
                            if index < mainGridParticipants.count {
                                let participant = mainGridParticipants[index]
                                VideoParticipantTileView(
                                    participant: participant,
                                    videoTrack: getVideoTrack(for: participant)
                                )
                                .aspectRatio(1, contentMode: .fill)
                                .onTapGesture {
                                    focusedIndex = index // index in displayParticipants
                                }
                            } else {
                                // Empty tile
                                EmptyView()
                            }
                        }
                    }
                    .padding(.top, 8)

                    // Additional participants section (horizontal scroll)
                    if !extraParticipants.isEmpty {
                        additionalParticipantsSection
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Additional Participants Section
    private var additionalParticipantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text(KeyLocalized.Other_Participants)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text("(\(extraParticipants.count))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(extraParticipants.enumerated()), id: \.element.userId) { pair in
                        let localIndex = 4 + pair.offset // index trong displayParticipants
                        let participant = pair.element
                        additionalParticipantAvatar(participant: participant)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                focusedIndex = localIndex
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func additionalParticipantAvatar(participant: Participant) -> some View {
        AudioParticipantTileView(participant: participant)
            .frame(width: 80)
    }

    // Thumbnails strip for fullscreen mode with centering behavior
    private var thumbnailsStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(displayParticipants.enumerated()), id: \.element.userId) { pair in
                        let index = pair.offset
                        let participant = pair.element

                        VideoParticipantTileView(
                            participant: participant,
                            videoTrack: getVideoTrack(for: participant)
                        )
                        .frame(width: 120, height: 150)
                        .clipped()
                        .background(.gray.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke((focusedIndex == index) ? Color.blue : Color.clear, lineWidth: 3)
                        )
                        .cornerRadius(12)
                        .id(participant.userId)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                focusedIndex = index
                                proxy.scrollTo(participant.userId, anchor: .center)
                            }
                        }
                    }
                }
            }
            .onChange(of: focusedIndex) { newIdx in
                if let i = newIdx, i < displayParticipants.count {
                    let id = displayParticipants[i].userId
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let i = focusedIndex, i < displayParticipants.count {
                    let id = displayParticipants[i].userId
                    DispatchQueue.main.async {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Helper Properties

    private func getVideoTrack(for participant: Participant) -> RTCVideoTrack? {
        if participant.isLocal {
            return publisherRtc.localVideoTrack
        } else {
            guard let feedId = participant.feedId else {
                debugLog("⚠️ No feedId for participant: \(participant.displayName)")
                return nil
            }

            guard let data = subscriberRtc.remoteVideoTracks[feedId] else {
                debugLog("⚠️ No video track found for feedId: \(feedId), participant: \(participant.displayName)")
                return nil
            }

            //            debugLog("✅ Found video track for feedId: \(feedId), participant: \(participant.displayName)")
            return data
        }
    }

    private func getAudioTrack(for participant: Participant) -> RTCAudioTrack? {
        if participant.isLocal {
            return publisherRtc.localAudioTrack
        } else {
            guard let feedId = participant.feedId, let data = subscriberRtc.remoteAudioTracks[feedId] else {return nil}
            return data
        }
    }
}
