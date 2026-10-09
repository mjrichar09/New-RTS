#pragma once

#include "WeatherBroadcastSystem.h"
#include <vector>
#include <memory>

namespace RTS {
namespace Resources {

// Constants for resource production
namespace Constants {
    constexpr double BASE_WIND_EFFICIENCY = 0.7;
    constexpr double BASE_SOLAR_EFFICIENCY = 0.8;
    constexpr double BASE_HYDRO_EFFICIENCY = 0.9;
    constexpr double MAX_WIND_SPEED = 25.0;
    constexpr double MIN_WIND_SPEED = 3.0;
    constexpr double OPTIMAL_TEMPERATURE = 25.0;
}

/**
 * Enum defining different types of energy sources
 */
enum class EnergySourceType {
    WIND_TURBINE,    // Affected by wind speed
    SOLAR_ARRAY,     // Affected by cloud cover and time of day
    HYDRO_PLANT,     // Affected by rainfall and temperature
    GEOTHERMAL,      // Stable baseline power
    FUSION_PLANT,    // High output, weather independent
    COAL_PLANT       // Traditional power, slight weather impact
};

/**
 * Structure holding weather influence data for resource production
 */
struct WeatherInfluence {
    double temperature = 20.0;
    double windSpeed = 0.0;
    double precipitation = 0.0;
    double cloudCover = 0.0;
    bool isDay = true;

    static WeatherInfluence FromWeatherData(const Weather::WeatherData& weather);
};

/**
 * Abstract base class for all resource types
 */
class Resource {
protected:
    double amount;
    double capacity;
    double productionRate;
    double consumptionRate;
    bool isEnabled;
    
public:
    explicit Resource(double cap = 1000.0);
    virtual ~Resource() = default;
    
    virtual void update(double deltaTime) = 0;
    double getAmount() const { return amount; }
    double getCapacity() const { return capacity; }
    void addAmount(double value);
    void removeAmount(double value);
    bool hasAmount(double value) const { return amount >= value; }
};

/**
 * Energy resource management class
 */
class Energy : public Resource {
private:
    struct EnergySource {
        EnergySourceType type;
        double baseRate;
        double efficiency;
        bool operational;

        EnergySource(EnergySourceType t, double rate);
    };

    std::vector<EnergySource> energySources;
    WeatherInfluence currentWeather;

    double calculateSourceEfficiency(const EnergySource& source) const;
    double calculateWindEfficiency() const;
    double calculateSolarEfficiency() const;
    double calculateHydroEfficiency() const;

public:
    explicit Energy(double cap = 1000.0);
    void addEnergySource(EnergySourceType type, double baseRate);
    void updateWeatherConditions(const WeatherInfluence& weather);
    void update(double deltaTime) override;
};

/**
 * Ore resource management class
 */
class Ore : public Resource {
private:
    struct Deposit {
        double remainingAmount;
        double baseMiningRate;
        double currentEfficiency;
        bool isOpenPit;

        Deposit(double amount, double rate, bool openPit);
    };

    std::vector<Deposit> deposits;
    WeatherInfluence currentWeather;

    double calculateMiningEfficiency(const Deposit& deposit) const;

public:
    explicit Ore(double cap = 1000.0);
    void addDeposit(double amount, double rate, bool isOpenPit = true);
    void updateWeatherConditions(const WeatherInfluence& weather);
    void update(double deltaTime) override;
};

/**
 * Central resource management system
 */
class ResourceManager : public Weather::IWeatherObserver {
private:
    Energy energy;
    Ore ore;
    WeatherInfluence currentWeather;
    double globalEfficiencyModifier;

    void updateResourceEfficiencies();

public:
    ResourceManager();
    void OnWeatherChanged(const Weather::WeatherData& weather) override;
    void update(double deltaTime);
    Energy& getEnergy() { return energy; }
    Ore& getOre() { return ore; }
    void setGlobalEfficiencyModifier(double modifier);
};

} // namespace Resources
} // namespace RTS