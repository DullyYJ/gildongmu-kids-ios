import Foundation
import CoreLocation
import UIKit

/// 부모님께 내 위치 알리기. 동의를 마치고 위치 공유가 켜져 있을 때만 위치를 받는다.
/// 보내는 주기는 안드로이드 키즈와 같다: 평소 5분 · 서버가 "가만히/멀리/약속 없음/보는 사람 없음"(sl)이면 8분 · 움직이면 3분 ·
/// 부모님이 지도를 보는 중이면 서버가 준 w(1=2.5초 · 2=10초 · 3=15초). 판단은 서버가 하고 앱은 그 값을 따른다.
final class KidsLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = KidsLocation()
    @Published private(set) var on = false
    @Published private(set) var denied = false
    private let mgr = CLLocationManager()
    private var lastSent = Date.distantPast
    private var interval: TimeInterval = 300
    private var sending = false
    private(set) var last: CLLocation?

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        mgr.distanceFilter = kCLDistanceFilterNone
        mgr.activityType = .otherNavigation
        mgr.pausesLocationUpdatesAutomatically = false
    }

    static var consented: Bool { UserDefaults.standard.integer(forKey: "kids.consent") >= 2 }
    static var wantShare: Bool { UserDefaults.standard.object(forKey: "kids.share") as? Bool ?? true }

    /// 동의 · 설정에 맞춰 켜거나 끈다(앱을 켤 때, 동의 직후, 스위치를 바꿀 때 부른다).
    func sync() {
        let want = Self.consented && Self.wantShare
        if want { start() } else { stop() }
    }
    private func start() {
        let st = mgr.authorizationStatus
        if st == .notDetermined { mgr.requestWhenInUseAuthorization(); return }
        if st == .denied || st == .restricted { DispatchQueue.main.async { self.denied = true; self.on = false }; return }
        if st == .authorizedWhenInUse { mgr.requestAlwaysAuthorization() }       // 앱을 닫아도 계속(항상 허용) — 거절하면 앱이 열려 있을 때만
        mgr.allowsBackgroundLocationUpdates = true
        mgr.showsBackgroundLocationIndicator = true
        mgr.startUpdatingLocation()
        DispatchQueue.main.async { self.denied = false; self.on = true }
    }
    private func stop() {
        mgr.stopUpdatingLocation()
        DispatchQueue.main.async { self.on = false }
    }
    /// 위치 한 번만(장면 날씨용) — 공유와 상관없이 앱이 열려 있을 때.
    func once() { if mgr.authorizationStatus == .notDetermined { mgr.requestWhenInUseAuthorization() } else { mgr.requestLocation() } }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { sync() }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last, l.horizontalAccuracy >= 0 else { return }
        last = l
        guard Self.consented, Self.wantShare, !sending, Date().timeIntervalSince(lastSent) >= interval else { return }
        sending = true; lastSent = Date()
        let dev = UIDevice.current
        dev.isBatteryMonitoringEnabled = true
        let bt = dev.batteryLevel < 0 ? -1 : Int((dev.batteryLevel * 100).rounded())
        let ch = dev.batteryState == .charging || dev.batteryState == .full
        Task { [weak self] in
            let r = await KidsServer.loc(la: l.coordinate.latitude, lo: l.coordinate.longitude, acc: l.horizontalAccuracy, bt: bt, ch: ch)
            self?.sending = false
            self?.follow(r)
        }
    }
    /// 서버 답을 따른다: w 가 있으면 촘촘히, sl 이 있으면 느리게, 아니면 평소.
    private func follow(_ r: [String: Any]?) {
        guard let r = r else { return }
        let w = (r["w"] as? NSNumber)?.intValue ?? 0
        if w == 1 { interval = 2.5 } else if w == 2 { interval = 10 } else if w == 3 { interval = 15 }
        else if (r["sl"] as? NSNumber)?.intValue == 1 { interval = 480 }
        else { interval = 300 }
        if let l = (r["linked"] as? NSNumber)?.intValue { DispatchQueue.main.async { Task { @MainActor in KidsStore.shared.noteLinked(l) } } }
    }
}
