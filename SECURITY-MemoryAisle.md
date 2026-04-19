# MemoryAisle -- Security & Trust Architecture
# Addendum to CLAUDE-MemoryAisle.md

> Drop this entire section into the CLAUDE.md under a new top-level heading.
> This replaces any existing security/privacy sections.

---

## Security & Trust Architecture

### Philosophy

MemoryAisle handles medication data, body composition, symptom logs, and nutrition history. This is health data. The security posture must reflect that reality. The guiding principle is: **assume breach, protect anyway.** Every layer assumes the layer above it has failed.

The user must feel safe before they enter a single data point. Trust is not a feature. It is the product.

---

### 1. Data Classification

Every piece of data in MemoryAisle is classified into one of four tiers. The tier determines encryption, storage location, retention, and access rules.

**TIER 1 -- CRITICAL (never leaves device unencrypted)**
- GLP-1 medication type and dosage
- Injection/dose schedule and timestamps
- Symptom logs (nausea severity, appetite state, side effects)
- Body weight and body composition readings
- Provider report exports

**TIER 2 -- SENSITIVE (encrypted at rest and in transit, server-side)**
- Meal plans and nutrition logs
- Grocery lists and pantry inventory
- Barcode scan history
- Mira conversation history
- User profile (name, email, goals, dietary restrictions)

**TIER 3 -- INTERNAL (standard encryption)**
- App usage analytics (anonymized)
- Feature flags and A/B test assignments
- Crash reports (no PII)

**TIER 4 -- PUBLIC**
- App metadata
- Generic nutrition database lookups
- Community discussion posts (user-chosen display name only)

---

### 2. Application-Layer Encryption (ALE)

DynamoDB encrypts at rest by default (SSE-KMS). That protects against physical disk theft at AWS. It does NOT protect against:
- A compromised Lambda function reading plaintext records
- An AWS IAM credential leak exposing the table
- An insider or attacker with database-level read access

For TIER 1 data, MemoryAisle adds a second encryption layer BEFORE data hits DynamoDB.

**Implementation:**

```
User Device (plaintext)
    |
    v
API Gateway (TLS 1.3 in transit)
    |
    v
Lambda Function
    |
    +--> KMS Envelope Encryption
    |      |
    |      +--> Generate data key from KMS CMK (Customer Master Key)
    |      +--> Encrypt TIER 1 fields with data key (AES-256-GCM)
    |      +--> Store encrypted data key alongside ciphertext
    |      +--> Discard plaintext data key from memory
    |
    v
DynamoDB (stores ciphertext only for TIER 1 fields)
```

**KMS Key Policy:**
- One CMK per environment (dev, staging, prod)
- Key alias: `alias/memoryaisle-health-data-{env}`
- Key rotation: automatic annual rotation enabled
- Access: ONLY the MemoryAisle Lambda execution role can call `kms:Decrypt` and `kms:GenerateDataKey`
- No human IAM user has decrypt permission in production
- CloudTrail logs every KMS API call

**What this means in practice:**
If someone dumps the entire DynamoDB table, TIER 1 fields (medication, dosage, symptoms, body composition) are AES-256-GCM ciphertext. Useless without the KMS key. And the KMS key cannot be extracted from AWS. It lives in hardware security modules.

---

### 3. On-Device Processing

The safest data is data that never leaves the device. MemoryAisle processes the following entirely on-device using Apple frameworks:

**HealthKit Data (body composition, weight, workouts):**
- Read via HealthKit API
- Processed in-memory for dashboard display and Mira's recommendations
- NEVER sent to the server in raw form
- Only anonymized aggregates (weekly protein target adjustment, lean mass trend direction) are synced
- User sees: "Your body data never leaves your phone"

**Barcode Scanning:**
- Apple Vision framework runs on-device
- Camera feed never transmitted
- Only the decoded barcode string (UPC/EAN) is sent to the nutrition API for lookup

**Voice Input (Mira):**
- Apple Speech framework (SFSpeechRecognizer) runs on-device transcription
- Audio is never sent to any server
- Only the transcribed text string is sent to Bedrock for Mira's response
- User sees: "Your voice stays on your device. Only text reaches Mira."

**Biometric Auth:**
- Face ID / Touch ID via LocalAuthentication framework
- Biometric data never leaves the Secure Enclave
- Used to gate access to TIER 1 data screens (medication log, body composition, provider reports)

---

### 4. Anonymized Medication Processing

This is the most sensitive design decision. When a user tells Mira "I'm on Ozempic 0.5mg, I injected yesterday," here is what happens:

**On-device:**
1. Speech transcribed locally (Apple Speech)
2. Medication context stored in SwiftData (on-device, encrypted by iOS Data Protection)
3. A medication context token is generated: `{ class: "glp1_agonist", subclass: "semaglutide", dose_tier: "low", days_since_dose: 1, current_phase: "appetite_suppression" }`
4. This token contains NO brand names, NO exact dosages, NO personally identifiable medical info

**Sent to Bedrock (Claude):**
```json
{
  "user_context": {
    "medication_class": "glp1_agonist",
    "dose_tier": "low",
    "days_since_dose": 1,
    "phase": "appetite_suppression",
    "symptom_state": "mild_nausea",
    "protein_target_g": 120,
    "protein_consumed_g": 45,
    "training_today": true,
    "dietary_restrictions": ["dairy_free"]
  },
  "query": "What should I eat for dinner?"
}
```

**What Bedrock/Claude NEVER receives:**
- User's real name
- Email address
- "Ozempic" or any brand name
- "0.5mg" or any exact dosage
- Injection dates
- Body weight or composition numbers
- Any data that could identify a specific person

**The server stores:**
- The anonymized context token (encrypted with ALE for TIER 1)
- Mira's response text (TIER 2 encryption)
- A session ID that maps to the user only via Cognito token (which expires)

**User-facing explanation (shown in onboarding and settings):**
"When you talk to Mira, your medication details stay on your phone. Mira only sees general categories like 'GLP-1 medication, low dose, day 2' -- never your exact prescription. Your name, email, and health numbers are never sent to AI."

---

### 5. Authentication Hardening

**Primary login: Apple Sign In**
- Required by Apple if you offer any social login
- No password to steal, no email/password database to breach
- Users already trust Apple with biometrics
- Token refresh handled by AuthenticationServices framework

**Fallback: Email + Password via Cognito**
- SRP (Secure Remote Password) protocol -- password never sent over the wire
- Minimum 12 characters, complexity requirements enforced client-side and server-side
- MFA required for email login (TOTP via authenticator app, not SMS)
- SMS-based MFA explicitly disabled (SIM swap attacks)

**Session Management:**
- Access tokens: 15-minute expiry
- Refresh tokens: 30-day expiry
- Token stored in iOS Keychain (hardware-backed on devices with Secure Enclave)
- Automatic token refresh via Cognito SDK
- Force logout on: password change, suspicious activity, account recovery

**Biometric Gate:**
- Face ID / Touch ID required to view TIER 1 screens after initial unlock
- Re-authentication required after 5 minutes of inactivity on TIER 1 screens
- Configurable by user in settings (can disable, but shown a warning)

---

### 6. Network Security

**TLS 1.3 enforced** on all connections. No fallback to 1.2.

**Certificate pinning** via TrustKit or equivalent:
- Pin the leaf certificate for the API domain
- Pin backup certificate for rotation
- Failure mode: block request, show user-friendly error, log to CloudWatch

**API Gateway:**
- WAF rules: rate limiting (100 req/min per user), SQL injection detection, XSS filtering
- Request signing: all requests include Cognito JWT in Authorization header
- No API keys in client code (Cognito handles auth)
- CORS: locked to memoryaisle.app and the iOS bundle identifier

**DNS:**
- DNSSEC enabled on Route 53 hosted zone
- CAA records restricting certificate issuance to Amazon and Let's Encrypt only

---

### 7. Data Retention & Deletion

| Data Type | Retention | Deletion Trigger |
|---|---|---|
| Medication logs (TIER 1) | Until user deletes or account deletion | User action or 30 days post-account-deletion |
| Symptom logs (TIER 1) | Until user deletes or account deletion | User action or 30 days post-account-deletion |
| Body composition (TIER 1) | On-device only, never server-stored | User deletes app or resets HealthKit permissions |
| Meal plans (TIER 2) | 12 months rolling | Auto-purge older records |
| Mira conversations (TIER 2) | 90 days | Auto-purge, user can clear anytime |
| Grocery lists (TIER 2) | 30 days after completion | Auto-purge |
| Analytics (TIER 3) | 12 months | Auto-purge, anonymized |
| Community posts (TIER 4) | Until user deletes | User action |

**Account Deletion:**
- User initiates from Settings > Privacy > Delete My Account
- Cognito user pool record: deleted immediately
- DynamoDB records: marked for deletion, purged within 30 days by scheduled Lambda
- S3 objects (provider report PDFs): deleted within 7 days
- KMS data keys associated with user: orphaned (ciphertext becomes permanently unrecoverable)
- Apple requires this flow for App Store compliance

**Right to Export:**
- User can export all their data as a JSON file from Settings > Privacy > Export My Data
- Export includes all TIER 1 and TIER 2 data in plaintext (decrypted on-device)
- CCPA and GDPR compliant

---

### 8. Trust UI -- Making Users FEEL Safe

Security architecture means nothing if the user doesn't know it exists. These are the visible trust elements built into the app:

**Onboarding (before any data collection):**
- Screen 3 in Mira's setup flow: "Your health data is sacred"
- Animated shield icon
- Three bullet points (voice-read by Mira):
  - "Your medication details never leave your phone"
  - "Your voice is transcribed on-device and never recorded"
  - "Your body data stays in Apple Health, not on our servers"
- User must tap "I understand" to proceed
- This screen cannot be skipped

**Privacy Dashboard (Settings > Privacy):**
- Visual breakdown of what data is stored where
- On-device indicator (green shield) vs. cloud indicator (blue lock) for each data type
- One-tap to view, export, or delete any category
- Last access log: "Mira accessed your medication context 3 hours ago"
- No dark patterns. Delete means delete.

**In-App Trust Signals:**
- Small lock icon next to TIER 1 data fields (medication, weight, symptoms)
- "On-device only" badge next to HealthKit data
- "Encrypted" badge next to medication logs
- Mira says "I don't store this" when discussing sensitive topics

**App Store Description:**
- "Your health data is encrypted with bank-grade security (AES-256)"
- "Medication details are processed on-device. Our AI never sees your prescription."
- "We never sell your data. We never share it with pharma companies or insurers."
- "Delete your account and all data is permanently erased."

---

### 9. Incident Response

Even with all these controls, plan for failure.

**Monitoring:**
- CloudWatch alarms on: unusual KMS decrypt volume, API error rate spike, WAF rule triggers, Cognito failed auth spike
- CloudTrail enabled for all API calls
- GuardDuty enabled for threat detection

**If a breach is suspected:**
1. Rotate KMS CMK immediately (all existing data keys remain valid under old key version)
2. Force-expire all Cognito sessions (users must re-authenticate)
3. Enable enhanced logging on API Gateway
4. Notify affected users within 72 hours (CCPA/GDPR requirement)
5. File with California AG if 500+ California residents affected

**Bug Bounty (Phase 2):**
- security@memoryaisle.app for responsible disclosure
- Scope: API, authentication, data exposure
- Response SLA: acknowledge within 48 hours, fix critical within 7 days

---

### 10. Compliance Checklist

- [ ] Apple App Store Privacy Nutrition Labels (declare all data types accurately)
- [ ] Apple Medical Device Regulatory Status declaration (Spring 2026 requirement)
- [ ] CCPA: privacy policy, do-not-sell, right to delete, right to know
- [ ] HIPAA: NOT required (MemoryAisle is not a covered entity and does not process PHI on behalf of one). But we follow HIPAA-grade encryption standards anyway because it's the right thing to do.
- [ ] SOC 2 Type I: target for Month 12 post-launch (builds enterprise/partnership credibility)
- [ ] Bedrock/Claude: confirm Anthropic's data processing terms allow health-adjacent context (they do as of 2025, but verify current terms)
- [ ] FatSecret/Nutritionix API: confirm their terms allow use in health-adjacent applications

---

### 11. What We Tell Users (Plain English)

This goes on memoryaisle.app/security and is linked from the app's Settings:

**"How we protect your data"**

Your health information is personal. Here is exactly what we do with it:

**Your medication details stay on your phone.** When you tell Mira about your medication, she processes it locally. Our AI only sees general categories like "GLP-1, low dose, day 2" -- never your exact prescription or brand name.

**Your voice is never recorded.** Speech recognition runs on your device using Apple's built-in technology. Only the text of what you said reaches Mira. The audio is discarded instantly.

**Your body data stays in Apple Health.** We read your weight and body composition to give you better recommendations, but we never copy it to our servers.

**Everything sensitive is encrypted twice.** Once by AWS (the same infrastructure banks use), and again by our own encryption layer. Even if someone broke into our database, your medication and symptom data would be unreadable gibberish.

**We never sell your data.** Not to pharma companies. Not to insurers. Not to advertisers. Not to anyone. Ever.

**You can delete everything.** Go to Settings > Privacy > Delete My Account. All your data is permanently erased within 30 days. No questions asked.

**We never share your data with your employer, insurer, or anyone else** unless you explicitly export a provider report yourself and choose to share it.

---

*This document is a living spec. Update it as the security posture evolves. Have a real attorney review the legal/compliance sections before launch.*
