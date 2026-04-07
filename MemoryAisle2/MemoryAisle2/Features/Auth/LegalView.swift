import SwiftUI

enum LegalPage: String, Identifiable {
    var id: String { rawValue }
    case terms = "Terms of Service"
    case privacy = "Privacy Policy"
    case medical = "Medical Disclaimer"
    case community = "Community Guidelines"

    var url: URL {
        switch self {
        case .terms: URL(string: "https://memoryaisle.app/terms")!
        case .privacy: URL(string: "https://memoryaisle.app/privacy")!
        case .medical: URL(string: "https://memoryaisle.app/medical-disclaimer")!
        case .community: URL(string: "https://memoryaisle.app/community-guidelines")!
        }
    }
}

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    let page: LegalPage

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.05)))
                }
                Spacer()
                Text(page.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch page {
                    case .terms:
                        termsContent
                    case .privacy:
                        privacyContent
                    case .medical:
                        medicalContent
                    case .community:
                        communityContent
                    }

                    footer
                }
                .padding(20)
            }
        }
        .themeBackground()
    }

    // MARK: - Terms

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate
            legalHeading("Agreement to Terms")
            legalBody("By downloading, accessing, or using the MemoryAisle mobile application (\"App\"), you agree to be bound by these Terms of Service. MemoryAisle is operated by SLTR Digital LLC, a limited liability company organized under the laws of the State of California, with its principal place of business in Los Angeles, California.")
            legalHeading("Eligibility")
            legalBody("You must be at least 18 years of age to use this App.")
            legalHeading("Medical Disclaimer")
            legalWarning("THIS APP IS NOT A MEDICAL DEVICE, MEDICAL SERVICE, OR HEALTHCARE PROVIDER. MemoryAisle is a nutrition planning tool. It does NOT provide medical advice. It does NOT prescribe, recommend, or endorse any medication. It does NOT replace consultation with your healthcare provider.")
            legalHeading("Nutritional Information")
            legalBody("Nutritional information is generated using third-party databases and AI estimation and may contain inaccuracies. AI-generated content from Mira should be treated as suggestions, not prescriptions.")
            legalHeading("Subscription")
            legalBody("MemoryAisle Pro is $49.99/year via Apple's App Store. Subscriptions auto-renew unless cancelled 24 hours before the end of the current period. Manage subscriptions in your Apple ID settings.")
            legalHeading("Limitation of Liability")
            legalBody("TO THE MAXIMUM EXTENT PERMITTED BY LAW, SLTR DIGITAL LLC SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES. Our aggregate liability shall not exceed the amount you paid in the preceding 12 months, or $50, whichever is greater.")
            legalHeading("Governing Law")
            legalBody("These Terms are governed by the laws of the State of California. Disputes are resolved through binding arbitration in Los Angeles County.")
        }
    }

    // MARK: - Privacy

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate
            legalHeading("Information We Collect")
            legalBody("Account info (email), profile data (dietary preferences, medication type, training level), nutrition logs, symptom data, body composition data, and device/usage information.")
            legalHeading("Medication and Symptom Data")
            legalWarning("Medication type, dosage, and symptom data are encrypted at rest (AES-256) and in transit (TLS 1.3). This data is never shared with third parties, pharmaceutical companies, insurance companies, or data brokers.")
            legalHeading("What We Never Do")
            legalBody("We never sell your personal information. We never use health or medication data for advertising. We never share medication data with any third party. We never store HealthKit data in iCloud.")
            legalHeading("AI Processing")
            legalBody("When you interact with Mira, anonymized nutritional context is sent to AWS Bedrock (Claude by Anthropic). Your full name, email, and raw medication data are never included in AI prompts.")
            legalHeading("Data Deletion")
            legalBody("Request deletion anytime via Profile > Delete Account or email legal@memoryaisle.app. All server-side data is permanently deleted within 24 hours.")
            legalHeading("HealthKit")
            legalBody("We read weight, body composition, and workout data with your permission. HealthKit data is never used for advertising and never stored on our servers.")
        }
    }

    // MARK: - Medical

    private var medicalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate
            legalWarning("MemoryAisle is NOT a medical service, medical device, or healthcare provider. All information is for GENERAL INFORMATIONAL AND EDUCATIONAL PURPOSES ONLY.")
            legalHeading("GLP-1 Medications")
            legalBody("The App accommodates users taking GLP-1 medications with meal timing suggestions and symptom-responsive food recommendations. This does NOT constitute medical management of your GLP-1 therapy. We do not prescribe, recommend, or endorse any medication.")
            legalHeading("Consult Your Provider")
            legalBody("ALWAYS consult your healthcare provider before making significant diet changes while on GLP-1 medications, starting or modifying exercise programs, or changing protein intake targets.")
            legalHeading("Emergency")
            legalWarning("If you experience severe abdominal pain, persistent vomiting, signs of allergic reaction, or any concerning symptoms, STOP using the App for guidance and call 911 or your local emergency number immediately.")
            legalHeading("No Guarantee of Results")
            legalBody("MemoryAisle does not guarantee any specific health outcomes, weight loss results, or body composition changes. Individual results vary.")
            legalHeading("Trademarks")
            legalBody("Ozempic and Wegovy are trademarks of Novo Nordisk. Mounjaro, Zepbound, and Foundayo are trademarks of Eli Lilly. MemoryAisle is not affiliated with any pharmaceutical manufacturer.")
        }
    }

    // MARK: - Community

    private var communityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate
            legalHeading("Purpose")
            legalBody("The MemoryAisle community is for peer support, sharing recipes, meal ideas, and practical nutrition tips. It is NOT a forum for medical advice.")
            legalHeading("What Is Welcome")
            legalBody("Sharing recipes, discussing nausea management food tips, protein-dense meal strategies, grocery shopping experiences, celebrating milestones, and supporting other members.")
            legalHeading("What Is Not Allowed")
            legalWarning("Medical advice of any kind. Recommending users change medications. Sharing compounded medication sources. Promoting supplements or products. Sharing others' health information. Harassment, misinformation, or spam.")
            legalHeading("Moderation")
            legalBody("All content is subject to moderation. Posts violating guidelines will be removed. Repeated violations result in suspension.")
        }
    }

    // MARK: - Components

    private var legalDate: some View {
        Text("Last Updated: April 6, 2026")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.2))
    }

    private func legalHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.top, 4)
    }

    private func legalBody(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))
            .lineSpacing(4)
    }

    private func legalWarning(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.6))
            .lineSpacing(4)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xFBBF24).opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: 0xFBBF24).opacity(0.1), lineWidth: 0.5)
            )
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("SLTR Digital LLC")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.15))
            Text("Los Angeles, California")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.15))
            Text("legal@memoryaisle.app")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}
