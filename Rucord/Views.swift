import SwiftUI
import StoreKit

struct CarListView: View {
    @EnvironmentObject var store: CarStore
    @State private var showingAdd = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            Group {
                if store.cars.isEmpty {
                    ContentUnavailableView("No cars yet",
                                           systemImage: "car",
                                           description: Text("Add your first car to start tracking RUC."))
                } else {
                    ScrollView {
                        
                            LazyVStack(spacing: 16) {
                                ForEach(store.cars) { car in
                                    NavigationLink(value: car.id) {
                                        CarRowView(car: car)
                                            .environmentObject(store)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(systemName: "car")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
    @EnvironmentObject var store: CarStore
    @State private var showingUpdateOdo = false
    @State private var newOdo: String = ""
    @State private var newDate: Date = Date()
    
    private let kmDueSoonThreshold = 500
    private let daysDueSoonThreshold = 7.0
    
    var body: some View {
        VStack(spacing: 12) {
                // License plate and days info
                HStack {
                    Text(car.plate)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if car.distanceRemaining == 0 {
                        Text("EXPIRED")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                    } else if let days = car.projectedDaysRemaining {
                        let dueSoon = days <= daysDueSoonThreshold
                        Text("~\(Int(days)) days")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(dueSoon ? .orange : .orange)
                    }
                }
                
                // Odometer and date
                HStack {
                    Text("Odo: \(car.latestOdometer.formatted()) km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let date = car.projectedExpiryDate {
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let latest = car.latestEntry {
                        Text(latest.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Update Odometer Button
                Button(action: { showingUpdateOdo = true }) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                        Text("Update Odometer")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .font(.headline)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingUpdateOdo) {
            UpdateOdometerView(car: car)
                .environmentObject(store)
        }
    }
}

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
        guard let v = Int(newOdo) else { return false }
        return v > car.latestOdometer
    }
    
    private func addReading() {
        guard let v = Int(newOdo) else { return }
        let entry = OdometerEntry(date: newDate, value: v)
        store.addEntry(entry, to: car)
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
                        Text(car.plate).foregroundStyle(.secondary)
                    }
                }
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

enum TipJar: String, CaseIterable {
    case coffee = "com.nicwise.rucord.tip.coffee"
    case lunch = "com.nicwise.rucord.tip.lunch"
    case dinner = "com.nicwise.rucord.tip.dinner"
    
    var name: String {
        switch self {
        case .coffee: return "Buy me a coffee"
        case .lunch: return "Buy me lunch"
        case .dinner: return "Buy me dinner"
        }
    }
    
    var emoji: String {
        switch self {
        case .coffee: return "☕️"
        case .lunch: return "🥪"
        case .dinner: return "🍽️"
        }
    }
    
    static func fetchProducts() async -> [Self: Product] {
        do {
            let productIDs = Self.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIDs)
            var results: [Self: Product] = [:]
            for product in products {
                if let tip = TipJar(rawValue: product.id) {
                    results[tip] = product
                }
            }
            return results
        } catch {
            print("Error fetching products: \(error)")
            return [:]
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let purchaseResult = try await product.purchase()
            switch purchaseResult {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    await transaction.finish()
                    return true
                default:
                    return false
                }
            default:
                return false
            }
        } catch {
            print("Purchase error: \(error)")
            return false
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tipProducts: [TipJar: Product] = [:]
    @State private var productsFetched = false
    @State private var pendingPurchase: TipJar? = nil
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    HStack {
                        Image(systemName: "car.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rucord")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("RUC tracking made simple")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text("Created by")
                        Spacer()
                        Text("Nic Wise and Amp")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link("Rucord website", destination: URL(string: "https://fastchicken.co.nz/rucord")!)
                        .foregroundStyle(.blue)
                    
                    Link("Ampcode - Agentic Coding", destination: URL(string: "https://ampcode.com")!)
                        .foregroundStyle(.blue)
                }
                
                Section("Support Development") {
                    ForEach(TipJar.allCases, id: \.self) { tip in
                        Button(action: {
                            purchaseTip(tip)
                        }) {
                            HStack {
                                Text("\(tip.name) \(tip.emoji)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if let product = tipProducts[tip] {
                                    if pendingPurchase == tip {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(product.displayPrice)
                                            .foregroundStyle(.blue)
                                    }
                                } else {
                                    if productsFetched {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                        }
                        .disabled(tipProducts[tip] == nil || pendingPurchase != nil)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                let products = await TipJar.fetchProducts()
                await MainActor.run {
                    withAnimation {
                        self.tipProducts = products
                        self.productsFetched = true
                    }
                }
            }
            .alert("Thank you!", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Thanks for supporting Rucord!")
            }
        }
    }
    
    private func purchaseTip(_ tip: TipJar) {
        guard pendingPurchase == nil, let product = tipProducts[tip] else { return }
        
        withAnimation {
            pendingPurchase = tip
        }
        
        Task {
            let success = await tip.purchase(product)
            await MainActor.run {
                withAnimation {
                    if success {
                        showingSuccessAlert = true
                    }
                    pendingPurchase = nil
                }
            }
        }
    }
}

#Preview {
    CarListView()
        .environmentObject(CarStore())
}
