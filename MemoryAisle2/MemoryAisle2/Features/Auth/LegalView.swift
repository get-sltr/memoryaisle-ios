import SwiftUI

enum LegalPage: String, Identifiable {
    var id: String { rawValue }
    case terms = "Terms of Service"
    case privacy = "Privacy Policy"
    case medical = "Medical Disclaimer"
    case community = "Community Guidelines"
    case dataPolicy = "Data Policy"

    var url: URL {
        let string = switch self {
        case .terms: "https://memoryaisle.app/terms"
        case .privacy: "https://memoryaisle.app/privacy"
        case .medical: "https://memoryaisle.app/medical-disclaimer"
        case .community: "https://memoryaisle.app/community-guidelines"
        case .dataPolicy: "https://memoryaisle.app/data-policy"
        }
        guard let url = URL(string: string) else { return URL(filePath: "/") }
        return url
    }
}

struct LegalView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let page: LegalPage

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
                Text(page.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Color.clear
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
                    case .dataPolicy:
                        dataPolicyContent
                    }

                    footer
                }
                .padding(20)
            }
        }
        .themeBackground()
    }

    // MARK: - Terms of Service

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate

            legalHeading("1.1 Agreement to Terms")
            legalBody("By downloading, accessing, or using the MemoryAisle mobile application (\"App\"), you agree to be bound by these Terms of Service (\"Terms\"). If you do not agree to these Terms, do not use the App. MemoryAisle is operated by SLTR Digital LLC (\"Company,\" \"we,\" \"us,\" or \"our\"), a limited liability company organized under the laws of the State of California, with its principal place of business in Los Angeles, California.")

            legalHeading("1.2 Eligibility")
            legalBody("You must be at least 18 years of age to use this App. By using the App, you represent and warrant that you are at least 18 years old and have the legal capacity to enter into these Terms. This App is not intended for use by individuals under the age of 18.")

            legalHeading("1.3 MEDICAL DISCLAIMER -- CRITICAL")
            legalWarning("THIS APP IS NOT A MEDICAL DEVICE, MEDICAL SERVICE, OR HEALTHCARE PROVIDER.")
            legalBody("MemoryAisle is a nutrition planning and wellness information tool. It is NOT intended to diagnose, treat, cure, or prevent any disease or medical condition. The App does NOT provide medical advice, and nothing in the App should be construed as medical advice.")
            legalSubheading("REGARDING GLP-1 MEDICATIONS:")
            legalBody("The App provides nutrition information that may reference GLP-1 receptor agonist medications (including but not limited to semaglutide, tirzepatide, orforglipron, and their branded formulations such as Ozempic, Wegovy, Mounjaro, Zepbound, Foundayo, and Rybelsus). This information is for general educational and nutritional planning purposes ONLY.")
            legalBody("The App does NOT:")
            legalBullet("Prescribe, recommend, or endorse any medication")
            legalBullet("Provide dosage guidance or medication timing advice for therapeutic purposes")
            legalBullet("Replace consultation with your prescribing physician, endocrinologist, or healthcare provider")
            legalBullet("Diagnose or assess the appropriateness of any medication for your condition")
            legalBullet("Monitor medication efficacy, side effects, or drug interactions")
            legalBullet("Function as a companion diagnostic or clinical decision support system")
            legalWarning("YOU MUST CONSULT YOUR HEALTHCARE PROVIDER before making any changes to your diet, exercise routine, or nutrition plan, particularly if you are taking prescription medications including GLP-1 receptor agonists. Changes in dietary composition, caloric intake, protein consumption, and meal timing can affect medication absorption, efficacy, and side effects.")
            legalWarning("IF YOU EXPERIENCE ADVERSE SYMPTOMS including but not limited to severe nausea, vomiting, abdominal pain, signs of pancreatitis, thyroid lumps, difficulty swallowing, allergic reactions, or any other concerning symptoms, discontinue use of the App for nutritional guidance and contact your healthcare provider or call 911 immediately.")

            legalHeading("1.4 Nutritional Information Disclaimer")
            legalBody("Nutritional information provided by the App, including but not limited to calorie counts, macronutrient breakdowns (protein, carbohydrates, fat, fiber), micronutrient information, and meal suggestions, is provided for general informational purposes only. This information:")
            legalBullet("Is generated using third-party nutrition databases and AI-based estimation and may contain inaccuracies")
            legalBullet("Should not be relied upon as a sole source of nutritional guidance for medical dietary requirements")
            legalBullet("Does not account for all individual health conditions, allergies, intolerances, drug interactions, or metabolic variations")
            legalBullet("May vary from actual nutritional content due to preparation methods, ingredient substitutions, brand variations, and portion size differences")
            legalSubheading("BARCODE SCANNING:")
            legalBody("Product nutritional information obtained through barcode scanning is sourced from third-party databases. We do not guarantee the accuracy, completeness, or currency of this information. Always verify product labels and consult your healthcare provider for dietary decisions related to your medical treatment.")
            legalSubheading("AI-GENERATED CONTENT:")
            legalBody("Meal plans, food suggestions, nutritional guidance, and conversational responses from the AI assistant (\"Mira\") are generated using artificial intelligence and should be treated as suggestions, not prescriptions. AI-generated content may contain errors and should not replace professional nutritional counseling from a registered dietitian or licensed nutritionist.")

            legalHeading("1.5 Body Composition and Fitness Disclaimer")
            legalBody("Features related to body composition tracking, lean mass estimation, muscle preservation scoring, and training-day nutrition adjustments are informational tools only. They are NOT:")
            legalBullet("Clinical body composition analysis (such as DEXA scans, hydrostatic weighing, or bioelectrical impedance analysis)")
            legalBullet("Medical assessments of sarcopenia, cachexia, or any clinical condition involving muscle loss")
            legalBullet("Substitutes for guidance from a certified personal trainer, exercise physiologist, or sports medicine physician")
            legalBody("Estimates of lean mass, body fat percentage, and muscle preservation scores are approximations based on user-reported data and/or HealthKit data and should not be used for clinical decision-making.")

            legalHeading("1.6 Not a Regulated Medical Device")
            legalBody("MemoryAisle is NOT a regulated medical device under the U.S. Food and Drug Administration (FDA), the European Medicines Agency (EMA), or any other regulatory body. The App has not been reviewed, cleared, or approved by any regulatory agency for any medical purpose.")
            legalBody("Per Apple App Store requirements effective Spring 2026, we declare that MemoryAisle is NOT a regulated medical device in any jurisdiction.")

            legalHeading("1.7 Subscription and Payment Terms")
            legalBody("MemoryAisle offers a free tier with limited features and a paid subscription (\"Pro\") at $49.99 per year (or as otherwise displayed in the App at the time of purchase). Subscriptions are processed through Apple's App Store and are subject to Apple's terms and conditions for in-app purchases and subscriptions.")
            legalBullet("Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period")
            legalBullet("Your account will be charged for renewal within 24 hours prior to the end of the current period at the then-current subscription price")
            legalBullet("You may manage subscriptions and turn off auto-renewal by going to your Apple ID Account Settings after purchase")
            legalBullet("No refunds will be provided for any unused portion of a subscription term")
            legalBullet("Any unused portion of a free trial period, if offered, will be forfeited when you purchase a subscription")

            legalHeading("1.8 User-Generated Content (Community Features)")
            legalBody("If and when community features are available, you are solely responsible for any content you post, including discussion board posts, comments, shared recipes, tips, and other contributions (\"User Content\"). By posting User Content, you grant SLTR Digital LLC a non-exclusive, worldwide, royalty-free, transferable license to use, display, reproduce, and distribute your User Content in connection with the App.")
            legalBody("You agree NOT to post User Content that:")
            legalBullet("Constitutes medical advice, including recommendations to start, stop, change, or adjust any medication")
            legalBullet("Promotes specific medication dosages, compounded medications, or off-label drug use")
            legalBullet("Contains misleading health claims or misinformation about GLP-1 medications")
            legalBullet("Promotes disordered eating, extreme caloric restriction, or unsafe dietary practices")
            legalBullet("Contains personally identifiable health information about other individuals")
            legalBullet("Is defamatory, harassing, threatening, or otherwise objectionable")
            legalBullet("Violates any applicable law or regulation")
            legalBody("We reserve the right to remove any User Content at our sole discretion and to suspend or terminate accounts that violate these guidelines.")

            legalHeading("1.9 Assumption of Risk")
            legalBody("You acknowledge and agree that:")
            legalBullet("Your use of the App is at your sole risk")
            legalBullet("You are solely responsible for all dietary and health decisions")
            legalBullet("The App is a tool to assist with meal planning and nutrition tracking, not a substitute for professional healthcare")
            legalBullet("You should not delay or forego seeking medical advice based on information provided by the App")
            legalBullet("Individual results from following any nutrition plan will vary based on numerous factors including but not limited to genetics, adherence, medical history, medication, activity level, and metabolic factors")

            legalHeading("1.10 Limitation of Liability")
            legalWarning("TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL SLTR DIGITAL LLC, ITS OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, OR AFFILIATES BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING WITHOUT LIMITATION, LOSS OF PROFITS, DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES, RESULTING FROM:\n\n(i) YOUR ACCESS TO OR USE OF OR INABILITY TO ACCESS OR USE THE APP;\n(ii) ANY CONDUCT OR CONTENT OF ANY THIRD PARTY ON THE APP;\n(iii) ANY CONTENT OBTAINED FROM THE APP, INCLUDING NUTRITIONAL INFORMATION, MEAL PLANS, AI-GENERATED SUGGESTIONS, AND BARCODE SCAN RESULTS;\n(iv) ANY ADVERSE HEALTH OUTCOME RELATED TO DIETARY CHANGES MADE IN CONNECTION WITH USE OF THE APP;\n(v) UNAUTHORIZED ACCESS, USE, OR ALTERATION OF YOUR TRANSMISSIONS OR CONTENT.\n\nIN NO EVENT SHALL OUR AGGREGATE LIABILITY EXCEED THE AMOUNT YOU PAID US IN THE TWELVE (12) MONTHS PRECEDING THE CLAIM, OR FIFTY DOLLARS ($50.00), WHICHEVER IS GREATER.")

            legalHeading("1.11 Indemnification")
            legalBody("You agree to defend, indemnify, and hold harmless SLTR Digital LLC and its officers, directors, employees, and agents from and against any claims, liabilities, damages, judgments, awards, losses, costs, expenses, or fees (including reasonable attorneys' fees) arising out of or relating to your violation of these Terms or your use of the App, including but not limited to any health outcomes resulting from dietary decisions made using the App.")

            legalHeading("1.12 Intellectual Property")
            legalBody("The App and its original content, features, and functionality are and will remain the exclusive property of SLTR Digital LLC. The App is protected by copyright, trademark, and other laws of the United States and foreign countries. Our trademarks may not be used in connection with any product or service without our prior written consent.")
            legalBody("\"MemoryAisle,\" \"Mira,\" and the MemoryAisle waveform logo are trademarks of SLTR Digital LLC.")

            legalHeading("1.13 Governing Law and Dispute Resolution")
            legalBody("These Terms shall be governed by and construed in accordance with the laws of the State of California, without regard to its conflict of law provisions. Any dispute arising from or relating to these Terms or your use of the App shall be resolved through binding arbitration administered by the American Arbitration Association under its Consumer Arbitration Rules, conducted in Los Angeles County, California. YOU AGREE TO WAIVE YOUR RIGHT TO A JURY TRIAL AND TO PARTICIPATE IN A CLASS ACTION LAWSUIT OR CLASS-WIDE ARBITRATION.")

            legalHeading("1.14 Changes to Terms")
            legalBody("We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days' notice prior to any new terms taking effect. By continuing to access or use the App after those revisions become effective, you agree to be bound by the revised Terms.")

            legalHeading("1.15 Contact")
            legalBody("SLTR Digital LLC\nLos Angeles, California\nEmail: legal@memoryaisle.app")
        }
    }

    // MARK: - Privacy Policy

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate

            legalHeading("2.1 Overview")
            legalBody("SLTR Digital LLC (\"we,\" \"us,\" or \"our\") operates the MemoryAisle mobile application (\"App\"). This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our App.")

            legalHeading("2.2 Information We Collect")

            legalSubheading("2.2.1 Information You Provide")
            legalBullet("Account Information: Email address, name (optional), and authentication credentials via Amazon Cognito")
            legalBullet("Profile Information: Dietary preferences, allergies, dietary restrictions, training schedule, health goals")
            legalBullet("Medication Information: GLP-1 medication type, dosage, administration method (injection or oral), dosing schedule. THIS INFORMATION IS ENCRYPTED AT REST AND IN TRANSIT.")
            legalBullet("Nutrition Data: Meal logs, protein intake, calorie tracking, hydration logs, fiber intake, food preferences, barcode scan history")
            legalBullet("Symptom Data: Self-reported symptoms including nausea, food aversions, energy levels, digestive comfort. THIS INFORMATION IS ENCRYPTED AT REST AND IN TRANSIT.")
            legalBullet("Body Composition Data: Weight, body fat percentage (if provided), lean mass estimates")
            legalBullet("Community Content: Discussion board posts, comments, shared recipes (if community features are active)")

            legalSubheading("2.2.2 Information Collected Automatically")
            legalBullet("Device Information: Device type, operating system version, unique device identifiers")
            legalBullet("Usage Data: Features accessed, screens viewed, session duration, interaction patterns")
            legalBullet("Crash Data: App crash logs and performance diagnostics")

            legalSubheading("2.2.3 Information from Third Parties")
            legalBullet("Apple HealthKit: With your explicit permission, we read weight, lean body mass, and body fat percentage from HealthKit and write dietary energy (calories) and dietary protein data to HealthKit when you log meals. HealthKit data is NEVER used for advertising or marketing purposes.")
            legalBullet("Nutrition Databases: When you scan a barcode or search for a food, we query third-party nutrition databases. These queries do not contain your personal information.")

            legalHeading("2.3 How We Use Your Information")
            legalBody("We use your information to:")
            legalBullet("Provide and maintain the App")
            legalBullet("Generate personalized meal plans and nutrition guidance")
            legalBullet("Power the AI assistant (Mira) with contextual awareness of your preferences and goals")
            legalBullet("Track your nutritional progress and provide insights")
            legalBullet("Generate grocery lists based on your meal plans")
            legalBullet("Provide barcode scan verdicts relevant to your dietary profile")
            legalBullet("Generate provider reports at your request")
            legalBullet("Send notifications (with your permission) for hydration reminders, protein targets, and meal suggestions")
            legalBullet("Improve the App and develop new features")
            legalBullet("Respond to your inquiries and provide customer support")

            legalHeading("2.4 How We Do NOT Use Your Information")
            legalBody("We DO NOT:")
            legalBullet("Sell your personal information to any third party. Ever.")
            legalBullet("Use your health, medication, or nutrition data for advertising or marketing purposes")
            legalBullet("Share your medication information with any third party (including pharmacies, pharmaceutical companies, insurance companies, or data brokers)")
            legalBullet("Use HealthKit data for any purpose other than providing App functionality you requested")
            legalBullet("Store raw audio from voice interactions beyond the duration needed for transcription")
            legalBullet("Create de-identified datasets from medication data for sale or licensing")

            legalHeading("2.5 AI Processing")
            legalBody("When you interact with Mira (the AI assistant), your prompts are sent to Amazon Web Services (AWS) Bedrock for processing by an AI model (Claude by Anthropic). These prompts include contextual information about your nutritional profile, dietary preferences, and current meal plan state. They do NOT include your full name, email address, or raw medication data. Prompts are not stored by the AI provider beyond the duration of the request.")

            legalHeading("2.6 Data Security")
            legalBody("We implement industry-standard security measures including:")
            legalBullet("Encryption of all data in transit using TLS 1.3")
            legalBullet("Encryption of sensitive data at rest using AES-256 (medication data, symptom data, health information)")
            legalBullet("Authentication via Amazon Cognito with JSON Web Tokens (JWT)")
            legalBullet("API rate limiting and WAF (Web Application Firewall) protection")
            legalBullet("Credentials stored in iOS Keychain, not in application storage")
            legalBullet("No personal health data stored in iCloud")

            legalHeading("2.7 Data Retention")
            legalBullet("Account data: Retained for the duration of your account plus 30 days after deletion request")
            legalBullet("Nutrition logs: Retained for the duration of your account")
            legalBullet("Voice transcriptions: Processed in real-time and not stored after transcription is complete")
            legalBullet("Barcode scan results: Cached locally on device for 30 days for offline access")
            legalBullet("Community posts: Retained until deleted by you or removed by moderation")

            legalHeading("2.8 Data Deletion")
            legalBody("You may request deletion of all your data at any time through the App (Profile > Delete Account) or by emailing legal@memoryaisle.app. Upon receiving a deletion request:")
            legalBullet("All server-side data will be permanently deleted within 24 hours")
            legalBullet("Local data on your device will be cleared immediately upon account deletion in the App")
            legalBullet("Community posts you created will be anonymized (username replaced with \"Deleted User\")")
            legalBullet("This action is irreversible")

            legalHeading("2.9 Children's Privacy")
            legalBody("The App is not intended for use by anyone under the age of 18. We do not knowingly collect personal information from children under 18. If you are a parent or guardian and believe your child has provided us with personal information, please contact us at legal@memoryaisle.app and we will promptly delete such information.")

            legalHeading("2.10 California Privacy Rights (CCPA)")
            legalBody("If you are a California resident, you have the right to:")
            legalBullet("Request disclosure of the categories and specific pieces of personal information we collect")
            legalBullet("Request deletion of your personal information")
            legalBullet("Opt out of the sale of your personal information (we do not sell personal information)")
            legalBullet("Not be discriminated against for exercising your privacy rights")
            legalBody("To exercise these rights, contact legal@memoryaisle.app.")

            legalHeading("2.11 International Users")
            legalBody("The App is operated from the United States. If you are accessing the App from outside the United States, please be aware that your information may be transferred to, stored, and processed in the United States where our servers are located and our central database is operated.")

            legalHeading("2.12 Changes to Privacy Policy")
            legalBody("We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the App and updating the \"Last Updated\" date. You are advised to review this Privacy Policy periodically.")
        }
    }

    // MARK: - Medical Disclaimer

    private var medicalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate
            legalWarning("THIS DOCUMENT MUST BE DISPLAYED PROMINENTLY IN THE APP AND ACCEPTED BY USERS DURING ONBOARDING.")

            legalHeading("3.1 Not Medical Advice")
            legalWarning("MemoryAisle is a nutrition planning and wellness information application. IT IS NOT A MEDICAL SERVICE, MEDICAL DEVICE, OR HEALTHCARE PROVIDER.")
            legalBody("All information provided by MemoryAisle, including but not limited to meal plans, nutritional guidance, protein targets, hydration recommendations, symptom-related food suggestions, barcode scan verdicts, and AI-generated conversational responses from Mira, is for GENERAL INFORMATIONAL AND EDUCATIONAL PURPOSES ONLY.")

            legalHeading("3.2 GLP-1 Medication Disclaimer")
            legalBody("MemoryAisle provides features that accommodate users who are taking GLP-1 receptor agonist medications. This accommodation includes meal timing suggestions, appetite-aware portion sizing, and symptom-responsive food recommendations.")
            legalWarning("THIS DOES NOT CONSTITUTE MEDICAL MANAGEMENT OF YOUR GLP-1 THERAPY.")
            legalBullet("We do NOT prescribe, recommend, dispense, or endorse any medication")
            legalBullet("We do NOT provide dosage recommendations or adjustments")
            legalBullet("We do NOT monitor medication levels, efficacy, or side effects for clinical purposes")
            legalBullet("We do NOT replace your prescribing physician, endocrinologist, registered dietitian, or any healthcare provider")
            legalBullet("Information about GLP-1 medications referenced in the App is sourced from publicly available medical literature and is provided for educational context only")
            legalBullet("Medication names (Ozempic, Wegovy, Mounjaro, Zepbound, Foundayo, Rybelsus, and others) are registered trademarks of their respective manufacturers and their inclusion in the App does not imply endorsement, affiliation, or sponsorship")

            legalHeading("3.3 Consult Your Healthcare Provider")
            legalBody("ALWAYS consult your healthcare provider before:")
            legalBullet("Making significant changes to your diet while on GLP-1 medications")
            legalBullet("Starting or modifying an exercise program while on GLP-1 medications")
            legalBullet("Changing your protein intake targets")
            legalBullet("Making dietary changes to address symptoms related to your medication")
            legalBullet("Using information from this App to make decisions about your medication regimen")

            legalHeading("3.4 Emergency Situations")
            legalBody("If you experience any of the following, STOP using the App for nutritional guidance and seek immediate medical attention:")
            legalBullet("Severe abdominal pain (possible sign of pancreatitis)")
            legalBullet("Persistent vomiting or inability to keep fluids down")
            legalBullet("Signs of allergic reaction (swelling, difficulty breathing, rash)")
            legalBullet("Lumps or swelling in your neck (possible thyroid concern)")
            legalBullet("Signs of hypoglycemia (shakiness, confusion, rapid heartbeat)")
            legalBullet("Any other symptoms that concern you")
            legalWarning("In case of emergency, call 911 or your local emergency number.")

            legalHeading("3.5 No Guarantee of Results")
            legalBody("MemoryAisle does not guarantee any specific health outcomes, weight loss results, body composition changes, or symptom improvements. Individual results vary based on numerous factors including genetics, adherence to plans, medication response, activity level, pre-existing conditions, and many other variables beyond the control of this App.")

            legalHeading("3.6 Third-Party Trademarks")
            legalBody("Ozempic and Wegovy are registered trademarks of Novo Nordisk A/S. Mounjaro and Zepbound are registered trademarks of Eli Lilly and Company. Foundayo is a registered trademark of Eli Lilly and Company. Rybelsus is a registered trademark of Novo Nordisk A/S. MemoryAisle is not affiliated with, endorsed by, or sponsored by any pharmaceutical manufacturer. The use of these names is for identification and informational purposes only.")
        }
    }

    // MARK: - Community Guidelines

    private var communityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate

            legalHeading("4.1 Purpose")
            legalBody("The MemoryAisle community exists to provide peer support, share experiences, and exchange practical tips related to nutrition, meal planning, and wellness. It is NOT a forum for medical advice.")

            legalHeading("4.2 Rules")
            legalSubheading("What is welcome:")
            legalBullet("Sharing recipes and meal ideas")
            legalBullet("Discussing nausea management tips (food-related, not medication-related)")
            legalBullet("Sharing protein-dense meal strategies")
            legalBullet("Discussing grocery shopping experiences")
            legalBullet("Celebrating milestones and progress")
            legalBullet("Sharing workout and training nutrition strategies")
            legalBullet("Asking questions about App features")
            legalBullet("Supporting other community members")

            legalSubheading("What is NOT allowed:")
            legalBullet("Medical advice of any kind, including recommendations about medications, dosages, injection sites, or drug interactions")
            legalBullet("Recommending users start, stop, or change any medication")
            legalBullet("Sharing specific compounded medication sources or providers")
            legalBullet("Promoting or selling any product, service, supplement, or medication")
            legalBullet("Sharing other users' personal health information")
            legalBullet("Promoting extreme dietary restriction, disordered eating, or unhealthy behaviors")
            legalBullet("Harassment, bullying, discrimination, or hate speech")
            legalBullet("Misinformation about GLP-1 medications, nutrition science, or health")
            legalBullet("Spam, self-promotion, or commercial solicitation")
            legalBullet("Sharing personal contact information")

            legalHeading("4.3 Moderation")
            legalBody("All community content is subject to moderation. We use a combination of AI-assisted flagging and human review. Posts that violate community guidelines will be removed. Repeated violations will result in temporary or permanent suspension of community privileges.")

            legalHeading("4.4 Disclaimer")
            legalBody("Posts in the community represent the personal experiences and opinions of individual users. They do NOT represent the views of SLTR Digital LLC, and they should NOT be treated as medical advice, nutritional prescriptions, or professional guidance. Always consult your healthcare provider before making health decisions based on information shared in the community.")
        }
    }

    // MARK: - Data Policy

    private var dataPolicyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            legalDate

            legalHeading("5. DATA PROCESSING ADDENDUM")

            legalHeading("5.1 Health Data Classification")
            legalBody("MemoryAisle processes the following categories of health-related data:")

            legalSubheading("Medication type and dose")
            legalBullet("Sensitivity Level: HIGH")
            legalBullet("Encryption: AES-256 at rest, TLS 1.3 in transit")
            legalBullet("Retention: Duration of account + 30 days")

            legalSubheading("Symptom logs")
            legalBullet("Sensitivity Level: HIGH")
            legalBullet("Encryption: AES-256 at rest, TLS 1.3 in transit")
            legalBullet("Retention: Duration of account + 30 days")

            legalSubheading("Body weight and composition")
            legalBullet("Sensitivity Level: MEDIUM")
            legalBullet("Encryption: AES-256 at rest, TLS 1.3 in transit")
            legalBullet("Retention: Duration of account + 30 days")

            legalSubheading("Nutrition logs (meals, macros)")
            legalBullet("Sensitivity Level: MEDIUM")
            legalBullet("Encryption: TLS 1.3 in transit")
            legalBullet("Retention: Duration of account + 30 days")

            legalSubheading("Dietary preferences")
            legalBullet("Sensitivity Level: LOW")
            legalBullet("Encryption: TLS 1.3 in transit")
            legalBullet("Retention: Duration of account + 30 days")

            legalSubheading("Barcode scan history")
            legalBullet("Sensitivity Level: LOW")
            legalBullet("Encryption: Local device only")
            legalBullet("Retention: 30 days")

            legalSubheading("Voice transcriptions")
            legalBullet("Sensitivity Level: MEDIUM")
            legalBullet("Encryption: Processed in-memory only")
            legalBullet("Retention: Not stored")

            legalHeading("5.2 Sub-processors")

            legalSubheading("Amazon Web Services (AWS)")
            legalBullet("Purpose: Cloud infrastructure, database, authentication, AI processing")
            legalBullet("Data Accessed: All server-side data (encrypted)")

            legalSubheading("Anthropic (via AWS Bedrock)")
            legalBullet("Purpose: AI meal generation and conversational responses")
            legalBullet("Data Accessed: Anonymized nutritional context (no PII)")

            legalSubheading("FatSecret or Nutritionix")
            legalBullet("Purpose: Nutrition database lookups")
            legalBullet("Data Accessed: Food names and barcodes (no user identity)")

            legalSubheading("Apple HealthKit")
            legalBullet("Purpose: Health data integration (read body composition, write nutrition)")
            legalBullet("Data Accessed: On-device only (not transmitted to our servers). Reads: weight, lean body mass, body fat percentage. Writes: dietary energy consumed, dietary protein.")

            legalHeading("5.3 Apple App Store Requirements")
            legalBody("Per Apple's Health & Fitness app requirements:")
            legalBullet("Health and fitness data collected through the App is never used for advertising")
            legalBullet("Health and fitness data is never sold to data brokers")
            legalBullet("HealthKit data is never stored in iCloud")
            legalBullet("We do not write false or inaccurate data to HealthKit")
            legalBullet("Users can revoke HealthKit access at any time through iOS Settings")
            legalBody("Per Apple's Spring 2026 Medical Device Disclosure requirement:")
            legalBullet("MemoryAisle is declared as NOT a regulated medical device in any jurisdiction")
            legalBullet("The App does not function as a Software as a Medical Device (SaMD)")
            legalBullet("The App does not perform clinical diagnostic, monitoring, or therapeutic functions")

            legalHeading("6. ACCEPTABLE USE POLICY")

            legalHeading("6.1 Prohibited Uses")
            legalBody("You agree not to use the App to:")
            legalBullet("Provide or solicit medical advice to or from other users")
            legalBullet("Misrepresent yourself as a healthcare provider, registered dietitian, or medical professional")
            legalBullet("Use the App as a substitute for professional medical care")
            legalBullet("Attempt to reverse-engineer, decompile, or extract source code from the App")
            legalBullet("Use the App in any manner that could interfere with, disrupt, or negatively affect the App or its servers")
            legalBullet("Use automated scripts, bots, or scrapers to access the App")
            legalBullet("Collect or harvest personal information of other users")
            legalBullet("Resell, redistribute, or commercially exploit any content from the App")

            legalHeading("7. COOKIE AND TRACKING POLICY (WEB)")

            legalHeading("7.1 Website (memoryaisle.app)")
            legalBody("If you visit our website, we use:")
            legalBullet("Essential cookies: Required for website functionality (session management, authentication)")
            legalBullet("Analytics cookies: Google Analytics (GA4) to understand website traffic and usage patterns. These cookies collect anonymous usage data and do not track individual health information.")
            legalBody("We do NOT use:")
            legalBullet("Advertising or targeting cookies")
            legalBullet("Third-party tracking pixels")
            legalBullet("Cross-site tracking technologies")
        }
    }

    // MARK: - Components

    private var legalDate: some View {
        Text("Last Updated: April 6, 2026")
            .font(.system(size: 11))
            .foregroundStyle(Theme.Text.tertiary(for: scheme))
    }

    private func legalHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.Text.primary)
            .padding(.top, 4)
    }

    private func legalSubheading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Text.secondary(for: scheme))
            .padding(.top, 2)
    }

    private func legalBody(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.Text.secondary(for: scheme))
            .lineSpacing(4)
    }

    private func legalWarning(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.Semantic.fiber(for: scheme).opacity(0.6))
            .lineSpacing(4)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.Semantic.fiber(for: scheme).opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Semantic.fiber(for: scheme).opacity(0.1), lineWidth: 0.5)
            )
    }

    private func legalBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("SLTR Digital LLC")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            Text("Los Angeles, California")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            Text("legal@memoryaisle.app")
                .font(.system(size: 11))
                .foregroundStyle(Color.violet.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}
