#pragma once

#include <vector>

namespace RTS {
namespace Weather {

/**
 * Simple weather data structure
 */
struct WeatherData {
    float temperature;    // Temperature in Celsius
    float humidity;       // Relative humidity (0-100%)
    float windSpeed;      // Wind speed in meters per second
    
    WeatherData(float temp = 20.0f, float hum = 50.0f, float wind = 0.0f);
};

/**
 * Interface for weather observers
 */
class IWeatherObserver {
public:
    virtual ~IWeatherObserver() = default;
    virtual void OnWeatherChanged(const WeatherData& weather) = 0;
};

/**
 * Weather system that manages weather state and notifications
 */
class WeatherSystem {
private:
    std::vector<IWeatherObserver*> observers;
    WeatherData currentWeather;

public:
    WeatherSystem();
    
    void AddObserver(IWeatherObserver* observer);
    void RemoveObserver(IWeatherObserver* observer);
    void UpdateWeather(float temperature, float humidity, float windSpeed);
    const WeatherData& GetCurrentWeather() const;

private:
    void NotifyObservers();
};

/**
 * Example implementation of a weather observer
 */
class WeatherSensitiveUnit : public IWeatherObserver {
public:
    explicit WeatherSensitiveUnit(WeatherSystem& weatherSystem);
    void OnWeatherChanged(const WeatherData& weather) override;

private:
    void UpdateMovementSpeed(float modifier);
};

} // namespace Weather
} // namespace RTS