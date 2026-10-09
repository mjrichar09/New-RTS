#include <iostream>
#include <cmath>
#include <string>

class WeatherCondition {
public:
    float sunIntensity;    // 0.0 to 1.0
    float windSpeed;       // in m/s
    float temperature;     // in Celsius
    
    WeatherCondition(float sun, float wind, float temp)
        : sunIntensity(sun), windSpeed(wind), temperature(temp) {}
};

class TimeOfDay {
public:
    int hour;    // 0-23
    bool isDay() const { return hour >= 6 && hour <= 18; }
};

class SolarPanel {
private:
    float maxCapacity;    // in watts
    float efficiency;     // 0.0 to 1.0

public:
    SolarPanel(float capacity, float eff) : maxCapacity(capacity), efficiency(eff) {}

    float calculatePowerOutput(const WeatherCondition& weather, const TimeOfDay& time) {
        if (!time.isDay()) return 0.0f;
        
        float output = maxCapacity * efficiency * weather.sunIntensity;
        // Reduce efficiency if temperature is too high
        if (weather.temperature > 25.0f) {
            output *= (1.0f - (weather.temperature - 25.0f) * 0.005f);
        }
        return std::max(0.0f, output);
    }
};

class WindTurbine {
private:
    float maxCapacity;    // in watts
    float cutInSpeed;     // minimum wind speed needed
    float cutOutSpeed;    // maximum safe wind speed

public:
    WindTurbine(float capacity, float cutIn, float cutOut)
        : maxCapacity(capacity), cutInSpeed(cutIn), cutOutSpeed(cutOut) {}

    float calculatePowerOutput(const WeatherCondition& weather) {
        if (weather.windSpeed < cutInSpeed || weather.windSpeed > cutOutSpeed) {
            return 0.0f;
        }
        
        // Power output is proportional to cube of wind speed
        float output = maxCapacity * pow(weather.windSpeed / cutOutSpeed, 3);
        return std::min(output, maxCapacity);
    }
};

int main() {
    WeatherCondition weather(0.8f, 5.0f, 22.0f);
    TimeOfDay time{14};  // 2 PM
    
    SolarPanel solar(1000.0f, 0.20f);    // 1kW panel with 20% efficiency
    WindTurbine wind(2000.0f, 3.0f, 25.0f);  // 2kW turbine
    
    std::cout << "Solar Output: " << solar.calculatePowerOutput(weather, time) << " W\n";
    std::cout << "Wind Output: " << wind.calculatePowerOutput(weather) << " W\n";
    
    return 0;
}