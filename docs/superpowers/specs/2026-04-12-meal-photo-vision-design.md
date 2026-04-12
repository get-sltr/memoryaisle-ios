# Meal Photo Vision Analysis

Wire up real Bedrock Claude Vision for meal photo analysis. Currently `MealPhotoView.analyzePhoto()` returns hardcoded "Grilled Chicken with Rice" regardless of what the user photographs.

## Problem

Three disconnected layers:
- `FoodAnalyzer.analyzePhoto(imageData:profile:)` builds a good prompt and parses pipe-delimited responses, but silently drops the image data
- `MiraAPIClient.send(message:context:)` has no image field in its request body
- `miraGenerate` Lambda hardcodes `content: message` as a string, blocking vision
- `MealPhotoView` never calls `FoodAnalyzer` at all -- uses a `DispatchQueue.main.asyncAfter` stub

## Design

Three layers, bottom-up. All changes are backwards-compatible with existing text-only calls.

### Layer 1: Lambda (`Infrastructure/lambda/miraGenerate/index.mjs`)

Add optional `imageBase64` (string) and `imageMediaType` (string, e.g. `image/jpeg`) to the parsed request body. When present, build a vision-capable content array for Bedrock:

```js
const content = imageBase64
  ? [
      { type: "image", source: { type: "base64", media_type: imageMediaType, data: imageBase64 } },
      { type: "text", text: message }
    ]
  : message;
```

Pass `content` into the existing Bedrock `InvokeModelCommand` body. No new Lambda, no new API Gateway route, no new IAM permissions (the existing wildcard Bedrock policy covers vision). `claude-sonnet-4-20250514` supports vision natively.

### Layer 2: MiraAPIClient (`Services/AI/MiraAPIClient.swift`)

Add two optional fields to the request:

```swift
struct MiraRequest: Codable {
    let message: String
    let context: MiraContext?
    let imageBase64: String?      // new
    let imageMediaType: String?   // new
}
```

Add a new send method or overload that accepts image data:

```swift
func send(message: String, context: MiraContext?, imageData: Data?) async throws -> MiraResponse
```

When `imageData` is provided:
1. Resize to max 1024px on longest dimension using `UIGraphicsImageRenderer`
2. JPEG compress at 0.7 quality
3. Base64-encode the compressed data
4. Set `imageMediaType` to `"image/jpeg"`

This keeps payload under ~1.4 MB (well within API Gateway's 10 MB limit).

### Layer 3: FoodAnalyzer + MealPhotoView

**FoodAnalyzer** (`Services/AI/FoodAnalyzer.swift`):
- Thread `imageData` parameter through to `MiraAPIClient.send` as base64
- The existing prompt and `parsePhotoAnalysis` response parser are already correct -- no changes needed there

**MealPhotoView** (`Features/Scan/MealPhotoView.swift`):
- Delete the hardcoded `analyzePhoto()` stub (lines 248-264)
- Delete the `MealPhotoResult` struct (lines 267-275) -- use `FoodAnalyzer.Analysis` instead
- Replace with a real async call to `FoodAnalyzer.analyzePhoto(imageData:profile:)`
- Map `FoodAnalyzer.Analysis` fields to the existing result view, or update the result view to consume `FoodAnalyzer.Analysis` directly

### Image Prep (on-device)

Before encoding, resize and compress:
1. Load `Data` into `UIImage`
2. Calculate scale factor to fit longest dimension within 1024px
3. Render via `UIGraphicsImageRenderer` at target size
4. Compress to JPEG at 0.7 quality
5. Base64-encode

This prevents raw 4-8 MB iPhone photos from hitting the wire.

### Error Handling

- Network/timeout failure: show an alert with a "Try again" button that resets to capture state
- Empty/unparseable response: show "Mira couldn't identify this meal. Try a clearer photo." with retry
- 30-second timeout (already configured on `MiraAPIClient`)

### Auth

Not in scope. The endpoint is already unauthenticated for text calls. Adding Cognito JWT auth is a separate task tracked in the App Store review audit.

## Files to Change

| File | Change |
|------|--------|
| `Infrastructure/lambda/miraGenerate/index.mjs` | Add vision content array branch |
| `MemoryAisle2/.../Services/AI/MiraAPIClient.swift` | Add image fields to request, image prep utility |
| `MemoryAisle2/.../Services/AI/FoodAnalyzer.swift` | Thread imageData through to API client |
| `MemoryAisle2/.../Features/Scan/MealPhotoView.swift` | Replace stub with real FoodAnalyzer call, delete MealPhotoResult |

## Out of Scope

- Auth on the endpoint (separate task)
- Barcode scan vision (ScanResultView uses a different pipeline via NutritionAPIClient)
- Caching/offline analysis
- Multiple photos per meal
