#include <vector>
#include <string>
#include <functional>

class WeatherManager {
public:
    enum class WeatherState {
        SUNNY,
        RAINY,
        CLOUDY,
        STORMY
    };

    enum class DayPhase {
        DAWN,
        DAY,
        DUSK,
        NIGHT
    };

    static WeatherManager& getInstance() {
        static WeatherManager instance;
        return instance;
    }

    // Delete copy constructor and assignment operator
    WeatherManager(const WeatherManager&) = delete;
    WeatherManager& operator=(const WeatherManager&) = delete;

    using WeatherCallback = std::function<void(WeatherState, DayPhase)>;

    void subscribe(WeatherCallback callback) {
        observers.push_back(callback);
    }

    void setWeather(WeatherState newState) {
        currentWeather = newState;
        notifyObservers();
    }

    void updateDayPhase(DayPhase newPhase) {
        currentPhase = newPhase;
        notifyObservers();
    }

    WeatherState getCurrentWeather() const { return currentWeather; }
    DayPhase getCurrentPhase() const { return currentPhase; }

private:
    WeatherManager() : currentWeather(WeatherState::SUNNY), currentPhase(DayPhase::DAY) {}

    void notifyObservers() {
        for (const auto& observer : observers) {
            observer(currentWeather, currentPhase);
        }
    }

    WeatherState currentWeather;
    DayPhase currentPhase;
    std::vector<WeatherCallback> observers;
};