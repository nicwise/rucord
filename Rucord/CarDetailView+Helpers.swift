import SwiftUI

extension CarDetailView {
    var defaultExpiryDate: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    var purchaseRUCURL: URL {
        NZTAURLs.purchaseRUC(for: car.plate)
    }

    var shouldShowBuyRUCSection: Bool {
        car.distanceRemaining == 0 || (car.projectedDaysRemaining ?? .infinity) < 30
    }

    var shouldShowWOFRegistrationSection: Bool {
        car.wofExpiryDate != nil || car.registrationExpiryDate != nil
    }

    var existingImage: UIImage? {
        guard let imageName = car.imageName else { return nil }
        return store.loadCarImage(named: imageName)
    }

    var hasPendingImage: Bool {
        pendingCarImage?.size.width ?? 0 > 0
    }

    var hasImage: Bool {
        hasPendingImage || (pendingCarImage == nil && existingImage != nil)
    }

    var displayImage: UIImage? {
        if hasPendingImage {
            return pendingCarImage
        }
        if pendingCarImage == nil {
            return existingImage
        }
        return nil
    }

    var canAdd: Bool {
        guard let odometerValue = Int(newOdo) else { return false }
        return odometerValue > car.latestOdometer
    }

    func startEditing() {
        if let updated = store.cars.first(where: { $0.id == car.id }) {
            car = updated
        }
        pendingCarImage = nil
        selectedImage = nil
    }

    func finishEditing() {
        if let newImage = pendingCarImage {
            if newImage.size.width > 0 {
                store.updateCarImage(car, with: newImage)
            } else {
                store.updateCarImage(car, with: nil)
            }

            if let updated = store.cars.first(where: { $0.id == car.id }) {
                car = updated
            }
        }

        store.updateCar(car)
        pendingCarImage = nil
        selectedImage = nil
    }

    func addReading() {
        guard let odometerValue = Int(newOdo) else { return }
        let entry = OdometerEntry(date: newDate, value: odometerValue)
        store.addEntry(entry, to: car)
        newOdo = ""
        newDate = Date()
    }

    func bump(by amount: Int) {
        car.expiryOdometer += amount
        store.updateCar(car)
    }
}
