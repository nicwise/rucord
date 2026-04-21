import SwiftUI

struct CarListView: View {
    @EnvironmentObject var store: CarStore
    @State private var showingAdd = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.cars.isEmpty {
                    ContentUnavailableView(
                        "No cars yet",
                        systemImage: "car",
                        description: Text("Add your first car to start tracking RUC.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(store.cars) { car in
                                NavigationLink(value: car.id) {
                                    CarRowView(carId: car.id)
                                        .environmentObject(store)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 8)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
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
        }
    }
}

struct CarRowView: View {
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
        VStack(spacing: 12) {
            if let imageName = car.imageName,
               let image = store.loadCarImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 12) {
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
                    } else if let days = car.projectedDaysRemaining, days <= 60 {
                        let dueSoon = days <= daysDueSoonThreshold
                        Text("about \(Int(days)) days")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(dueSoon ? .orange : .secondary)
                    }

                    Button(
                        action: { showingUpdateOdo = true },
                        label: {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    )
                    .buttonStyle(.plain)
                }

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

                if car.wofDueWithin2Months || car.registrationDueWithin2Months {
                    VStack(alignment: .leading, spacing: 4) {
                        if car.wofDueWithin2Months,
                           let wofDate = car.wofExpiryDate,
                           let days = car.wofDaysRemaining {
                            HStack {
                                if (car.wofBooked ?? false) == false || days < 0 {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                                Text("WOF expires \(wofDate, style: .date) (\(days) days)")
                                    .font(.caption)
                                    .foregroundStyle(days <= 14 ? .red : .orange)
                                Spacer()
                            }
                        }

                        if car.registrationDueWithin2Months,
                           let regDate = car.registrationExpiryDate,
                           let days = car.registrationDaysRemaining {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text(
                                    "Registration expires \(regDate, style: .date) (\(days) days)"
                                )
                                .font(.caption)
                                .foregroundStyle(days <= 14 ? .red : .orange)
                                Spacer()
                            }
                        }

                        if car.registrationDueSoon {
                            HStack {
                                Link(destination: NZTAURLs.registrationRenewal) {
                                    Label(
                                        "Renew registration with NZTA",
                                        systemImage: "safari"
                                    )
                                    .font(.caption)
                                }
                                .foregroundStyle(.blue)
                                .accessibilityLabel(
                                    "Open NZTA registration renewal website in Safari"
                                )
                                Spacer()
                            }
                        }
                    }
                }

                if shouldShowPurchaseRUCLink {
                    HStack {
                        Link(destination: purchaseRUCURL) {
                            Label("Buy RUC from NZTA", systemImage: "link.circle.fill")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Open NZTA purchase RUC website")
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, car.imageName != nil ? 16 : 0)
            .padding(.vertical, car.imageName != nil ? 16 : 0)
        }
        .padding(.horizontal, car.imageName != nil ? 0 : 16)
        .padding(.vertical, car.imageName != nil ? 0 : 16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: car.imageName != nil ? 12 : 8))
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingUpdateOdo) {
            UpdateOdometerView(car: car)
                .environmentObject(store)
        }
    }
}
