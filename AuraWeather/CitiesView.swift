//
//  CiriesView.swift
//  AuraWeather
//
//  Created by Rashid Shalbuzov on 28.05.26.
//

import SwiftUI

struct CitiesView: View {
    @ObservedObject var service: WeatherService
    @State private var showAddCity = false
    @State private var newCityText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                SkyBackgroundView(condition: service.weather?.weather.first?.main ?? "Clear")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if service.savedCities.isEmpty {
                        EmptyCitiesView()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                // Текущая геолокация
                                if let weather = service.weather {
                                    CurrentLocationCard(weather: weather)
                                }

                                // Сохранённые города
                                ForEach(service.savedCities) { city in
                                    CityCard(city: city)
                                        .onTapGesture {
                                            service.fetchWeatherForCity(city.name)
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "my_cities"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCity = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !service.savedCities.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showAddCity) {
                AddCitySheet(service: service, isPresented: $showAddCity)
            }
        }
    }
}

// MARK: - Карточка текущей геолокации
struct CurrentLocationCard: View {
    let weather: WeatherResponse

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(localized: "my_location"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(weather.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text(weather.weather.first?.description.capitalized ?? "")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(weather.main.temp))°")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("↑\(Int(weather.main.tempMax))°")
                    Text("↓\(Int(weather.main.tempMin))°")
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(20)
        .background(.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Карточка города
struct CityCard: View {
    let city: SavedCity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                if let weather = city.weather {
                    Text(weather.weather.first?.description.capitalized ?? "")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 8) {
                        Label("\(Int(weather.wind.speed)) м/с", systemImage: "wind")
                        Label("\(weather.main.humidity)%", systemImage: "humidity")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
                } else {
                    Text("Загрузка...")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let weather = city.weather {
                    Image(systemName: weatherIcon(for: weather.weather.first?.main ?? ""))
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(Int(weather.main.temp))°")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text("↑\(Int(weather.main.tempMax))°")
                        Text("↓\(Int(weather.main.tempMin))°")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Пустой список
struct EmptyCitiesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.5))
            Text(String(localized: "no_cities"))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
            Text(String(localized: "add_city_hint"))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }
}

// MARK: - Добавить город
struct AddCitySheet: View {
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
        "Тбилиси", "Ташкент", "Алматы", "Бишкек", "Астана",
        "Минск", "Киев", "Анкара", "Афины", "Будапешт"
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(String(localized: "city_name"), text: $text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { addCity(text) }
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
                        Button { addCity(city) } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.blue).font(.system(size: 14))
                                Text(city).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue).font(.system(size: 16))
                            }
                        }
                    }.listStyle(.plain)
                } else if text.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(localized: "popular_cities"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        List(popularCities, id: \.self) { city in
                            Button { addCity(city) } label: {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.orange).font(.system(size: 14))
                                    Text(city).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue).font(.system(size: 16))
                                }
                            }
                        }.listStyle(.plain)
                    }
                }

                Spacer()
            }
            .navigationTitle(String(localized: "add_city"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { isPresented = false }
                }
            }
        }
        .onAppear { focused = true }
    }

    func updateSuggestions() {
        guard !text.isEmpty else { suggestions = []; return }
        suggestions = popularCities.filter { $0.lowercased().contains(text.lowercased()) }
    }

    func addCity(_ city: String) {
        guard !city.isEmpty else { return }
        service.addCity(city)
        isPresented = false
    }
}
