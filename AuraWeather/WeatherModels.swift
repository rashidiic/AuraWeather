import Foundation

// MARK: - Текущая погода
struct WeatherResponse: Codable, Equatable {
    let name: String
    let main: MainWeather
    let weather: [WeatherCondition]
    let wind: Wind
    let sys: Sys
    let coord: Coord
}

struct Coord: Codable, Equatable {
    let lat: Double
    let lon: Double
}

struct MainWeather: Codable, Equatable {
    let temp: Double
    let feelsLike: Double
    let humidity: Int
    let tempMin: Double
    let tempMax: Double
    let pressure: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case humidity
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case pressure
    }
}

struct WeatherCondition: Codable, Equatable {
    let main: String
    let description: String
    let icon: String
}

struct Wind: Codable, Equatable {
    let speed: Double
}

struct Sys: Codable, Equatable {
    let country: String
    let sunrise: TimeInterval
    let sunset: TimeInterval
}

// MARK: - Прогноз 5 дней / почасовой
struct ForecastResponse: Codable {
    let list: [ForecastItem]
}

struct ForecastItem: Codable, Identifiable {
    let id = UUID()
    let dt: TimeInterval
    let main: MainWeather
    let weather: [WeatherCondition]

    enum CodingKeys: String, CodingKey {
        case dt, main, weather
    }

    var date: Date { Date(timeIntervalSince1970: dt) }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - UV Index
struct UVResponse: Codable {
    let value: Double
}

// MARK: - Air Quality
struct AirQualityResponse: Codable {
    let list: [AQItem]
}

struct AQItem: Codable {
    let main: AQMain
    let components: AQComponents
}

struct AQMain: Codable {
    let aqi: Int
}

struct AQComponents: Codable {
    let pm2_5: Double
    let pm10: Double
    let no2: Double
    let o3: Double

    enum CodingKeys: String, CodingKey {
        case pm2_5 = "pm2_5"
        case pm10, no2, o3
    }
}

// MARK: - Сохранённый город
struct SavedCity: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let lat: Double
    let lon: Double
    var weather: WeatherResponse?

    init(id: UUID = UUID(), name: String, lat: Double, lon: Double, weather: WeatherResponse? = nil) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
        self.weather = weather
    }

    static func == (lhs: SavedCity, rhs: SavedCity) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Хелперы
func weatherIcon(for condition: String) -> String {
    switch condition.lowercased() {
    case "clear":        return "sun.max.fill"
    case "clouds":       return "cloud.fill"
    case "rain":         return "cloud.rain.fill"
    case "drizzle":      return "cloud.drizzle.fill"
    case "thunderstorm": return "cloud.bolt.rain.fill"
    case "snow":         return "snowflake"
    case "mist", "fog":  return "cloud.fog.fill"
    default:             return "cloud.sun.fill"
    }
}

func uvDescription(_ uv: Double) -> (label: String, color: String) {
    switch uv {
    case 0..<3:   return (String(localized: "low"), "#4CAF50")
    case 3..<6:   return (String(localized: "moderate_uv"), "#FFC107")
    case 6..<8:   return (String(localized: "high"), "#FF9800")
    case 8..<11:  return (String(localized: "very_high"), "#F44336")
    default:      return (String(localized: "extreme"), "#9C27B0")
    }
}

func aqiDescription(_ aqi: Int) -> (label: String, color: String) {
    switch aqi {
    case 1: return (String(localized: "good"), "#4CAF50")
    case 2: return (String(localized: "fair"), "#8BC34A")
    case 3: return (String(localized: "moderate"), "#FFC107")
    case 4: return (String(localized: "poor"), "#FF9800")
    default: return (String(localized: "very_poor"), "#F44336")
    }
}
