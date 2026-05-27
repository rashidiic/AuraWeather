import Foundation
import Combine
import CoreLocation
import UserNotifications
import SwiftUI

@MainActor
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var weather: WeatherResponse?
    @Published var forecast: [ForecastItem] = []
    @Published var hourlyForecast: [ForecastItem] = []
    @Published var uvIndex: Double = 0
    @Published var airQuality: AQItem?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationName: String = ""
    @Published var savedCities: [SavedCity] = []

    private let apiKey = "9e596288abd309cd50915052400fa06d"
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        loadSavedCities()
        requestNotificationPermission()
    }

    // MARK: - Геолокация
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        lastLocation = location
        Task {
            await fetchWeather(lat: location.coordinate.latitude,
                               lon: location.coordinate.longitude)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await fetchWeather(lat: 40.4093, lon: 49.8671) }
    }

    // MARK: - Поиск по городу
    func fetchWeatherForCity(_ city: String) {
        Task { await fetchWeatherByCity(city) }
    }

    // MARK: - Основной запрос по координатам
    private func fetchWeather(lat: Double, lon: Double) async {
        isLoading = true
        errorMessage = nil

        async let weatherTask = fetch(WeatherResponse.self,
            from: "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric")
        async let forecastTask = fetch(ForecastResponse.self,
            from: "\(baseURL)/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric")
        async let aqTask = fetch(AirQualityResponse.self,
            from: "\(baseURL)/air_pollution?lat=\(lat)&lon=\(lon)&appid=\(apiKey)")

        do {
            let (w, f, aq) = try await (weatherTask, forecastTask, aqTask)
            weather = w
            forecast = dailyForecast(from: f.list)
            hourlyForecast = Array(f.list.prefix(8))
            airQuality = aq.list.first
            locationName = w.name

            // UV черезOneCall (бесплатный endpoint)
            if let uvData = try? await fetch(UVResponse.self,
                from: "https://api.openweathermap.org/data/2.5/uvi?lat=\(lat)&lon=\(lon)&appid=\(apiKey)") {
                uvIndex = uvData.value
            }

            checkAndSendNotifications(weather: w)
            await refreshSavedCities()
        } catch {
            errorMessage = "Ошибка загрузки данных"
        }
        isLoading = false
    }

    // MARK: - Запрос по названию города
    private func fetchWeatherByCity(_ city: String) async {
        isLoading = true
        errorMessage = nil

        let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city

        async let weatherTask = fetch(WeatherResponse.self,
            from: "\(baseURL)/weather?q=\(encoded)&appid=\(apiKey)&units=metric")
        async let forecastTask = fetch(ForecastResponse.self,
            from: "\(baseURL)/forecast?q=\(encoded)&appid=\(apiKey)&units=metric")

        do {
            let (w, f) = try await (weatherTask, forecastTask)
            weather = w
            forecast = dailyForecast(from: f.list)
            hourlyForecast = Array(f.list.prefix(8))
            locationName = w.name

            let lat = w.coord.lat
            let lon = w.coord.lon

            if let aq = try? await fetch(AirQualityResponse.self,
                from: "\(baseURL)/air_pollution?lat=\(lat)&lon=\(lon)&appid=\(apiKey)") {
                airQuality = aq.list.first
            }
            if let uvData = try? await fetch(UVResponse.self,
                from: "https://api.openweathermap.org/data/2.5/uvi?lat=\(lat)&lon=\(lon)&appid=\(apiKey)") {
                uvIndex = uvData.value
            }

            checkAndSendNotifications(weather: w)
        } catch {
            errorMessage = "Город не найден"
        }
        isLoading = false
    }

    // MARK: - Несколько городов
    func addCity(_ city: String) {
        Task {
            let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
            guard let w = try? await fetch(WeatherResponse.self,
                from: "\(baseURL)/weather?q=\(encoded)&appid=\(apiKey)&units=metric") else { return }

            let newCity = SavedCity(name: w.name, lat: w.coord.lat, lon: w.coord.lon, weather: w)
            if !savedCities.contains(where: { $0.name.lowercased() == w.name.lowercased() }) {
                savedCities.append(newCity)
                saveCities()
            }
        }
    }

    func removeCity(at offsets: IndexSet) {
        savedCities.remove(atOffsets: offsets)
        saveCities()
    }

    func refreshSavedCities() async {
        for i in savedCities.indices {
            if let w = try? await fetch(WeatherResponse.self,
                from: "\(baseURL)/weather?lat=\(savedCities[i].lat)&lon=\(savedCities[i].lon)&appid=\(apiKey)&units=metric") {
                savedCities[i].weather = w
            }
        }
        saveCities()
    }

    private func saveCities() {
        if let data = try? JSONEncoder().encode(savedCities) {
            UserDefaults.standard.set(data, forKey: "savedCities")
        }
    }

    private func loadSavedCities() {
        if let data = UserDefaults.standard.data(forKey: "savedCities"),
           let cities = try? JSONDecoder().decode([SavedCity].self, from: data) {
            savedCities = cities
        }
    }

    // MARK: - Уведомления
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func checkAndSendNotifications(weather: WeatherResponse) {
        let condition = weather.weather.first?.main.lowercased() ?? ""
        let temp = weather.main.temp

        if condition == "rain" || condition == "drizzle" || condition == "thunderstorm" {
            sendNotification(title: "🌧 Дождь в \(weather.name)",
                           body: "На улице \(weather.weather.first?.description ?? "дождь"). Возьмите зонт!")
        } else if temp < 0 {
            sendNotification(title: "🥶 Мороз в \(weather.name)",
                           body: "Температура \(Int(temp))°. Одевайтесь теплее!")
        } else if temp > 35 {
            sendNotification(title: "🔥 Жара в \(weather.name)",
                           body: "Температура \(Int(temp))°. Пейте больше воды!")
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers
    private func fetch<T: Codable>(_ type: T.Type, from urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func dailyForecast(from items: [ForecastItem]) -> [ForecastItem] {
        var seen = Set<String>()
        var result: [ForecastItem] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for item in items {
            let day = formatter.string(from: item.date)
            if !seen.contains(day) {
                seen.insert(day)
                result.append(item)
            }
            if result.count == 5 { break }
        }
        return result
    }
}
