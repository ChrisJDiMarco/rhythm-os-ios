import SwiftUI

struct WeeklyReportView: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        let snapshot = store.snapshot

        ScreenChrome(screen: .weekly, variant: .weekly, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Rhythmicity Report")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Week ending \(Date.now.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
            }

            ScoreCard(score: snapshot.scores.rhythmicity)

            WeekChart(samples: snapshot.week)
                .frame(height: 104)
                .padding(.top, 4)

            InsightCard(
                title: "What's working",
                tint: RhythmColor.bio,
                items: snapshot.workingInsights.map(\.body)
            )

            InsightCard(
                title: "Pull-points",
                tint: RhythmColor.warn,
                items: snapshot.pullInsights.map(\.body)
            )
        }
    }
}

private struct ScoreCard: View {
    let score: Int

    var body: some View {
        GlassCard(radius: 24, strokeOpacity: 0.18) {
            VStack(spacing: 7) {
                Text("Rhythmicity Score")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(RhythmColor.bio)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 64, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RhythmColor.ink)
                        .contentTransition(.numericText())

                    Text("/100")
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundStyle(RhythmColor.ink3)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                    Text("12 vs last week")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(RhythmColor.bio)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct WeekChart: View {
    let samples: [DailyRhythmSample]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, item in
                let value = RhythmEngine.scoreForWeekChart(item, week: samples)
                let isToday = Calendar.current.isDateInToday(item.date)

                VStack(spacing: 8) {
                    Spacer(minLength: 0)

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isToday ? [.white, RhythmColor.bio] : [RhythmColor.bio, RhythmColor.bioDim],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(12, 76 * value))
                        .shadow(color: isToday ? RhythmColor.bio.opacity(0.55) : .clear, radius: 10)
                        .opacity(isToday ? 1 : 0.82)

                    Text(item.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(RhythmColor.ink3)
                }
            }
        }
        .padding(.horizontal, 6)
    }
}

private struct InsightCard: View {
    let title: String
    let tint: Color
    let items: [String]

    var body: some View {
        SolidCard(radius: 18) {
            VStack(alignment: .leading, spacing: 11) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(RhythmColor.ink3)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 9) {
                            Circle()
                                .fill(tint)
                                .frame(width: 6, height: 6)
                                .shadow(color: tint.opacity(0.45), radius: 6)
                                .padding(.top, 5)

                            Text(item)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .lineSpacing(3)
                                .foregroundStyle(RhythmColor.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
