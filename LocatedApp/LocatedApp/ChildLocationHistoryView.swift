import SwiftUI
import MapKit

// MARK: - Child Location History View
struct ChildLocationHistoryView: View {
    let childId: String
    let childName: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var historyService = LocationHistoryService()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(childName)
                                .font(.radioCanadaBig(24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Location Trail - Last 6 Hours")
                                .font(.radioCanadaBig(14, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding()
                }
                .background(Color.vibrantRed)
                
                // Map
                if historyService.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading history...")
                            .font(.radioCanadaBig(16, weight: .regular))
                        Spacer()
                    }
                } else if let errorMessage = historyService.errorMessage {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.radioCanadaBig(14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                } else if historyService.historyPoints.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "location.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No location history")
                            .font(.radioCanadaBig(18, weight: .semibold))
                        Text("Location updates will appear here once \(childName) starts sharing their location.")
                            .font(.radioCanadaBig(14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                } else {
                    HistoryMapView(
                        historyPoints: historyService.historyPoints,
                        region: $region
                    )
                    
                    // Stats Footer
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(historyService.historyPoints.count)")
                                .font(.radioCanadaBig(20, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Points")
                                .font(.radioCanadaBig(12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        if let firstPoint = historyService.historyPoints.first,
                           let lastPoint = historyService.historyPoints.last {
                            VStack(spacing: 4) {
                                Text(timeAgoString(from: firstPoint.timestamp))
                                    .font(.radioCanadaBig(20, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Duration")
                                    .font(.radioCanadaBig(12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await historyService.fetchHistory(childId: childId, hours: 6)
                updateMapRegion()
            }
        }
    }
    
    private func updateMapRegion() {
        guard !historyService.historyPoints.isEmpty else { return }
        
        let coordinates = historyService.historyPoints.map { $0.coordinate }
        
        // Calculate bounding box
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLng = coordinates.map { $0.longitude }.min() ?? 0
        let maxLng = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.3,
            longitudeDelta: max(maxLng - minLng, 0.01) * 1.3
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        if hours > 0 {
            return "\(hours)h"
        }
        let minutes = Int(interval / 60)
        return "\(minutes)m"
    }
}

// MARK: - History Map View
struct HistoryMapView: UIViewRepresentable {
    let historyPoints: [LocationHistoryPoint]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard !historyPoints.isEmpty else { return }
        
        // Create polyline from history points
        let coordinates = historyPoints.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Add start marker (green)
        if let firstPoint = historyPoints.first {
            let startAnnotation = HistoryPointAnnotation(
                coordinate: firstPoint.coordinate,
                title: "Start",
                subtitle: formatTime(firstPoint.timestamp),
                isStart: true
            )
            mapView.addAnnotation(startAnnotation)
        }
        
        // Add end marker (red)
        if let lastPoint = historyPoints.last, historyPoints.count > 1 {
            let endAnnotation = HistoryPointAnnotation(
                coordinate: lastPoint.coordinate,
                title: "Current",
                subtitle: formatTime(lastPoint.timestamp),
                isStart: false
            )
            mapView.addAnnotation(endAnnotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let historyAnnotation = annotation as? HistoryPointAnnotation else {
                return nil
            }
            
            let identifier = "HistoryPoint"
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            annotationView.annotation = annotation
            annotationView.markerTintColor = historyAnnotation.isStart ? .systemGreen : .systemRed
            annotationView.glyphImage = UIImage(systemName: historyAnnotation.isStart ? "figure.walk" : "mappin.circle.fill")
            annotationView.canShowCallout = true
            
            return annotationView
        }
    }
}

// MARK: - History Point Annotation
class HistoryPointAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let isStart: Bool
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, isStart: Bool) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.isStart = isStart
    }
}

