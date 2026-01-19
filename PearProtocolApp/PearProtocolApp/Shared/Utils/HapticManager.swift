import UIKit

// MARK: - Haptic Manager
/// Centralized haptic feedback manager for consistent tactile feedback throughout the app
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {
        // Pre-warm generators for faster response
        prepareGenerators()
    }
    
    // MARK: - Generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - Impact Feedback
    
    /// Light tap - for subtle interactions like hovering or light taps
    func lightTap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Medium tap - primary button taps, card selections
    func tap() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Heavy tap - confirmations, important actions
    func heavyTap() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }
    
    /// Soft tap - gentle feedback for toggles, sliders
    func softTap() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }
    
    /// Rigid tap - sharp feedback for errors, boundaries
    func rigidTap() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed - picker changes, segment controls, tabs
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    // MARK: - Notification Feedback
    
    /// Success - trade executed, action completed
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Warning - validation issues, caution states
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// Error - failures, destructive confirmations
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
    
    // MARK: - Contextual Haptics
    
    /// Button press - standard CTA button feedback
    func buttonPress() {
        tap()
    }
    
    /// Card tap - selecting a card or list item
    func cardTap() {
        lightTap()
    }
    
    /// Navigation - tab changes, page transitions
    func navigate() {
        selection()
    }
    
    /// Toggle - switch or checkbox interactions
    func toggle() {
        softTap()
    }
    
    /// Slider - continuous feedback for sliders
    func sliderTick() {
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()
    }
    
    /// Swipe action - swipe to confirm, swipe to delete
    func swipeProgress(intensity: CGFloat) {
        mediumImpact.impactOccurred(intensity: min(1.0, intensity))
    }
    
    /// Swipe complete - swipe action completed
    func swipeComplete() {
        success()
    }
    
    /// Pull to refresh trigger
    func pullToRefresh() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }
    
    /// Long press recognized
    func longPress() {
        heavyTap()
    }
    
    /// Copy to clipboard
    func copy() {
        success()
    }
    
    /// Delete/remove action
    func delete() {
        rigidTap()
    }
    
    /// Trade execution started
    func tradeStarted() {
        mediumImpact.impactOccurred(intensity: 0.8)
        mediumImpact.prepare()
    }
    
    /// Trade execution success
    func tradeSuccess() {
        // Double tap pattern for trade success
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.notificationGenerator.notificationOccurred(.success)
        }
    }
    
    /// Trade execution failed
    func tradeFailed() {
        error()
    }
    
    /// Wallet connected
    func walletConnected() {
        success()
    }
    
    /// Position closed
    func positionClosed() {
        success()
    }
}

// MARK: - Convenience Extensions
extension HapticManager {
    /// Trigger haptic based on PnL value
    func pnlFeedback(for value: Double) {
        if value > 0 {
            softTap()
        } else if value < 0 {
            rigidImpact.impactOccurred(intensity: 0.3)
        }
    }
}
