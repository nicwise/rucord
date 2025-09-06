import Foundation
import Combine

final class CarStore: ObservableObject {
    @Published var cars: [Car] = [] {
        didSet { save() }
    }
    
    private let fileName = "cars.json"
    private let backupFileName = "cars_backup.json"
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
    
    private func backupURL() -> URL { documentsURL().appendingPathComponent(backupFileName) }
    
    private func load() {
        let url = fileURL()
        let backupUrl = backupURL()
        
        // Try loading main file first
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Car].self, from: data)
                self.cars = decoded
                return
            } catch {
                print("Failed to load main cars file: \(error)")
            }
        }
        
        // Try loading backup file if main file failed or doesn't exist
        if FileManager.default.fileExists(atPath: backupUrl.path) {
            do {
                let data = try Data(contentsOf: backupUrl)
                let decoded = try JSONDecoder().decode([Car].self, from: data)
                self.cars = decoded
                print("Loaded cars from backup file")
                return
            } catch {
                print("Failed to load backup cars file: \(error)")
            }
        }
        
        // If both failed, start with empty array
        self.cars = []
    }
    
    private func save() {
        let url = fileURL()
        let backupUrl = backupURL()
        
        do {
            let data = try JSONEncoder().encode(cars)
            
            // Create backup of current file if it exists
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    _ = try FileManager.default.replaceItem(at: backupUrl, withItemAt: url, 
                                                          backupItemName: nil, options: [], 
                                                          resultingItemURL: nil)
                } catch {
                    // If replace fails, try copy
                    try? FileManager.default.removeItem(at: backupUrl)
                    try? FileManager.default.copyItem(at: url, to: backupUrl)
                }
            }
            
            // Write new data
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Failed to save cars: \(error)")
        }
    }
}
