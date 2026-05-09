import SwiftUI

extension CarDetailView {
    var defaultExpiryDate: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    var shouldShowWOFRegistrationSection: Bool {
        car.wofExpiryDate != nil || car.registrationExpiryDate != nil
    }

    func startEditing() {
        if let updated = store.cars.first(where: { $0.id == car.id }) {
            car = updated
        }
    }

    func finishEditing() {
        store.updateCar(car)
    }

    func bump(by amount: Int) {
        car.expiryOdometer += amount
        store.updateCar(car)
    }
}
