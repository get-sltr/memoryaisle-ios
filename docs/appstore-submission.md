# MemoryAisle - App Store Submission Guide

## App Store Connect Metadata

### App Name
MemoryAisle

### Subtitle (30 chars max)
GLP-1 meal planning that protects muscle

### Keywords (100 chars max)
glp1,ozempic,wegovy,mounjaro,protein,meal plan,nutrition,muscle,body composition,weight loss,zepbound

### Description
MemoryAisle is the adaptive nutrition platform for GLP-1 medication users who want to lose fat without losing muscle.

39% of weight lost on GLP-1 medications is lean mass. MemoryAisle solves that with personalized meals, grocery lists, and daily guidance that adapt to your appetite, symptoms, and training goals.

WHAT MEMORYAISLE DOES

Protein-First Meal Plans
Mira, your AI nutrition companion, generates daily meals optimized for your protein target, medication phase, and dietary needs. Every recipe includes exact ingredients and step-by-step cooking instructions.

Medication-Aware Nutrition
The app knows where you are in your injection cycle or oral dosing schedule. On high-nausea days, meals are gentler and smaller. On appetite-return days, portions increase to maximize protein intake.

Smart Grocery Lists
Scan barcodes in-store and get instant verdicts: "Good choice: 24g protein, nausea-safe" or "Skip: high fat, slow gastric emptying." Your grocery list is generated from your meal plan.

Body Composition Tracking
Track weight, lean mass, and body fat over time. See your muscle preservation score and share weekly provider reports with your doctor.

5 Adaptive Modes
Switch between Everyday GLP-1, Sensitive Stomach, Muscle Preservation, Training Performance, and Maintenance/Taper. Each mode adjusts meals, portions, and guidance.

PRIVACY FIRST
Your medication details never leave your phone. Our AI only sees anonymous categories like "GLP-1, low dose, day 2." Your voice is transcribed on-device. Your body data stays in Apple Health.

SUPPORTED MEDICATIONS
Ozempic, Wegovy, Wegovy Pill, Mounjaro, Zepbound, Foundayo, Rybelsus, compounded semaglutide and tirzepatide.

Free to try. Pro unlocks unlimited meal plans, barcode scans, and provider reports for $49.99/year.

### Promotional Text (170 chars max)
Lose fat without losing muscle. AI-powered meal plans that adapt to your GLP-1 medication cycle, appetite, and training goals.

### Category
Primary: Health & Fitness
Secondary: Food & Drink

### Age Rating
12+ (Medical/Treatment Information)

---

## Privacy Nutrition Labels

### Data Collected

**Health & Fitness Data**
- Health data (HealthKit - weight, body composition)
- Used for: App Functionality
- Linked to user: Yes
- Tracking: No

**Body Data**
- Body measurements (weight, body fat %, lean mass)
- Used for: App Functionality
- Linked to user: Yes
- Tracking: No

**User Content**
- Photos (progress photos, meal photos)
- Used for: App Functionality
- Linked to user: Yes
- Tracking: No

**Identifiers**
- User ID (Cognito)
- Used for: App Functionality
- Linked to user: Yes
- Tracking: No

**Contact Info**
- Email address
- Used for: App Functionality, Account creation
- Linked to user: Yes
- Tracking: No

**Usage Data**
- Product interaction
- Used for: Analytics
- Linked to user: No
- Tracking: No

### Data NOT Collected
- Financial information
- Location
- Contacts
- Browsing history
- Search history
- Sensitive information (medication data stays on-device)
- Diagnostics

---

## App Review Notes

Paste this in the "Notes" field when submitting:

```
MemoryAisle is a nutrition planning app for people taking GLP-1 medications (like Ozempic, Wegovy, Mounjaro). It does NOT provide medical advice, diagnose conditions, or recommend medication changes.

IMPORTANT CONTEXT FOR REVIEW:
- This is a meal planning app, not a medical device
- The app never recommends starting, stopping, or changing medication
- All nutrition screens include a medical disclaimer
- The AI assistant (Mira) always defers to "talk to your prescriber" for medical questions
- Medication data is stored on-device only and never sent to our servers
- The app uses HealthKit read-only (weight, body composition) to personalize nutrition targets

DEMO ACCOUNT:
Reviewer credentials are entered directly in App Store Connect under
App Review → App Information → Sign-In required. They are intentionally
not stored in this repository.

SUBSCRIPTION:
$49.99/year via StoreKit 2. Free tier includes basic features. Pro unlocks unlimited meal plans, barcode scans, and provider reports.

THIRD-PARTY SERVICES:
- Amazon Cognito (authentication)
- Amazon Bedrock / Claude AI (meal generation - receives anonymized context only, never medication brand names or user identity)
- OpenFoodFacts API (barcode nutrition lookup - anonymous, no user data sent)
- Apple HealthKit (read-only, weight and body composition)

For questions: kevin@sltrdigital.com
```

---

## Pre-Submission Checklist

- [ ] App icon (1024x1024) in Assets.xcassets
- [ ] Launch screen configured
- [ ] All required device sizes tested (iPhone 15 Pro, iPhone SE, iPad)
- [ ] Screenshots for 6.7" (iPhone 15 Pro Max) and 6.1" (iPhone 15 Pro)
- [ ] Screenshots for 5.5" if supporting older devices
- [ ] Privacy policy URL live at memoryaisle.app/privacy
- [ ] Terms of service URL live at memoryaisle.app/terms
- [ ] Support URL live at memoryaisle.app/support
- [ ] Demo account created (appreview@memoryaisle.app)
- [ ] Medical disclaimer visible on nutrition screens
- [ ] HealthKit usage description in Info.plist
- [ ] Camera usage description in Info.plist (barcode scanner)
- [ ] Microphone usage description in Info.plist (voice input)
- [ ] Speech recognition usage description in Info.plist
- [ ] StoreKit 2 products configured in App Store Connect
- [ ] Archive builds without warnings
- [ ] Tested on physical device
