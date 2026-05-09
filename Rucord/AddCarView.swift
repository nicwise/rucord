import SwiftUI

struct AddCarView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: CarStore
    @State private var plate: String = ""
    @State private var expiryOdo: String = ""
    @State private var initialOdo: String = ""
    @State private var initialDate: Date = Date()
    @State private var carColour: Color = .blue
    @State private var wofExpiryDate: Date?
    @State private var registrationExpiryDate: Date?
    @FocusState private var plateFieldFocused: Bool

    private var defaultExpiryDate: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    private var colourSection: some View {
        Section("Car Colour") {
            ColorPicker("Colour", selection: $carColour, supportsOpacity: false)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Plate", text: $plate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($plateFieldFocused)
                    TextField("RUC expiry odometer", text: $expiryOdo)
                        .keyboardType(.numberPad)
                    TextField("Current odometer", text: $initialOdo)
                        .keyboardType(.numberPad)
                    DatePicker(
                        "Initial reading date",
                        selection: $initialDate,
                        displayedComponents: .date
                    )
                }

                colourSection

                Section("WOF and Registration") {
                    HStack {
                        Text("WOF expires")
                        Spacer()
                        if let wofDate = wofExpiryDate {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { wofDate },
                                    set: { wofExpiryDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        } else {
                            Button("Set WOF date") {
                                wofExpiryDate = defaultExpiryDate
                            }
                        }
                    }

                    if wofExpiryDate != nil {
                        HStack {
                            Button("Clear WOF date") {
                                wofExpiryDate = nil
                            }
                            .foregroundStyle(.red)
                            Spacer()
                        }
                    }

                    HStack {
                        Text("Registration expires")
                        Spacer()
                        if let regDate = registrationExpiryDate {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { regDate },
                                    set: { registrationExpiryDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        } else {
                            Button("Set Registration date") {
                                registrationExpiryDate = defaultExpiryDate
                            }
                        }
                    }

                    if registrationExpiryDate != nil {
                        HStack {
                            Button("Clear Registration date") {
                                registrationExpiryDate = nil
                            }
                            .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Car")
            .onAppear {
                plateFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        guard !plate.trimmingCharacters(in: .whitespaces).isEmpty,
              let expiry = Int(expiryOdo), expiry > 0,
              let initial = Int(initialOdo), initial >= 0,
              initial < expiry else {
            return false
        }
        return true
    }

    private func save() {
        guard let expiry = Int(expiryOdo),
              let start = Int(initialOdo) else {
            return
        }

        let first = OdometerEntry(date: initialDate, value: start)
        let car = Car(
            plate: plate,
            expiryOdometer: expiry,
            entries: [first],
            colourHex: carColour.hexString ?? "#3B82F6",
            wofExpiryDate: wofExpiryDate,
            registrationExpiryDate: registrationExpiryDate
        )

        store.addCar(car)
        dismiss()
    }
}
