import Foundation

// MARK: - Текущая погода
struct WeatherResponse: Codable, Equatable {
    let name: String
    let main: MainWeather
    let weather: [WeatherCondition]
    let wind: Wind
    let sys: Sys
}

struct MainWeather: Codable, Equatable {
    let temp: Double
    let feelsLike: Double
    let humidity: Int
    let tempMin: Double
    let tempMax: Double

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case humidity
        case tempMin = "temp_min"
        case tempMax = "temp_max"
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
}

// MARK: - Прогноз 5 дней
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
}

// MARK: - Хелпер для SF Symbol иконок
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

// MARK: - Цвет градиента неба
func skyGradient(for condition: String, isDaytime: Bool) -> [String] {
    if !isDaytime { return ["#0f0c29", "#302b63"] }
    switch condition.lowercased() {
    case "clear":        return ["#56CCF2", "#2F80ED"]
    case "clouds":       return ["#757F9A", "#D7DDE8"]
    case "rain", "drizzle", "thunderstorm": return ["#373B44", "#4286f4"]
    case "snow":         return ["#E0EAFC", "#CFDEF3"]
    default:             return ["#56CCF2", "#2F80ED"]
    }
}
