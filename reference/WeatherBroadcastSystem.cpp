#include <vector>
#include <algorithm>  // for std::find

namespace RTS {
namespace Weather {

/**
 * Simple weather data structure
 */
struct WeatherData {
    float temperature;    // Temperature in Celsius
    float humidity;       // Relative humidity (0-100%)
    float windSpeed;      // Wind speed in meters per second
    
    WeatherData(float temp = 20.0f, float hum = 50.0f, float wind = 0.0f)
        : temperature(temp), humidity(hum), windSpeed(wind) {}
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
    WeatherSystem() : currentWeather(20.0f, 50.0f, 0.0f) {}

    void AddObserver(IWeatherObserver* observer) {
        if (observer) {
            observers.push_back(observer);
            observer->OnWeatherChanged(currentWeather);
        }
    }

    void RemoveObserver(IWeatherObserver* observer) {
        auto it = std::find(observers.begin(), observers.end(), observer);
        if (it != observers.end()) {
            observers.erase(it);
        }
    }

    void UpdateWeather(float temperature, float humidity, float windSpeed) {
        currentWeather = WeatherData(temperature, humidity, windSpeed);
        NotifyObservers();
    }

    const WeatherData& GetCurrentWeather() const {
        return currentWeather;
    }

private:
    void NotifyObservers() {
        for (auto* observer : observers) {
            if (observer) {
                observer->OnWeatherChanged(currentWeather);
            }
        }
    }
};

/**
 * Example implementation of a weather observer
 */
class WeatherSensitiveUnit : public IWeatherObserver {
public:
    explicit WeatherSensitiveUnit(WeatherSystem& weatherSystem) {
        weatherSystem.AddObserver(this);
    }

    void OnWeatherChanged(const WeatherData& weather) override {
        // Example of how a unit might respond to weather changes
        float speedModifier = 1.0f;
        
        // Reduce speed in adverse conditions
        if (weather.windSpeed > 10.0f) {
            speedModifier *= 0.8f;  // 20% slower in high winds
        }
        if (weather.humidity > 80.0f) {
            speedModifier *= 0.9f;  // 10% slower in high humidity
        }

        // Apply the modifier
        UpdateMovementSpeed(speedModifier);
    }

private:
    void UpdateMovementSpeed(float modifier) {
        // Implementation would update the unit's movement speed
    }
};

/**
 * Comprehensive weather data structure containing all relevant atmospheric conditions
 * Used to broadcast weather state changes to registered observers
 */
struct WeatherData {
    float temperature;    // Temperature in Celsius
    float humidity;       // Relative humidity (0-100%)
    float windSpeed;      // Wind speed in meters per second
    float visibility;     // Visibility range in meters
    float precipitation;  // Precipitation rate in mm/hour
    float pressure;       // Atmospheric pressure in hPa

    // Constructor with default values
    WeatherData(float temp = 20.0f, float hum = 50.0f, float wind = 0.0f,
                float vis = 10000.0f, float precip = 0.0f, float pres = 1013.25f)
        : temperature(temp), humidity(hum), windSpeed(wind)
        , visibility(vis), precipitation(precip), pressure(pres) {}

    // Utility method to get weather severity (0.0 - 1.0)
    float GetWeatherSeverity() const {
        float sevTemp = std::abs(temperature - 20.0f) / 30.0f;  // Deviation from comfortable temperature
        float sevWind = windSpeed / 30.0f;                      // Wind severity
        float sevVis = (10000.0f - visibility) / 10000.0f;     // Visibility reduction
        float sevPrec = precipitation / 50.0f;                  // Precipitation severity

        return std::min(1.0f, (sevTemp + sevWind + sevVis + sevPrec) / 4.0f);
    }

    // Get human-readable weather description
    std::string GetWeatherDescription() const {
        std::string description = "Current weather conditions:\\n";
        description += "Temperature: " + std::to_string(temperature) + "°C\\n";
        description += "Humidity: " + std::to_string(humidity) + "%\\n";
        description += "Wind Speed: " + std::to_string(windSpeed) + " m/s\\n";
        description += "Visibility: " + std::to_string(visibility) + " m\\n";
        description += "Precipitation: " + std::to_string(precipitation) + " mm/h\\n";
        description += "Pressure: " + std::to_string(pressure) + " hPa";
        return description;
    }
};

/**
 * Central weather management system that broadcasts weather changes to registered observers
 * Implements the Observer pattern for weather state distribution
 */
class WeatherSystem {
public:
    /** Delegate type for weather change notifications */
    using WeatherDelegate = std::function<void(const WeatherData&)>;

    /** Unique identifier for registered observers */
    using ObserverID = size_t;

private:
    /** List of registered weather observers with their IDs */
    std::vector<WeatherObserver*> observers;
    /** Current weather conditions */
    WeatherData currentWeather;
    /** Next available observer ID */
    ObserverID nextObserverID = 0;
    /** Weather update interval in seconds */
    float updateInterval = 300.0f; // 5 minutes
    /** Time since last weather update */
    float timeSinceLastUpdate = 0.0f;

public:
    /**
     * Register a new observer to receive weather updates
     * @param observer - Function to be called when weather changes
     * @return Unique identifier for the registered observer
     */
    void AddObserver(WeatherObserver* observer) {
        if (observer) {
            observers.push_back(observer);
            // Immediately notify new observer of current conditions
            observer->OnWeatherChanged(currentWeather);
        }
    }

    /**
     * Unregister an observer using its ID
     * @param id - The ID returned from AddObserver
     * @return true if observer was found and removed
     */
    void RemoveObserver(WeatherObserver* observer) {
        auto it = std::find(observers.begin(), observers.end(), observer);
        if (it != observers.end()) {
            observers.erase(it);
        }
    }

    /**
     * Update weather conditions with new values
     * @param temp - New temperature in Celsius
     * @param humidity - New relative humidity (0-100%)
     * @param wind - New wind speed in m/s
     * @param visibility - New visibility in meters
     * @param precipitation - New precipitation rate in mm/hour
     * @param pressure - New atmospheric pressure in hPa
     */
    void UpdateWeather(float temp, float humidity, float wind,
                      float visibility = 10000.0f, float precipitation = 0.0f,
                      float pressure = 1013.25f) {
        currentWeather = WeatherData(temp, humidity, wind, 
                                   visibility, precipitation, pressure);
        NotifyObservers();
    }

    /**
     * Get the current weather conditions
     * @return Current WeatherData
     */
    const WeatherData& GetCurrentWeather() const {
        return currentWeather;
    }

    /**
     * Update weather system with delta time
     * @param deltaTime - Time elapsed since last frame in seconds
     */
    void Tick(float deltaTime) {
        timeSinceLastUpdate += deltaTime;
        if (timeSinceLastUpdate >= updateInterval) {
            SimulateWeatherChanges();
            timeSinceLastUpdate = 0.0f;
        }
    }

    /**
     * Set the interval for automatic weather updates
     * @param interval - New interval in seconds
     */
    void SetUpdateInterval(float interval) {
        updateInterval = std::max(60.0f, interval); // Minimum 1 minute
    }

private:
    /**
     * Notify all registered observers of weather changes
     */
    void NotifyObservers() {
        for (WeatherObserver* observer : observers) {
            if (observer) {
            observer(currentWeather);
        }
    }

    /**
     * Simulate gradual weather changes based on current conditions
     * Called automatically at update intervals
     */
    void SimulateWeatherChanges() {
        // Gradually change weather conditions
        // Simple random weather changes using C-style random
        static bool seeded = false;
        if (!seeded) {
            srand(static_cast<unsigned>(time(nullptr)));
            seeded = true;
        }
        
        float randFloat = [](float min, float max) -> float {
            return min + (max - min) * (rand() / static_cast<float>(RAND_MAX));
        };
        
        currentWeather.temperature += randFloat(-0.5f, 0.5f);
        currentWeather.humidity += randFloat(-2.0f, 2.0f);
        currentWeather.windSpeed += randFloat(-0.5f, 0.5f);
        
        // Clamp values to realistic ranges
        currentWeather.humidity = std::min(100.0f, std::max(0.0f, currentWeather.humidity));
        currentWeather.windSpeed = std::max(0.0f, currentWeather.windSpeed);
        
        NotifyObservers();
    }
};

/**
 * Example weather-sensitive game object that reacts to weather changes
 */
class WeatherSensitiveObject {
public:
    WeatherSensitiveObject(WeatherSystem& weatherSys) {
        // Register for weather updates
        auto callback = std::bind(&WeatherSensitiveObject::OnWeatherChanged, this, std::placeholders::_1);
        observerID = weatherSys.AddObserver(callback);
    }

    ~WeatherSensitiveObject() {
        // Clean up observer if weather system still exists
        if (weatherSystem) {
            weatherSystem->RemoveObserver(observerID);
        }
    }

    /**
     * Handle weather change notifications
     * @param weather - New weather conditions
     */
    void OnWeatherChanged(const WeatherData& weather) {
        // Calculate performance modifiers based on weather
        float severityPenalty = 1.0f - weather.GetWeatherSeverity();
        
        // Apply movement speed modification
        float speedModifier = 1.0f;
        if (weather.precipitation > 0.0f) {
            speedModifier *= 0.8f; // 20% slower in rain
        }
        if (weather.visibility < 5000.0f) {
            speedModifier *= 0.9f; // 10% slower in poor visibility
        }
        
        // Apply the calculated modifiers
        UpdatePerformance(speedModifier, severityPenalty);
    }

private:
    WeatherSystem* weatherSystem = nullptr;
    WeatherSystem::ObserverID observerID;
    
    void UpdatePerformance(float speedMod, float effectivenessMod) {
        // Implementation would update the object's performance
        // based on the weather modifiers
    }
};