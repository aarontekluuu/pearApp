import SwiftUI

// MARK: - Pear Protocol Typography System
// SF Pro Display based typography scale

enum PearTypography {
    // MARK: - Display
    /// 28-32pt Bold, -0.5pt letter spacing - Hero text, main headings
    static let display = Font.system(size: 30, weight: .bold, design: .default)
    
    // MARK: - Headings
    /// 22-24pt Semibold - Section headings
    static let largeHeading = Font.system(size: 23, weight: .semibold)
    /// 18-20pt Semibold - Card titles, subsection headings
    static let heading = Font.system(size: 19, weight: .semibold)
    
    // MARK: - Body
    /// 16pt Regular - Primary content
    static let body = Font.system(size: 16, weight: .regular)
    /// 16pt Medium - Emphasized body text
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    
    // MARK: - Secondary
    /// 14pt Regular - Supporting text
    static let secondary = Font.system(size: 14, weight: .regular)
    /// 14pt Medium - Emphasized supporting text
    static let secondaryMedium = Font.system(size: 14, weight: .medium)
    
    // MARK: - Small
    /// 12pt Regular/Medium - Captions, labels
    static let caption = Font.system(size: 12, weight: .medium)
    static let captionRegular = Font.system(size: 12, weight: .regular)
    
    /// 11pt Regular - Footnotes, timestamps
    static let footnote = Font.system(size: 11, weight: .regular)
}

// MARK: - Typography View Modifier
struct PearFontModifier: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    func pearDisplay() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.display, color: .textPrimary))
            .tracking(-0.5) // -0.5pt letter spacing per design system
    }
    
    func pearLargeHeading() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.largeHeading, color: .textPrimary))
    }
    
    func pearHeading() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.heading, color: .textPrimary))
    }
    
    func pearBody() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.body, color: .textPrimary))
    }
    
    func pearSecondary() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.secondary, color: .textSecondary))
    }
    
    func pearCaption() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.caption, color: .textSecondary))
    }
    
    func pearFootnote() -> some View {
        self.modifier(PearFontModifier(font: PearTypography.footnote, color: .textSecondary))
    }
}
