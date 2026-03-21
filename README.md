# Aura Weather

Aura Weather is a beautiful, modern weather application for iOS built with SwiftUI. It provides a visually rich experience with dynamic backgrounds and particle animations that change based on the current weather conditions and time of day.

## Features

- **Dynamic UI:** The background gradient and particle effects adapt to the weather (clear, clouds, rain, snow) and the time of day (morning, day, evening, night).
- **Current Weather:** Get instant access to the current temperature, weather description, and high/low for the day.
- **Detailed Information:** View supplementary data such as "feels like" temperature, humidity, and wind speed.
- **5-Day Forecast:** Plan ahead with a summarized forecast for the next five days.
- **In-Depth Daily View:** Tap on a day in the forecast to see a detailed view, including a comfort index, atmospheric conditions, and an hourly temperature breakdown.
- **Location-Based & Search:** Automatically fetches weather for your current location or allows you to search for any city worldwide.
- **Animated Effects:** Includes smooth animations for rain, snow, and twinkling stars to create an immersive "aura" for the current weather.

## Technical Stack

- **Framework:** SwiftUI
- **Language:** Swift
- **Concurrency:** `async/await` for modern, clean asynchronous network calls.
- **Location:** CoreLocation for fetching the user's geographical coordinates.
- **Networking:** `URLSession` to communicate with the weather API.
- **API:** [OpenWeatherMap](https://openweathermap.org/) for weather and forecast data.

## Architecture

The app follows a modern SwiftUI architecture, with the logic and UI clearly separated.

-   **`WeatherService.swift`**: An `ObservableObject` that acts as the single source of truth for all weather data. It is responsible for:
    -   Requesting location permissions and fetching coordinates via `CLLocationManager`.
    -   Making asynchronous API calls to OpenWeatherMap using `async/await`.
    -   Handling API responses, decoding JSON into the model objects, and managing loading/error states.
    -   Providing a fallback location if geolocation fails.

-   **`ContentView.swift`**: The main view of the application. It observes `WeatherService` and updates the UI whenever the weather data changes. It is composed of several specialized subviews:
    -   `SkyBackgroundView`: Renders the animated background gradient based on the weather and time.
    -   `ParticleSystemView`: Manages and animates the particle effects (rain, snow, stars).
    -   `MainWeatherView`: Displays the primary weather information (city, temperature, condition).
    -   `WeatherDetailsView`: A card showing details like humidity and wind.
    -   `ForecastView`: A list presenting the 5-day forecast.
    -   `SearchView`: A modal sheet for finding weather by city name.
    -   `ForecastDetailView`: A detailed modal sheet for a specific day's forecast.

-   **`WeatherModels.swift`**: Contains the `Codable` data structures that map directly to the JSON responses from the OpenWeatherMap API.

## Getting Started

To run this project locally, you will need an API key from OpenWeatherMap.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/rashidiic/AuraWeather.git
    cd AuraWeather
    ```

2.  **Get an API Key:**
    -   Sign up for a free account at [OpenWeatherMap](https://openweathermap.org/).
    -   Navigate to the "API keys" tab and get your key.

3.  **Add the API Key:**
    -   Open the project in Xcode.
    -   Navigate to the `WeatherService.swift` file.
    -   Replace the placeholder value of the `apiKey` constant with your own key:
        ```swift
        private let apiKey = "YOUR_API_KEY_HERE"
        ```

4.  **Build and Run:**
    -   Open `AuraWeather.xcodeproj` in Xcode.
    -   Select a simulator or a connected iOS device.
    -   Press the "Run" button (▶) to build and launch the application.
