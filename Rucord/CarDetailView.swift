import SwiftUI
import PhotosUI

struct CarDetailView: View {
    @EnvironmentObject var store: CarStore
    @State var car: Car
    @State var newOdo: String = ""
    @State var newDate: Date = Date()
    @State var editing = false
    @State var showAllHistory = false
    @State var selectedImage: PhotosPickerItem?
    @State var pendingCarImage: UIImage?
    @State var showingDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            summarySection

            if editing {
                carPhotoSection
            }

            addReadingSection

            if shouldShowBuyRUCSection {
                buyRUCSection
            }

            rucSettingsSection

            if editing {
                wofRegistrationEditingSection
            } else if shouldShowWOFRegistrationSection {
                wofRegistrationStatusSection
            }

            historySection

            if editing {
                dangerZoneSection
            }
        }
        .navigationTitle(car.plate)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "Done" : "Edit") {
                    if editing {
                        finishEditing()
                    } else {
                        startEditing()
                    }
                    withAnimation {
                        editing.toggle()
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(car.plate)?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.deleteCar(car)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(
                "This will permanently delete the car, its readings, and its photo. This action cannot be undone."
            )
        }
        .onChange(of: store.cars) { _, newCars in
            if let updated = newCars.first(where: { $0.id == car.id }) {
                car = updated
            }
        }
    }
}
