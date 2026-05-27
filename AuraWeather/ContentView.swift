import SwiftUI
import Combine

extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Время суток
enum TimeOfDay {
    case morning, day, evening, night
    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9:   return .morning
        case 9..<18:  return .day
        case 18..<22: return .evening
        default:      return .night
        }
    }
}

// MARK: - Частицы
enum ParticleType { case star, rain, snow, sparkle }

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat; var y: CGFloat; var size: CGFloat
    var opacity: Double; var speed: CGFloat
    var type: ParticleType; var twinkle: Double = 0
    var twinkleSpeed: Double

    static func random(in size: CGSize, type: ParticleType) -> Particle {
        Particle(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height),
            size: type == .rain ? CGFloat.random(in: 1...2) : type == .snow ? CGFloat.random(in: 3...7) : CGFloat.random(in: 1...3),
            opacity: Double.random(in: 0.4...1.0),
            speed: type == .rain ? CGFloat.random(in: 8...14) : type == .snow ? CGFloat.random(in: 1...3) : CGFloat.random(in: 0.1...0.4),
            type: type, twinkleSpeed: Double.random(in: 0.02...0.07))
    }

    mutating func update(in size: CGSize) {
        switch type {
        case .rain:
            y += speed; x += 1
            if y > size.height { y = -10; x = CGFloat.random(in: 0...size.width) }
        case .snow:
            y += speed; x += sin(y / 30) * 0.5
            if y > size.height { y = -10; x = CGFloat.random(in: 0...size.width) }
        case .star, .sparkle:
            twinkle += twinkleSpeed
            opacity = 0.4 + abs(sin(twinkle)) * 0.6
        }
    }
}

struct ParticleView: View {
    let particle: Particle
    var body: some View {
        Group {
            switch particle.type {
            case .rain:
                Rectangle().fill(.white.opacity(particle.opacity * 0.6))
                    .frame(width: particle.size * 0.5, height: particle.size * 8)
                    .rotationEffect(.degrees(15))
            case .snow:
                Image(systemName: "snowflake").font(.system(size: particle.size))
                    .foregroundStyle(.white.opacity(particle.opacity))
            case .star, .sparkle:
                Circle().fill(.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
            }
        }
        .position(x: particle.x, y: particle.y)
    }
}

struct ParticleSystemView: View {
    let condition: String
    @State private var particles: [Particle] = []
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var config: (count: Int, type: ParticleType) {
        switch TimeOfDay.current {
        case .night: return (80, .star)
        case .morning, .day, .evening:
            switch condition.lowercased() {
            case "rain", "drizzle": return (60, .rain)
            case "thunderstorm":    return (80, .rain)
            case "snow":            return (50, .snow)
            default:                return (25, .sparkle)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack { ForEach(particles) { p in ParticleView(particle: p) } }
            .onAppear {
                particles = (0..<config.count).map { _ in Particle.random(in: geo.size, type: config.type) }
            }
            .onReceive(timer) { _ in
                for i in particles.indices { particles[i].update(in: geo.size) }
            }
        }
    }
}

// MARK: - Фон неба
struct SkyBackgroundView: View {
    let condition: String
    var colors: [Color] {
        switch TimeOfDay.current {
        case .night:
            return [Color(hexString: "#0a0015"), Color(hexString: "#0d0d2b"), Color(hexString: "#1a1a4e")]
        case .morning:
            switch condition.lowercased() {
            case "rain", "drizzle", "thunderstorm":
                return [Color(hexString: "#4a5568"), Color(hexString: "#718096"), Color(hexString: "#a0aec0")]
            default:
                return [Color(hexString: "#ff9a56"), Color(hexString: "#ffb347"), Color(hexString: "#ffd700")]
            }
        case .day:
            switch condition.lowercased() {
            case "clear":  return [Color(hexString: "#1a6fa8"), Color(hexString: "#2980b9"), Color(hexString: "#56CCF2")]
            case "clouds": return [Color(hexString: "#4a5568"), Color(hexString: "#718096"), Color(hexString: "#a0aec0")]
            case "rain", "drizzle", "thunderstorm":
                return [Color(hexString: "#2d3748"), Color(hexString: "#4a5568"), Color(hexString: "#2980b9")]
            case "snow":   return [Color(hexString: "#a8c8e8"), Color(hexString: "#c5dff0"), Color(hexString: "#e8f4fd")]
            default:       return [Color(hexString: "#1a6fa8"), Color(hexString: "#2980b9"), Color(hexString: "#56CCF2")]
            }
        case .evening:
            return [Color(hexString: "#c0392b"), Color(hexString: "#8e44ad"), Color(hexString: "#2c3e70")]
        }
    }
    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .animation(.easeInOut(duration: 2.0), value: condition)
    }
}

// MARK: - Main Tab View
struct ContentView: View {
    @StateObject private var service = WeatherService()

    var body: some View {
        TabView {
            MainWeatherTab(service: service)
                .tabItem {
                    Label(String(localized: "weather_tab"), systemImage: "cloud.sun.fill")
                }

            CitiesView(service: service)
                .tabItem {
                    Label(String(localized: "cities_tab"), systemImage: "list.bullet")
                }
        }
        .onAppear {
            service.requestLocation()
        }
    }
}

// MARK: - Главная вкладка
struct MainWeatherTab: View {
    @ObservedObject var service: WeatherService
    @State private var showSearch = false
    @State private var animateIn = false

    var body: some View {
        ZStack {
            SkyBackgroundView(condition: service.weather?.weather.first?.main ?? "Clear")
                .ignoresSafeArea()
            ParticleSystemView(condition: service.weather?.weather.first?.main ?? "Clear")
                .ignoresSafeArea()

            if service.isLoading {
                SearchView.LoadingView()
            } else if let weather = service.weather {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        MainWeatherView(weather: weather)
                            .opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 30)

                        WeatherDetailsView(weather: weather)
                            .opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 30)

                        // Почасовой прогноз
                        if !service.hourlyForecast.isEmpty {
                            HourlyForecastView(items: service.hourlyForecast)
                                .opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 30)
                        }

                        // UV + качество воздуха
                        UVAirQualityView(uv: service.uvIndex, aq: service.airQuality)
                            .opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 30)

                        if !service.forecast.isEmpty {
                            ForecastView(forecast: service.forecast)
                                .opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 30)
                        }

                        Spacer(minLength: 40)
                    }
                }
            } else {
                SearchView.WelcomeView()
            }

            VStack {
                HStack {
                    Spacer()
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { animateIn = true }
        }
        .onChange(of: service.weather) {
            animateIn = false
            withAnimation(.easeOut(duration: 0.6)) { animateIn = true }
        }
        .sheet(isPresented: $showSearch) {
            SearchView(service: service, isPresented: $showSearch)
        }
    }
}

// MARK: - Почасовой прогноз
struct HourlyForecastView: View {
    let items: [ForecastItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "hourly_forecast"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 20).padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(items) { item in
                        VStack(spacing: 8) {
                            Text(item.hourString)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                            Image(systemName: weatherIcon(for: item.weather.first?.main ?? ""))
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                            Text("\(Int(item.main.temp))°")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(item.main.humidity)%")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(width: 70)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - UV + Air Quality
struct UVAirQualityView: View {
    let uv: Double
    let aq: AQItem?

    var body: some View {
        HStack(spacing: 12) {
            let uvInfo = uvDescription(uv)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    Text(String(localized: "uv_index")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Text("\(Int(uv))").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                Text(uvInfo.label).font(.system(size: 13)).foregroundStyle(Color(hexString: uvInfo.color)).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25), lineWidth: 0.5))

            if let aq = aq {
                let aqInfo = aqiDescription(aq.main.aqi)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "wind").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                        Text(String(localized: "air_quality")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                    }
                    Text("AQI \(aq.main.aqi)").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    Text(aqInfo.label).font(.system(size: 13)).foregroundStyle(Color(hexString: aqInfo.color)).fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                .background(.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
    }
}

// MARK: - Основная погода
struct MainWeatherView: View {
    let weather: WeatherResponse
    var body: some View {
        VStack(spacing: 8) {
            Text(weather.name)
                .font(.system(size: 32, weight: .medium)).foregroundStyle(.white)
            Text("\(Int(weather.main.temp))°")
                .font(.system(size: 96, weight: .thin)).foregroundStyle(.white)
            Text(weather.weather.first?.description.capitalized ?? "")
                .font(.system(size: 20)).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 16) {
                Text("Макс: \(Int(weather.main.tempMax))°")
                Text("Мин: \(Int(weather.main.tempMin))°")
            }
            .font(.system(size: 17)).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, 80).padding(.bottom, 30)
    }
}

// MARK: - Детали
struct WeatherDetailsView: View {
    let weather: WeatherResponse
    var body: some View {
        HStack(spacing: 0) {
            DetailCell(icon: "thermometer.medium", value: "\(Int(weather.main.feelsLike))°", label: String(localized: "feels_like"))
            Divider().frame(height: 40).overlay(Color.white.opacity(0.3))
            DetailCell(icon: "humidity", value: "\(weather.main.humidity)%", label: String(localized: "humidity"))
            Divider().frame(height: 40).overlay(Color.white.opacity(0.3))
            DetailCell(icon: "wind", value: "\(Int(weather.wind.speed)) м/с", label: String(localized: "wind"))
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 0.5))
        .padding(.horizontal, 20).padding(.bottom, 16)
    }
}

struct DetailCell: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(.white.opacity(0.9))
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Прогноз 5 дней
struct ForecastView: View {
    let forecast: [ForecastItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "five_day_forecast"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 20).padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(forecast.enumerated()), id: \.offset) { index, item in
                    ForecastRow(item: item)
                    if index < forecast.count - 1 {
                        Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5).padding(.horizontal, 20)
                    }
                }
            }
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 0.5))
            .padding(.horizontal, 20).padding(.bottom, 16)

            HStack(spacing: 12) {
                ExtraInfoCard(icon: "sunrise.fill", title: String(localized: "sunrise"), value: sunriseTime())
                ExtraInfoCard(icon: "sunset.fill", title: String(localized: "sunset"), value: sunsetTime())
                ExtraInfoCard(icon: "gauge.medium", title: String(localized: "pressure"), value: pressureValue())
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
    }

    func sunriseTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "06:24" : "06:24"
    }
    func sunsetTime() -> String { "19:47" }
    func pressureValue() -> String { "1013 гПа" }
}

struct ExtraInfoCard: View {
    let icon: String; let title: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Text(value).font(.system(size: 18, weight: .medium)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Строка прогноза
struct ForecastRow: View {
    let item: ForecastItem
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack {
                Text(item.dayName).font(.system(size: 17)).foregroundStyle(.white)
                    .frame(width: 50, alignment: .leading)
                Image(systemName: weatherIcon(for: item.weather.first?.main ?? ""))
                    .font(.system(size: 20)).foregroundStyle(.white.opacity(0.9)).frame(width: 32)
                Text(item.weather.first?.description.capitalized ?? "")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                Text("\(Int(item.main.tempMin))°")
                    .font(.system(size: 17)).foregroundStyle(.white.opacity(0.6))
                    .frame(width: 36, alignment: .trailing)
                Text("\(Int(item.main.tempMax))°")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .sheet(isPresented: $showDetail) { ForecastDetailView(item: item) }
    }
}

// MARK: - Детали дня
struct ForecastDetailView: View {
    let item: ForecastItem

    var fullDayName: String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "EEEE"
        return f.string(from: item.date).capitalized
    }
    var dateString: String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "d MMMM"
        return f.string(from: item.date)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hexString: "#0d0d2b"), Color(hexString: "#1a1a4e"), Color(hexString: "#2d1b69")],
                startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.3))
                        .frame(width: 40, height: 5).padding(.top, 12)

                    VStack(spacing: 4) {
                        Text(fullDayName).font(.system(size: 28, weight: .medium)).foregroundStyle(.white)
                        Text(dateString).font(.system(size: 16)).foregroundStyle(.white.opacity(0.6))
                    }

                    Image(systemName: weatherIcon(for: item.weather.first?.main ?? ""))
                        .font(.system(size: 90)).foregroundStyle(.white)

                    Text(item.weather.first?.description.capitalized ?? "")
                        .font(.system(size: 20)).foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text(String(localized: "minimum")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                            Text("\(Int(item.main.tempMin))°").font(.system(size: 48, weight: .thin)).foregroundStyle(.white)
                        }.frame(maxWidth: .infinity)
                        Rectangle().fill(.white.opacity(0.2)).frame(width: 0.5, height: 60)
                        VStack(spacing: 4) {
                            Text(String(localized: "maximum")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                            Text("\(Int(item.main.tempMax))°").font(.system(size: 48, weight: .thin)).foregroundStyle(.white)
                        }.frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: 0.5))
                    .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DetailSheetCard(icon: "thermometer.medium", value: "\(Int(item.main.feelsLike))°", label: "Ощущается")
                        DetailSheetCard(icon: "humidity", value: "\(item.main.humidity)%", label: "Влажность")
                        DetailSheetCard(icon: "thermometer.low", value: "\(Int(item.main.tempMin))°", label: "Минимум")
                        DetailSheetCard(icon: "thermometer.high", value: "\(Int(item.main.tempMax))°", label: "Максимум")
                    }.padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "sensations"))
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                        let feelsLike = item.main.feelsLike
                        let comfort: (String, String, String) = {
                            switch feelsLike {
                            case ..<0:    return ("snowflake", String(localized: "very_cold"), String(localized: "very_cold_tip"))
                            case 0..<8:   return ("wind", String(localized: "cold"), String(localized: "cold_tip"))
                            case 8..<16:  return ("cloud", String(localized: "cool"), String(localized: "cool_tip"))
                            case 16..<24: return ("sun.max", String(localized: "comfortable"), String(localized: "comfortable_tip"))
                            case 24..<30: return ("sun.max.fill", String(localized: "warm"), String(localized: "warm_tip"))
                            default:      return ("thermometer.sun.fill", String(localized: "hot"), String(localized: "hot_tip"))
                            }
                        }()
                        HStack(spacing: 16) {
                            Image(systemName: comfort.0).font(.system(size: 32)).foregroundStyle(.white).frame(width: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comfort.1).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                                Text(comfort.2).font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 0.5))
                    }.padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "atmosphere"))
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                        HStack(spacing: 12) {
                            AtmosphereCard(icon: "cloud.fill", title: String(localized: "clouds"), value: cloudDescription(item.weather.first?.main ?? ""))
                            AtmosphereCard(icon: "drop.fill", title: String(localized: "precipitation"), value: precipDescription(item.weather.first?.main ?? ""))
                        }
                    }.padding(.horizontal, 20)

                    Spacer(minLength: 30)
                }
            }
        }
    }

    func cloudDescription(_ c: String) -> String {
        switch c.lowercased() {
        case "clear":  return String(localized: "clear_sky")
        case "clouds": return String(localized: "cloudy")
        default:       return String(localized: "variable")
        }
    }
    func precipDescription(_ c: String) -> String {
        switch c.lowercased() {
        case "rain", "drizzle": return String(localized: "rain_precip")
        case "thunderstorm":    return String(localized: "storm")
        case "snow":            return String(localized: "snow_precip")
        default:                return String(localized: "none")
        }
    }
}

struct AtmosphereCard: View {
    let icon: String; let title: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            }
            Text(value).font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 0.5))
    }
}

struct DetailSheetCard: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(.white.opacity(0.8))
            Text(value).font(.system(size: 24, weight: .medium)).foregroundStyle(.white)
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Поиск
struct SearchView: View {
    @ObservedObject var service: WeatherService
    @Binding var isPresented: Bool
    @State private var text = ""
    @State private var suggestions: [String] = []
    @FocusState private var focused: Bool
    
    let popularCities = [
        "Москва", "Санкт-Петербург", "Баку", "Лондон", "Нью-Йорк",
        "Париж", "Дубай", "Стамбул", "Токио", "Берлин",
        "Рим", "Барселона", "Амстердам", "Сингапур", "Сеул",
        "Пекин", "Шанхай", "Торонто", "Сидней", "Лос-Анджелес",
        "Тбилиси", "Ташкент", "Алматы", "Бишкек", "Астана"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(String(localized: "enter_city"), text: $text)
                        .focused($focused).submitLabel(.search)
                        .onSubmit { search(text) }
                        .onChange(of: text) { updateSuggestions() }
                    if !text.isEmpty {
                        Button { text = ""; suggestions = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .padding()
                
                if !suggestions.isEmpty {
                    List(suggestions, id: \.self) { city in
                        Button { search(city) } label: {
                            HStack {
                                Image(systemName: "location.fill").foregroundStyle(.blue).font(.system(size: 14))
                                Text(city).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left").foregroundStyle(.secondary).font(.system(size: 12))
                            }
                        }
                    }.listStyle(.plain)
                } else if text.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(localized: "popular_cities"))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                        List(popularCities, id: \.self) { city in
                            Button { search(city) } label: {
                                HStack {
                                    Image(systemName: "star.fill").foregroundStyle(.orange).font(.system(size: 14))
                                    Text(city).foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }.listStyle(.plain)
                    }
                } else {
                    Spacer()
                    if let error = service.errorMessage {
                        Text(error).foregroundStyle(.red).padding()
                    }
                }
            }
            .navigationTitle(String(localized: "search_city"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "cancel")) { isPresented = false } }
            }
            .onAppear { focused = true }
        }
    }
    
    private func updateSuggestions() {
        guard !text.isEmpty else { suggestions = []; return }
        suggestions = popularCities.filter { $0.lowercased().contains(text.lowercased()) }
    }
    private func search(_ city: String) {
        guard !city.isEmpty else { return }
        service.fetchWeatherForCity(city)
        isPresented = false
    }
    
    // MARK: - Загрузка
    struct LoadingView: View {
        @State private var animate = false
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "cloud.sun.fill").font(.system(size: 60)).foregroundStyle(.white)
                    .scaleEffect(animate ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(), value: animate)
                Text(String(localized: "loading")).font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }
            .onAppear { animate = true }
        }
    }
    
    // MARK: - Приветствие
    struct WelcomeView: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill").font(.system(size: 70)).foregroundStyle(.white)
                Text(String(localized: "app_name")).font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                Text(String(localized: "allow_location"))
                    .font(.system(size: 17)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            }
        }
    }
}

#Preview { ContentView() }
