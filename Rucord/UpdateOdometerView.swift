import SwiftUI

struct UpdateOdometerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: CarStore
    let car: Car
    @State private var newOdo: String = ""
    @State private var newDate: Date = Date()
    @FocusState private var odometerFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Update Odometer") {
                    TextField("Current odometer (km)", text: $newOdo)
                        .keyboardType(.numberPad)
                        .focused($odometerFieldFocused)
                    DatePicker("Date", selection: $newDate, displayedComponents: .date)
                }

                Section("Quick Options") {
                    Button("Quick +100 km") {
                        newOdo = String(car.latestOdometer + 100)
                    }
                    Button("Quick +500 km") {
                        newOdo = String(car.latestOdometer + 500)
                    }
                    Button("Quick +1000 km") {
                        newOdo = String(car.latestOdometer + 1000)
                    }
                }

                Section("Current Status") {
                    HStack {
                        Text("Last reading")
                        Spacer()
                        Text("\(car.latestOdometer) km")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("RUC expires at")
                        Spacer()
                        Text("\(car.expiryOdometer) km")
                            .foregroundStyle(.secondary)
                    }
                    if car.distanceRemaining > 0 {
                        HStack {
                            Text("Distance remaining")
                            Spacer()
                            Text("\(car.distanceRemaining) km")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("RUC EXPIRED")
                                .foregroundStyle(.red)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Update \(car.plate)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                odometerFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addReading()
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var canAdd: Bool {
        guard let odometerValue = Int(newOdo) else { return false }
        return odometerValue > car.latestOdometer
    }

    private func addReading() {
        guard let odometerValue = Int(newOdo) else { return }
        let entry = OdometerEntry(date: newDate, value: odometerValue)
        store.addEntry(entry, to: car)
    }
}
