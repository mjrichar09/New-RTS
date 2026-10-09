#include <string>
#include <iostream>

enum class WeatherType {
    Sunny,
    Cloudy,
    Rainy,
    Stormy,
    Snowy,
    Foggy,
    PartlyCloudy
};

enum class WindDirection {
    North,
    South,
    East,
    West,
    NorthEast,
    NorthWest,
    SouthEast,
    SouthWest
};

struct WeatherData {
    WeatherType type;
    double temperature;      // in Celsius
    double humidity;         // percentage
    double windSpeed;        // in km/h
    WindDirection windDir;
    double precipitation;    // in mm
    double pressure;        // in hPa

    // Serialization to string
    std::string serialize() const {
        return std::to_string(static_cast<int>(type)) + "," +
               std::to_string(temperature) + "," +
               std::to_string(humidity) + "," +
               std::to_string(windSpeed) + "," +
               std::to_string(static_cast<int>(windDir)) + "," +
               std::to_string(precipitation) + "," +
               std::to_string(pressure);
    }

    // Deserialization from string
    static WeatherData deserialize(const std::string& data) {
        WeatherData wd;
        size_t pos = 0;
        std::string token;
        int index = 0;
        std::string temp = data;

        while ((pos = temp.find(",")) != std::string::npos) {
            token = temp.substr(0, pos);
            switch (index) {
                case 0: wd.type = static_cast<WeatherType>(std::stoi(token)); break;
                case 1: wd.temperature = std::stod(token); break;
                case 2: wd.humidity = std::stod(token); break;
                case 3: wd.windSpeed = std::stod(token); break;
                case 4: wd.windDir = static_cast<WindDirection>(std::stoi(token)); break;
                case 5: wd.precipitation = std::stod(token); break;
            }
            temp.erase(0, pos + 1);
            index++;
        }
        wd.pressure = std::stod(temp);
        return wd;
    }
};