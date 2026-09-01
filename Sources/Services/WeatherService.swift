import Foundation
import SwiftUI
import Combine
import CoreLocation

public struct HourlyForecastItem: Identifiable, Sendable {
    public let id = UUID()
    public let timeString: String
    public let temp: Int
    public let iconName: String
    public let rainChance: Int
}

public struct WeatherData: Sendable {
    public let cityName: String
    public let temperature: Int
    public let conditionText: String
    public let iconName: String
    public let tintColor: Color
    public let highTemp: Int
    public let lowTemp: Int
    public let aqi: Int
    public let aqiText: String
    public let aqiColor: Color
    public let humidity: Int
    public let windSpeed: Int
    public let uvIndex: Int
    public let hourlyForecast: [HourlyForecastItem]
    public let isFahrenheit: Bool
    
    public static var fallback: WeatherData {
        WeatherData(
            cityName: "Cupertino",
            temperature: 72,
            conditionText: "Partly Cloudy",
            iconName: "cloud.sun.fill",
            tintColor: Color(red: 1.0, green: 0.75, blue: 0.25),
            highTemp: 76,
            lowTemp: 58,
            aqi: 28,
            aqiText: "Good",
            aqiColor: Color(red: 0.22, green: 0.85, blue: 0.42),
            humidity: 48,
            windSpeed: 8,
            uvIndex: 4,
            hourlyForecast: [
                HourlyForecastItem(timeString: "Now", temp: 72, iconName: "cloud.sun.fill", rainChance: 0),
                HourlyForecastItem(timeString: "4 PM", temp: 74, iconName: "sun.max.fill", rainChance: 0),
                HourlyForecastItem(timeString: "5 PM", temp: 73, iconName: "sun.max.fill", rainChance: 0),
                HourlyForecastItem(timeString: "6 PM", temp: 69, iconName: "cloud.sun.fill", rainChance: 10),
                HourlyForecastItem(timeString: "7 PM", temp: 65, iconName: "cloud.fill", rainChance: 20),
                HourlyForecastItem(timeString: "8 PM", temp: 62, iconName: "moon.stars.fill", rainChance: 5)
            ],
            isFahrenheit: true
        )
    }
}

/// Service managing ambient live weather & air quality telemetry via CoreLocation
public final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherService()
    
    @Published public private(set) var currentWeather: WeatherData = .fallback
    @Published public var isFahrenheit: Bool = true {
        didSet {
            UserDefaults.standard.set(isFahrenheit, forKey: "macbooknotch.weather.isFahrenheit")
            fetchWeather()
        }
    }
    
    public var onWeatherUpdated: ((WeatherData) -> Void)?
    
    private var currentCoords: (lat: Double, lon: Double)
    private var currentCityName: String
    private var refreshTimer: Timer?
    private let locationManager = CLLocationManager()
    
    private override init() {
        let storedF = UserDefaults.standard.object(forKey: "macbooknotch.weather.isFahrenheit") as? Bool ?? true
        self.isFahrenheit = storedF
        
        let savedLat = UserDefaults.standard.double(forKey: "macbooknotch.weather.savedLat")
        let savedLon = UserDefaults.standard.double(forKey: "macbooknotch.weather.savedLon")
        let savedCity = UserDefaults.standard.string(forKey: "macbooknotch.weather.savedCity") ?? "Cupertino"
        
        if savedLat != 0 && savedLon != 0 {
            self.currentCoords = (lat: savedLat, lon: savedLon)
            self.currentCityName = savedCity
        } else {
            self.currentCoords = (lat: 37.7749, lon: -122.4194)
            self.currentCityName = "San Francisco"
        }
        
        super.init()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Initial fetch
        fetchWeather()
        
        // Refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Stop updating to save battery, we only need it periodically
        manager.stopUpdatingLocation()
        
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            let city = placemarks?.first?.locality ?? "Current Location"
            
            DispatchQueue.main.async {
                self.currentCoords = (lat: lat, lon: lon)
                self.currentCityName = city
                UserDefaults.standard.set(lat, forKey: "macbooknotch.weather.savedLat")
                UserDefaults.standard.set(lon, forKey: "macbooknotch.weather.savedLon")
                UserDefaults.standard.set(city, forKey: "macbooknotch.weather.savedCity")
                self.fetchWeather()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error)")
    }
    
    public func fetchWeather() {
        let lat = currentCoords.lat
        let lon = currentCoords.lon
        let tempUnit = isFahrenheit ? "fahrenheit" : "celsius"
        let windUnit = isFahrenheit ? "mph" : "kmh"
        
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,uv_index&hourly=temperature_2m,precipitation_probability,weather_code&temperature_unit=\(tempUnit)&wind_speed_unit=\(windUnit)&forecast_hours=6") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let currentTemp = current["temperature_2m"] as? Double,
                   let weatherCode = current["weather_code"] as? Int {
                    
                    let humidity = Int(current["relative_humidity_2m"] as? Double ?? 50.0)
                    let wind = Int(current["wind_speed_10m"] as? Double ?? 10.0)
                    let uv = Int(current["uv_index"] as? Double ?? 3.0)
                    
                    let (condText, iconName, tint) = self.interpretWeatherCode(weatherCode)
                    
                    // Parse Hourly
                    var hourlyItems: [HourlyForecastItem] = []
                    if let hourly = json["hourly"] as? [String: Any],
                       let times = hourly["time"] as? [String],
                       let temps = hourly["temperature_2m"] as? [Double],
                       let codes = hourly["weather_code"] as? [Int],
                       let rains = hourly["precipitation_probability"] as? [Int] {
                        
                        let count = min(times.count, min(temps.count, codes.count))
                        for i in 0..<min(count, 6) {
                            let timeStr: String
                            if i == 0 {
                                timeStr = "Now"
                            } else {
                                let iso = times[i]
                                if let hourPart = iso.components(separatedBy: "T").last?.prefix(2),
                                   let hourInt = Int(hourPart) {
                                    let hour12 = hourInt == 0 ? 12 : (hourInt > 12 ? hourInt - 12 : hourInt)
                                    let amPm = hourInt >= 12 ? "PM" : "AM"
                                    timeStr = "\(hour12) \(amPm)"
                                } else {
                                    timeStr = "+\(i)h"
                                }
                            }
                            let itemIcon = self.interpretWeatherCode(codes[i]).icon
                            let rainP = rains.indices.contains(i) ? rains[i] : 0
                            hourlyItems.append(HourlyForecastItem(timeString: timeStr, temp: Int(round(temps[i])), iconName: itemIcon, rainChance: rainP))
                        }
                    }
                    
                    let high = hourlyItems.map { $0.temp }.max() ?? Int(round(currentTemp)) + 3
                    let low = hourlyItems.map { $0.temp }.min() ?? Int(round(currentTemp)) - 4
                    
                    let newWeather = WeatherData(
                        cityName: self.currentCityName,
                        temperature: Int(round(currentTemp)),
                        conditionText: condText,
                        iconName: iconName,
                        tintColor: tint,
                        highTemp: high,
                        lowTemp: low,
                        aqi: 24,
                        aqiText: "Good",
                        aqiColor: Color(red: 0.22, green: 0.85, blue: 0.42),
                        humidity: humidity,
                        windSpeed: wind,
                        uvIndex: uv,
                        hourlyForecast: hourlyItems.isEmpty ? WeatherData.fallback.hourlyForecast : hourlyItems,
                        isFahrenheit: self.isFahrenheit
                    )
                    
                    DispatchQueue.main.async {
                        self.currentWeather = newWeather
                        self.onWeatherUpdated?(newWeather)
                    }
                }
            } catch {
                // Parsing error fallback
            }
        }.resume()
    }
    
    private func interpretWeatherCode(_ code: Int) -> (text: String, icon: String, tint: Color) {
        switch code {
        case 0:
            return ("Clear", "sun.max.fill", Color(red: 1.0, green: 0.78, blue: 0.22))
        case 1, 2:
            return ("Partly Cloudy", "cloud.sun.fill", Color(red: 1.0, green: 0.75, blue: 0.35))
        case 3:
            return ("Overcast", "cloud.fill", Color(red: 0.75, green: 0.82, blue: 0.90))
        case 45, 48:
            return ("Foggy", "cloud.fog.fill", Color(red: 0.70, green: 0.78, blue: 0.85))
        case 51, 53, 55, 61, 63, 65:
            return ("Rain", "cloud.rain.fill", Color(red: 0.35, green: 0.72, blue: 1.0))
        case 71, 73, 75, 77, 85, 86:
            return ("Snow", "snowflake", Color(red: 0.80, green: 0.92, blue: 1.0))
        case 80, 81, 82:
            return ("Showers", "cloud.heavyrain.fill", Color(red: 0.30, green: 0.65, blue: 1.0))
        case 95, 96, 99:
            return ("Thunderstorm", "cloud.bolt.rain.fill", Color(red: 0.95, green: 0.65, blue: 0.25))
        default:
            return ("Fair", "cloud.sun.fill", Color(red: 1.0, green: 0.75, blue: 0.35))
        }
    }
}
