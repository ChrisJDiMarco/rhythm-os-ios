import SwiftUI

struct NotificationBatchView: View {
    @EnvironmentObject private var store: RhythmStore

    private let passThrough = [
        NotificationItem(sender: "Sam", preview: "\"think i found the partykit edge case...\"", status: "Now", isPassThrough: true),
        NotificationItem(sender: "Jordan", preview: "\"call after lunch? quick project Q\"", status: "Now", isPassThrough: true)
    ]

    private let held = [
        NotificationItem(sender: "Instagram - 7 alerts", preview: "3 likes, 1 follow, 3 reels suggested", status: "5:00 PM", isPassThrough: false),
        NotificationItem(sender: "Gmail - 11 alerts", preview: "9 newsletters, 2 work threads", status: "5:00 PM", isPassThrough: false),
        NotificationItem(sender: "LinkedIn - 4 alerts", preview: "\"Someone you may know...\"", status: "5:00 PM", isPassThrough: false)
    ]

    var body: some View {
        let snapshot = store.snapshot

        ScreenChrome(screen: .notifications, variant: .notifications, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Notifications")
                    .font(.system(size: 31, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink)

                Text("Real people pass. Algorithms wait.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
            }

            GlassCard(radius: 20, strokeOpacity: 0.18) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next batch delivery")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(RhythmColor.bio)

                        Text(snapshot.nextBatchDate.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 25, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(RhythmColor.ink)

                        Text("\(snapshot.heldNotificationCount) held - \(snapshot.passThroughNotificationCount) pass through")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(RhythmColor.ink2)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(RhythmColor.bio.opacity(0.22), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(RhythmColor.bio, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(RhythmColor.bio)
                    }
                    .frame(width: 68, height: 68)
                }
            }

            NotificationControlCard()

            NotificationSection(title: "Pass-through - real people", count: "2 now", items: passThrough)
            NotificationSection(title: "Held - algorithms + work", count: "\(snapshot.heldNotificationCount) batched", items: held)
        }
    }
}

private struct NotificationControlCard: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        SolidCard(radius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: store.notificationAuthorizationGranted ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.notificationAuthorizationGranted ? RhythmColor.bio : RhythmColor.warn)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.notificationAuthorizationGranted ? "Local nudges enabled" : "Enable Rhythm nudges")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(RhythmColor.ink)

                        Text("iOS does not allow third-party global notification interception. Rhythm uses local nudges plus App Gate shielding.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .lineSpacing(2)
                            .foregroundStyle(RhythmColor.ink3)
                    }

                    Spacer()
                }

                Button {
                    Task { await store.scheduleNextNotificationBatch() }
                } label: {
                    Label(store.notificationAuthorizationGranted ? "Schedule next batch" : "Enable and schedule", systemImage: "clock.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .foregroundStyle(RhythmColor.ink2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct NotificationSection: View {
    let title: String
    let count: String
    let items: [NotificationItem]

    var body: some View {
        VStack(spacing: 8) {
            SectionKicker(title: title, trailing: count)

            VStack(spacing: 6) {
                ForEach(items) { item in
                    NotificationRow(item: item)
                }
            }
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    item.isPassThrough
                    ? AnyShapeStyle(LinearGradient(colors: [RhythmColor.bio, RhythmColor.pulse], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(RhythmColor.ink4.opacity(0.72))
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: item.isPassThrough ? "person.fill" : "app.badge.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.isPassThrough ? Color(hex: 0x061310) : RhythmColor.ink2.opacity(0.72))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.sender)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(RhythmColor.ink.opacity(item.isPassThrough ? 1 : 0.68))
                    .lineLimit(1)

                Text(item.preview)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(item.status)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(item.isPassThrough ? RhythmColor.bio : RhythmColor.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            item.isPassThrough
            ? RhythmColor.bio.opacity(0.05)
            : RhythmColor.bgCard.opacity(0.54),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(item.isPassThrough ? RhythmColor.bio.opacity(0.22) : .white.opacity(0.06), lineWidth: 1)
        )
    }
}
