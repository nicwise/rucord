import SwiftUI

struct CarListView: View {
    @EnvironmentObject var store: CarStore
    @State private var showingAdd = false
    
    var body: some View {
        NavigationStack {
            Group {
                if store.cars.isEmpty {
                    ContentUnavailableView("No cars yet",
                                           systemImage: "car",
                                           description: Text("Add your first car to start tracking RUC."))
                } else {
                    List {
                        ForEach(store.cars) { car in
                            NavigationLink(value: car.id) {
                                CarRowView(car: car)
                            }
                        }
                        .onDelete(perform: store.deleteCar)
                    }
                }
            }
            .navigationTitle("RUC Buddy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add car")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCarView()
                    .environmentObject(store)
            }
            .navigationDestination(for: UUID.self) { id in
                if let car = store.cars.first(where: { $0.id == id }) {
                    CarDetailView(car: car)
                        .environmentObject(store)
                }
            }
        }
    }
}

struct CarRowView: View {
    let car: Car
    
    private let kmDueSoonThreshold = 500
    private let daysDueSoonThreshold = 7.0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(car.plate)
                    .font(.headline)
                Text("Odo: \(car.latestOdometer.formatted()) km")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if car.distanceRemaining == 0 {
                    Label("RUC expired", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if let date = car.projectedExpiryDate, let days = car.projectedDaysRemaining {
                    let dueSoon = days <= daysDueSoonThreshold
                    Text("~\(Int(days).formatted()) days")
                        .font(.subheadline)
                        .foregroundStyle(dueSoon ? .orange : .secondary)
                    Text(date, style: .date)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    let dueSoon = car.distanceRemaining <= kmDueSoonThreshold
                    Text("\(car.distanceRemaining.formatted()) km left")
                        .font(.subheadline)
                        .foregroundStyle(dueSoon ? .orange : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCarView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: CarStore
    @State private var plate: String = ""
    @State private var expiryOdo: String = ""
    @State private var initialOdo: String = ""
    @State private var initialDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Car") {
                    TextField("Number plate (e.g. ABC123)", text: $plate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("Initial reading") {
                    TextField("Odometer km", text: $initialOdo)
                        .keyboardType(.numberPad)
                    DatePicker("Date", selection: $initialDate, displayedComponents: .date)
                }
                Section("RUC") {
                    TextField("Expiry odometer (km)", text: $expiryOdo)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Car")
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
              initial < expiry
        else { return false }
        return true
    }
    
    private func save() {
        guard let expiry = Int(expiryOdo), let start = Int(initialOdo) else { return }
        let first = OdometerEntry(date: initialDate, value: start)
        let car = Car(plate: plate, expiryOdometer: expiry, entries: [first])
        store.addCar(car)
        dismiss()
    }
}

struct CarDetailView: View {
    @EnvironmentObject var store: CarStore
    @State var car: Car
    @State private var newOdo: String = ""
    @State private var newDate: Date = Date()
    @State private var editing = false
    @State private var showRUCQuick = false
    @State private var showAllHistory = false
    
    var body: some View {
        Form {
            Section("Summary") {
                HStack { Text("Plate"); Spacer(); Text(car.plate).foregroundStyle(.secondary) }
                HStack { Text("Latest odo"); Spacer(); Text("\(car.latestOdometer) km").foregroundStyle(.secondary) }
                HStack { Text("RUC expires at"); Spacer(); Text("\(car.expiryOdometer) km").foregroundStyle(.secondary) }
                if car.distanceRemaining == 0 {
                    Text("RUC expired").foregroundStyle(.red)
                } else if let date = car.projectedExpiryDate, let days = car.projectedDaysRemaining {
                    HStack { Text("Est. days left"); Spacer(); Text("~\(Int(days))") }
                    HStack { Text("Est. date"); Spacer(); Text(date, style: .date) }
                } else {
                    HStack { Text("Distance left"); Spacer(); Text("\(car.distanceRemaining) km") }
                }
            }
            
            Section("Add reading") {
                TextField("Odometer km", text: $newOdo)
                    .keyboardType(.numberPad)
                DatePicker("Date", selection: $newDate, displayedComponents: .date)
                Button("Add reading") { addReading() }
                    .disabled(!canAdd)
            }
            
            Section("RUC settings") {
                HStack {
                    Text("Expiry odometer")
                    Spacer()
                    if editing {
                        TextField("Expiry", value: $car.expiryOdometer, formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 120)
                    } else {
                        Text("\(car.expiryOdometer) km").foregroundStyle(.secondary)
                    }
                }
                if !editing {
                    HStack {
                        Text("Quick bump")
                        Spacer()
                        Menu {
                            Button("+1,000 km") { bump(by: 1000) }
                            Button("+5,000 km") { bump(by: 5000) }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
            
            Section("History") {
                if car.entries.isEmpty {
                    Text("No readings yet").foregroundStyle(.secondary)
                } else {
                    let sorted = car.entries.sorted { $0.date > $1.date }
                    let visible = showAllHistory ? sorted : Array(sorted.prefix(3))
                    ForEach(visible) { entry in
                        HStack {
                            Text(entry.date, style: .date)
                            Spacer()
                            Text("\(entry.value) km")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if sorted.count > 3 {
                        Button(showAllHistory ? "Show less" : "Show all") {
                            withAnimation { showAllHistory.toggle() }
                        }
                    }
                }
            }
        }
        .navigationTitle(car.plate)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "Done" : "Edit") {
                    if editing { store.updateCar(car) }
                    withAnimation { editing.toggle() }
                }
            }
        }
        .onChange(of: store.cars) { _, new in
            if let updated = new.first(where: { $0.id == car.id }) { car = updated }
        }
    }
    
    private var canAdd: Bool {
        guard let v = Int(newOdo) else { return false }
        return v > (car.latestOdometer)
    }
    
    private func addReading() {
        guard let v = Int(newOdo) else { return }
        let entry = OdometerEntry(date: newDate, value: v)
        store.addEntry(entry, to: car)
        newOdo = ""
        newDate = Date()
    }
    
    private func bump(by amount: Int) {
        car.expiryOdometer += amount
        store.updateCar(car)
    }
}

#Preview {
    CarListView()
        .environmentObject(CarStore())
}
