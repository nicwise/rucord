import Foundation

enum NZTAURLs {
    static let registrationRenewal = URL(
        string: "https://transact.nzta.govt.nz/v2/vehicle-licence-renewal"
    )!

    static func purchaseRUC(for plate: String) -> URL {
        URL(string: "https://transact.nzta.govt.nz/v2/purchase-ruc?plate=\(plate)")!
    }
}
