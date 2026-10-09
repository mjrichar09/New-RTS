#pragma once

namespace RTS {
namespace Weather {

struct WeatherData {
    float temperature;    // Temperature in Celsius
    float windSpeed;      // Wind speed in m/s
    float precipitation;  // Precipitation amount (0-1)
    float cloudCover;     // Cloud cover amount (0-1)
    bool isDay;          // Whether it's daytime

    WeatherData()
        : temperature(20.0f)
        , windSpeed(0.0f)
        , precipitation(0.0f)
        , cloudCover(0.0f)
        , isDay(true)
    {}
};

} // namespace Weather
} // namespace RTS