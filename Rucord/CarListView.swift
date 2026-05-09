import SwiftUI

struct CarListView: View {
    @EnvironmentObject var store: CarStore
    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var selectedCarId: UUID?

    private var selectedCar: Car? {
        if let selectedCarId,
           let car = store.cars.first(where: { $0.id == selectedCarId }) {
            return car
        }
        return store.cars.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cars.isEmpty {
                    ContentUnavailableView(
                        "No cars yet",
                        systemImage: "car",
                        description: Text("Add your first car to start tracking RUC.")
                    )
                } else if let selectedCar {
                    FocusedCarView(carId: selectedCar.id)
                        .environmentObject(store)
                } else {
                    EmptyView()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if store.cars.isEmpty {
                        Image(systemName: "car")
                            .font(.title2)
                            .fontWeight(.medium)
                    } else {
                        Menu {
                            ForEach(store.cars) { car in
                                Button {
                                    selectedCarId = car.id
                                } label: {
                                    if car.id == selectedCar?.id {
                                        Label(car.plate, systemImage: "checkmark")
                                    } else {
                                        Text(car.plate)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("My Garage")
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.primary)
                        }
                        .accessibilityLabel("Select car")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(
                        action: { showingSettings = true },
                        label: {
                            Image(systemName: "gearshape")
                        }
                    )
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        action: { showingAdd = true },
                        label: {
                            Image(systemName: "plus")
                        }
                    )
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
            .onAppear {
                syncSelectedCar()
            }
            .onChange(of: store.cars) { _, _ in
                syncSelectedCar()
            }
        }
    }

    private func syncSelectedCar() {
        guard !store.cars.isEmpty else {
            selectedCarId = nil
            return
        }

        if let selectedCarId,
           store.cars.contains(where: { $0.id == selectedCarId }) {
            return
        }

        selectedCarId = store.cars.first?.id
    }
}

struct FocusedCarView: View {
    let carId: UUID
    @EnvironmentObject var store: CarStore
    @State private var showingUpdateOdo = false

    private let daysDueSoonThreshold = 7.0

    private var car: Car {
        store.cars.first(where: { $0.id == carId }) ?? Car(plate: "ERROR", expiryOdometer: 0)
    }

    private var purchaseRUCURL: URL {
        NZTAURLs.purchaseRUC(for: car.plate)
    }

    private var shouldShowPurchaseRUCLink: Bool {
        car.distanceRemaining == 0 || (car.projectedDaysRemaining ?? .infinity) < 30
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                primaryMetric
                expiryMetricsGrid
                actionLinks
                metricsGrid
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .safeAreaPadding(.horizontal, 16)
        .sheet(isPresented: $showingUpdateOdo) {
            UpdateOdometerView(car: car)
                .environmentObject(store)
        }
    }

    private var hero: some View {
        NavigationLink(value: car.id) {
            ZStack(alignment: .bottomLeading) {
                car.displayColour
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.18), .black.opacity(0.28)]),
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                )

                Image(systemName: "car.side.fill")
                    .font(.system(size: 108, weight: .regular))
                    .foregroundStyle(.white.opacity(0.28))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(car.plate)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("View details")
                        .font(.subheadline)
                }
                .foregroundStyle(.white)
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.primary.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View details for \(car.plate)")
    }

    private var primaryMetric: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RUC remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(car.distanceRemaining.formatted()) km")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(car.distanceRemaining == 0 ? .red : .primary)
                }

                Spacer()

                Button(
                    action: { showingUpdateOdo = true },
                    label: {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.title3)
                    }
                )
                .buttonStyle(.bordered)
                .accessibilityLabel("Update odometer")
            }

            if car.distanceRemaining == 0 {
                Text("RUC expired")
                    .font(.headline)
                    .foregroundStyle(.red)
            } else if let days = car.projectedDaysRemaining,
                      let date = car.projectedExpiryDate {
                let formattedDate = date.formatted(date: .abbreviated, time: .omitted)
                Text("About \(Int(days)) \(dayLabel(for: days)), estimated \(formattedDate)")
                    .font(.subheadline)
                    .foregroundStyle(days <= daysDueSoonThreshold ? .orange : .secondary)
            } else {
                Text("Add another odometer reading to estimate when your RUC will run out.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(title: "Odometer", value: "\(car.latestOdometer.formatted()) km")
            metricCard(title: "RUC expires", value: "\(car.expiryOdometer.formatted()) km")
        }
    }

    @ViewBuilder
    private var expiryMetricsGrid: some View {
        if car.wofExpiryDate != nil || car.registrationExpiryDate != nil {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let wofDate = car.wofExpiryDate {
                    metricCard(
                        title: "WOF",
                        value: wofDate.formatted(date: .abbreviated, time: .omitted),
                        detail: expiryDetail(days: car.wofDaysRemaining),
                        showsWarning: car.wofDueWithin2Months
                            && ((car.wofBooked ?? false) == false || (car.wofDaysRemaining ?? 0) < 0)
                    )
                }

                if let registrationDate = car.registrationExpiryDate {
                    metricCard(
                        title: "Registration",
                        value: registrationDate.formatted(date: .abbreviated, time: .omitted),
                        detail: expiryDetail(days: car.registrationDaysRemaining),
                        showsWarning: car.registrationDueWithin2Months
                    )
                }
            }
        }
    }

    private func metricCard(
        title: String,
        value: String,
        detail: String? = nil,
        showsWarning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showsWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Text(value)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func dayLabel(for days: Double) -> String {
        Int(days) == 1 ? "day" : "days"
    }

    private func expiryDetail(days: Int?) -> String? {
        guard let days, days <= 60 else { return nil }
        return "Expires in \(days) \(days == 1 ? "day" : "days")"
    }

    @ViewBuilder
    private var actionLinks: some View {
        if shouldShowPurchaseRUCLink || car.registrationDueSoon {
            VStack(alignment: .leading, spacing: 12) {
                if shouldShowPurchaseRUCLink {
                    Link(destination: purchaseRUCURL) {
                        Label("Buy RUC from NZTA", systemImage: "link.circle.fill")
                    }
                    .accessibilityLabel("Open NZTA purchase RUC website")
                }

                if car.registrationDueSoon {
                    Link(destination: NZTAURLs.registrationRenewal) {
                        Label("Renew registration with NZTA", systemImage: "safari")
                    }
                    .accessibilityLabel("Open NZTA registration renewal website in Safari")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
