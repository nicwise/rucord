import SwiftUI

extension CarDetailView {
    var summarySection: some View {
        Section("Summary") {
            HStack {
                Text("Plate")
                Spacer()
                if editing {
                    TextField("Plate", text: $car.plate)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 120)
                } else {
                    Text(car.plate)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Latest odo")
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

            if car.distanceRemaining == 0 {
                Text("RUC expired")
                    .foregroundStyle(.red)
            } else if let date = car.projectedExpiryDate,
                      let days = car.projectedDaysRemaining {
                HStack {
                    Text("Est. days left")
                    Spacer()
                    Text("~\(Int(days))")
                }
                HStack {
                    Text("Est. date")
                    Spacer()
                    Text(date, style: .date)
                }
            } else {
                HStack {
                    Text("Distance left")
                    Spacer()
                    Text("\(car.distanceRemaining) km")
                }
            }
        }
    }

    var carColourSection: some View {
        Section("Car Colour") {
            ColorPicker(
                "Colour",
                selection: Binding(
                    get: { car.displayColour },
                    set: { car.colourHex = $0.hexString ?? car.colourHex }
                ),
                supportsOpacity: false
            )
        }
    }

    var rucSettingsSection: some View {
        Section("RUC settings") {
            HStack {
                Text("Expiry odometer")
                Spacer()
                if editing {
                    TextField(
                        "Expiry",
                        value: $car.expiryOdometer,
                        formatter: NumberFormatter()
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 120)
                } else {
                    Text("\(car.expiryOdometer) km")
                        .foregroundStyle(.secondary)
                }
            }

            if !editing {
                HStack {
                    Text("Quick add")
                    Spacer()
                    Menu {
                        Button("+1,000 km") { bump(by: 1000) }
                        Button("+2,000 km") { bump(by: 2000) }
                        Button("+5,000 km") { bump(by: 5000) }
                        Button("+10,000 km") { bump(by: 10000) }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
    }

    var wofRegistrationEditingSection: some View {
        Section("WOF and Registration") {
            HStack {
                Text("WOF expires")
                Spacer()
                if let wofDate = car.wofExpiryDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { wofDate },
                            set: {
                                car.wofExpiryDate = $0
                                car.wofBooked = nil
                            }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                } else {
                    Button("Set WOF date") {
                        car.wofExpiryDate = defaultExpiryDate
                        car.wofBooked = nil
                    }
                }
            }

            if car.wofExpiryDate != nil {
                HStack {
                    Button("Clear WOF date") {
                        car.wofExpiryDate = nil
                        car.wofBooked = nil
                    }
                    .foregroundStyle(.red)
                    Spacer()
                }
            }

            HStack {
                Text("Registration expires")
                Spacer()
                if let regDate = car.registrationExpiryDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { regDate },
                            set: { car.registrationExpiryDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                } else {
                    Button("Set Registration date") {
                        car.registrationExpiryDate = defaultExpiryDate
                    }
                }
            }

            if car.registrationExpiryDate != nil {
                HStack {
                    Button("Clear Registration date") {
                        car.registrationExpiryDate = nil
                    }
                    .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
    }

    var wofRegistrationStatusSection: some View {
        Section("WOF and Registration") {
            if let wofDate = car.wofExpiryDate {
                HStack {
                    Text("WOF expires")
                    Spacer()
                    Text(wofDate, style: .date)
                        .foregroundStyle(car.wofDueSoon ? .red : .secondary)
                    if car.wofDueSoon,
                       (car.wofBooked ?? false) == false || (car.wofDaysRemaining ?? 0) < 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let days = car.wofDaysRemaining {
                    HStack {
                        Text("Days until WOF due")
                        Spacer()
                        Text("\(days)")
                            .foregroundStyle(days <= 42 ? .red : .secondary)
                    }
                }

                if let days = car.wofDaysRemaining, days <= 30 {
                    Toggle(
                        "WOF booked",
                        isOn: Binding(
                            get: { car.wofBooked ?? false },
                            set: {
                                car.wofBooked = $0
                                store.updateCar(car)
                            }
                        )
                    )
                }
            }

            if let regDate = car.registrationExpiryDate {
                HStack {
                    Text("Registration expires")
                    Spacer()
                    Text(regDate, style: .date)
                        .foregroundStyle(car.registrationDueSoon ? .red : .secondary)
                    if car.registrationDueSoon {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let days = car.registrationDaysRemaining {
                    HStack {
                        Text("Days until Registration due")
                        Spacer()
                        Text("\(days)")
                            .foregroundStyle(days <= 42 ? .red : .secondary)
                    }
                }
            }
        }
    }

    var historySection: some View {
        Section("History") {
            if car.entries.isEmpty {
                Text("No readings yet")
                    .foregroundStyle(.secondary)
            } else {
                let sortedEntries = car.entries.sorted { $0.date > $1.date }
                let visibleEntries = showAllHistory
                    ? sortedEntries
                    : Array(sortedEntries.prefix(3))

                ForEach(visibleEntries) { entry in
                    HStack {
                        Text(entry.date, style: .date)
                        Spacer()
                        Text("\(entry.value) km")
                            .foregroundStyle(.secondary)
                    }
                }

                if sortedEntries.count > 3 {
                    Button(showAllHistory ? "Show less" : "Show all") {
                        withAnimation {
                            showAllHistory.toggle()
                        }
                    }
                }
            }
        }
    }

    var dangerZoneSection: some View {
        Section("Danger Zone") {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete Car", systemImage: "trash")
            }
            .foregroundStyle(.red)
        }
    }
}
