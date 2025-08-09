import Foundation
import Combine

final class CarStore: ObservableObject {
    @Published var cars: [Car] = [] {
        didSet { save() }
    }
    
    private let fileName = "cars.json"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        load()
    }
    
    func addCar(_ car: Car) {
        cars.append(car)
        sort()
    }
    
    func updateCar(_ car: Car) {
        if let idx = cars.firstIndex(where: { $0.id == car.id }) {
            cars[idx] = car
            sort()
        }
    }
    
    func deleteCar(at offsets: IndexSet) {
        cars.remove(atOffsets: offsets)
    }
    
    func addEntry(_ entry: OdometerEntry, to car: Car) {
        guard let idx = cars.firstIndex(where: { $0.id == car.id }) else { return }
        var updated = cars[idx]
        updated.entries.append(entry)
        updated.entries.sort { $0.date < $1.date }
        cars[idx] = updated
    }
    
    private func sort() {
        cars.sort { a, b in
            let aExpired = a.distanceRemaining == 0
            let bExpired = b.distanceRemaining == 0
            if aExpired != bExpired { return aExpired && !bExpired }
            
            let aDays = a.projectedDaysRemaining ?? Double.infinity
            let bDays = b.projectedDaysRemaining ?? Double.infinity
            if aDays != bDays { return aDays < bDays }
            
            if a.distanceRemaining != b.distanceRemaining {
                return a.distanceRemaining < b.distanceRemaining
            }
            return a.plate < b.plate
        }
    }
    
    // MARK: Persistence
    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func fileURL() -> URL { documentsURL().appendingPathComponent(fileName) }
    
    private func load() {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.cars = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Car].self, from: data)
            self.cars = decoded
        } catch {
            print("Failed to load cars: \(error)")
            self.cars = []
        }
    }
    
    private func save() {
        let url = fileURL()
        do {
            let data = try JSONEncoder().encode(cars)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Failed to save cars: \(error)")
        }
    }
}
