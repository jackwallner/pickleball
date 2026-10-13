import SwiftUI

/// Shown once on the first launch after an update. Two audiences read the same
/// list: a member is being told what they already own, a free player is being
/// shown what the membership would hand them.
///
/// It stays a sheet with one obvious dismiss and at most one soft upgrade
/// button. An update note that ambushes a returning player with a full paywall
/// is how you teach them not to update.
struct WhatsNewSheet: View {
    let release: WhatsNewRelease
    /// Raised instead of presenting the paywall from here. A sheet cannot
    /// present another sheet while it is itself dismissing, so the host closes
    /// this one and opens the paywall on the next runloop.
    let onUpgrade: () -> Void

    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    private var lockedItems: [WhatsNewItem] {
        subscriptions.isPro ? [] : release.items.filter(\.isPlus)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ForEach(release.items) { item in
                        row(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { close() }
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.court)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's New")
                .font(.caption.weight(.heavy))
                .kerning(1.4)
                .foregroundStyle(Theme.inkSecondary)
            Text(release.headline)
                .font(Theme.display(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Version \(release.version)")
                .font(.footnote)
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.top, 4)
    }

    private func row(_ item: WhatsNewItem) -> some View {
        let locked = item.isPlus && !subscriptions.isPro
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(locked ? Theme.gold : Theme.court)
                .frame(width: 42, height: 42)
                .background(
                    (locked ? Theme.gold : Theme.court).opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    if locked {
                        PlusBadge()
                    }
                }
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Members get a single "Start practising" button. Free players get the
    /// same button plus one line about the membership, never a plan picker.
    private var footer: some View {
        VStack(spacing: 10) {
            if !lockedItems.isEmpty {
                Button {
                    WhatsNew.markSeen()
                    onUpgrade()
                } label: {
                    Text("Unlock with \(Membership.name)").primaryCTA(color: Theme.gold)
                }
            }
            Button {
                close()
            } label: {
                Text(lockedItems.isEmpty ? "Start practising" : "Keep practising free")
                    .font(.headline)
                    .foregroundStyle(lockedItems.isEmpty ? .white : Theme.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: lockedItems.isEmpty ? 56 : 44)
                    .background(
                        lockedItems.isEmpty ? Theme.court : .clear,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.background)
    }

    private func close() {
        WhatsNew.markSeen()
        dismiss()
    }
}
