import SwiftUI

/// Shown when a barcode lookup either returns no record OR returns a
/// record without enough serving data to honestly compute per-serving
/// macros. The user types the values from the package label and we treat
/// what they enter as the source of truth — because the bag is.
///
/// Fields default-empty for new entries; `prefilledName` and
/// `prefilledBrand` populate the top section when Open Food Facts at
/// least gave us a product identity but lacked serving info.
struct ManualNutritionEntrySheet: View {
    let prefilledName: String
    let prefilledBrand: String
    let onSave: (NutritionData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var brand: String
    @State private var servingSize: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var fiber: String = ""

    init(
        prefilledName: String = "",
        prefilledBrand: String = "",
        onSave: @escaping (NutritionData) -> Void
    ) {
        self.prefilledName = prefilledName
        self.prefilledBrand = prefilledBrand
        self.onSave = onSave
        _name = State(initialValue: prefilledName)
        _brand = State(initialValue: prefilledBrand)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(calories.trimmingCharacters(in: .whitespaces)) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter what's on the package label. The bag is the source of truth — these values become the entry exactly as you type them.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Section("Product") {
                    TextField("Product name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Brand", text: $brand)
                        .textInputAutocapitalization(.words)
                    TextField("Serving size (e.g. 1 bag, 40g)", text: $servingSize)
                }

                Section("Per serving") {
                    LabeledContent("Calories") {
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Protein (g)") {
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Carbs (g)") {
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Fat (g)") {
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Fiber (g)") {
                        TextField("0", text: $fiber)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Enter from label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: handleSave)
                        .disabled(!canSave)
                        .accessibilityLabel("Save entry")
                }
            }
        }
    }

    private func handleSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let trimmedServing = servingSize.trimmingCharacters(in: .whitespaces)

        let nutrition = NutritionData(
            name: trimmedName.isEmpty ? "Unknown product" : trimmedName,
            brand: trimmedBrand.isEmpty ? "Unknown brand" : trimmedBrand,
            servingSize: trimmedServing.isEmpty ? "1 serving" : trimmedServing,
            calories: Int(calories.trimmingCharacters(in: .whitespaces)) ?? 0,
            protein: Double(protein.trimmingCharacters(in: .whitespaces)) ?? 0,
            fat: Double(fat.trimmingCharacters(in: .whitespaces)) ?? 0,
            carbs: Double(carbs.trimmingCharacters(in: .whitespaces)) ?? 0,
            fiber: Double(fiber.trimmingCharacters(in: .whitespaces)) ?? 0,
            sodium: 0,
            sugar: 0
        )
        HapticManager.success()
        onSave(nutrition)
        dismiss()
    }
}
