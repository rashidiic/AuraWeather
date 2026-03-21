import Foundation
import Combine
import CoreLocation
import CoreLocation

@MainActor
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    @Published var weather: WeatherResponse?
    @Published var forecast: [ForecastItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationName: String = ""
    
    private let apiKey = "9e596288abd309cd50915052400fa06d"
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
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
        errorMessage = "Не удалось получить геолокацию"
        // Загружаем Баку по умолчанию
        Task { await fetchWeather(lat: 40.4093, lon: 49.8671) }
    }
    
    // MARK: - Поиск по городу
    func fetchWeatherForCity(_ city: String) {
        Task { await fetchWeatherByCity(city) }
    }
    
    // MARK: - API запросы
    private func fetchWeather(lat: Double, lon: Double) async {
        isLoading = true
        errorMessage = nil
        
        async let weatherTask = fetch(
            WeatherResponse.self,
            from: "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric&lang=ru"
        )
        async let forecastTask = fetch(
            ForecastResponse.self,
            from: "\(baseURL)/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric&lang=ru"
        )
        
        do {
            let (w, f) = try await (weatherTask, forecastTask)
            weather = w
            forecast = dailyForecast(from: f.list)
            locationName = w.name
        } catch {
            errorMessage = "Ошибка загрузки данных"
        }
        isLoading = false
    }
    
    private func fetchWeatherByCity(_ city: String) async {
        isLoading = true
        errorMessage = nil
        
        let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        
        async let weatherTask = fetch(
            WeatherResponse.self,
            from: "\(baseURL)/weather?q=\(encodedCity)&appid=\(apiKey)&units=metric&lang=ru"
        )
        async let forecastTask = fetch(
            ForecastResponse.self,
            from: "\(baseURL)/forecast?q=\(encodedCity)&appid=\(apiKey)&units=metric&lang=ru"
        )
        
        do {
            let (w, f) = try await (weatherTask, forecastTask)
            weather = w
            forecast = dailyForecast(from: f.list)
            locationName = w.name
        } catch {
            errorMessage = "Город не найден"
        }
        isLoading = false
    }
    
    private func fetch<T: Codable>(_ type: T.Type, from urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Оставляем один прогноз на день (12:00)
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
