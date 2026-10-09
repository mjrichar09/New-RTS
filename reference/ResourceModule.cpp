#include <string>
#i#includ#include "ResourceModule.h"

namespace RTS {
namespace Resources { "ResourceModule.h"
#include <cmath>
#include <algorithm>

namespace RTS {
namespace Resources {

using namespace Constants;clude <vector>
#include <map>
#include <cmath>
#include <algorithm>

// Forward declarations
class WeatherData;
class IWeatherObserver;

// Constants for resource production
namespace ResourceConstants {
    constexpr double BASE_WIND_EFFICIENCY = 0.7;
    constexpr double BASE_SOLAR_EFFICIENCY = 0.8;
    constexpr double BASE_HYDRO_EFFICIENCY = 0.9;
    constexpr double MAX_WIND_SPEED = 25.0;
    constexpr double MIN_WIND_SPEED = 3.0;
    constexpr double OPTIMAL_TEMPERATURE = 25.0;
}

/**
 * Enum defining different types of energy sources
 * Each type has unique characteristics and weather dependencies
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
    double temperature;
    double windSpeed;
    double precipitation;
    double cloudCover;
    bool isDay;

    WeatherInfluence()
        : temperature(20.0), windSpeed(0.0)
        , precipitation(0.0), cloudCover(0.0)
        , isDay(true) {}
};

/**
 * Abstract base class for all resource types
 * Provides common functionality for resource management
 */
class Resource {
protected:
    double amount;
    double capacity;
    double productionRate;
    double consumptionRate;
    bool isEnabled;
    
public:
    Resource(double cap = 1000.0)
        : amount(0.0), capacity(cap)
        , productionRate(0.0), consumptionRate(0.0)
        , isEnabled(true) {}
    
    virtual void update(float deltaTime) = 0;
    double getAmount() const { return amount; }
    double getCapacity() const { return capacity; }
    bool addAmount(double value) {
        if (amount + value <= capacity) {
            amount += value;
            return true;
        }
        return false;
    }
};

/**
 * Energy resource management class
 * Handles different energy sources and their weather-dependent production
 */
class Energy : public Resource {
private:
    struct EnergySource {
        EnergySourceType type;
        double baseRate;
        double efficiency;
        bool operational;

        EnergySource(EnergySourceType t, double rate)
            : type(t), baseRate(rate)
            , efficiency(1.0), operational(true) {}
    };

    std::vector<EnergySource> energySources;
    WeatherInfluence currentWeather;

public:
    Energy(double cap = 1000.0) : Resource(cap) {}
    
    void addEnergySource(EnergySourceType type, double baseRate) {
        energySources.emplace_back(type, baseRate);
    }

    void updateWeatherConditions(const WeatherInfluence& weather) {
        currentWeather = weather;
        // Update each source's efficiency based on weather
        for (auto& source : energySources) {
            source.efficiency = calculateSourceEfficiency(source);
        }
    }
    
    void update(float deltaTime) override {
        double totalProduction = 0.0;
        for (const auto& source : energySources) {
            if (source.operational) {
                totalProduction += source.baseRate * source.efficiency * deltaTime;
            }
        }
        addAmount(totalProduction);
    }

private:
    double calculateSourceEfficiency(const EnergySource& source) const {
        switch (source.type) {
            case EnergySourceType::WIND_TURBINE:
                return calculateWindEfficiency();
            case EnergySourceType::SOLAR_ARRAY:
                return calculateSolarEfficiency();
            case EnergySourceType::HYDRO_PLANT:
                return calculateHydroEfficiency();
            case EnergySourceType::GEOTHERMAL:
                return 0.95; // Very stable
            case EnergySourceType::FUSION_PLANT:
                return 1.0;  // Weather independent
            case EnergySourceType::COAL_PLANT:
                return 0.85 + (currentWeather.temperature > 25.0 ? -0.1 : 0.0); // Slight penalty in hot weather
            default:
                return 1.0;
        }
    }

    double calculateWindEfficiency() const {
        using namespace ResourceConstants;
        if (currentWeather.windSpeed < MIN_WIND_SPEED || currentWeather.windSpeed > MAX_WIND_SPEED) {
            return 0.0; // Too little or too much wind
        }
        // Optimal efficiency at 15 m/s wind speed
        double normalizedSpeed = (currentWeather.windSpeed - MIN_WIND_SPEED) / (15.0 - MIN_WIND_SPEED);
        return BASE_WIND_EFFICIENCY * std::pow(normalizedSpeed, 2) * (normalizedSpeed <= 1.0 ? 1.0 : (2.0 - normalizedSpeed));
    }

    double calculateSolarEfficiency() const {
        using namespace ResourceConstants;
        if (!currentWeather.isDay) return 0.0;
        
        double cloudPenalty = currentWeather.cloudCover * 0.8; // Up to 80% reduction from clouds
        double tempEffect = 1.0 - std::abs(currentWeather.temperature - OPTIMAL_TEMPERATURE) / 100.0;
        
        return BASE_SOLAR_EFFICIENCY * (1.0 - cloudPenalty) * tempEffect;
    }

    double calculateHydroEfficiency() const {
        using namespace ResourceConstants;
        // Increased efficiency with more precipitation
        double rainBonus = currentWeather.precipitation * 0.1; // 10% boost per mm/h of rain
        return BASE_HYDRO_EFFICIENCY * (1.0 + std::min(rainBonus, 0.5));
    }
    }
};

/**
 * Ore resource management class
 * Handles mining operations with weather-dependent efficiency
 */
class Ore : public Resource {
private:
    struct Deposit {
        double remainingAmount;
        double baseMiningRate;
        double currentEfficiency;
        bool isOpenPit;      // Open pit mines are more affected by weather

        Deposit(double amount, double rate, bool openPit = true)
            : remainingAmount(amount), baseMiningRate(rate)
            , currentEfficiency(1.0), isOpenPit(openPit) {}
    };

    std::vector<Deposit> deposits;
    WeatherInfluence currentWeather;

public:
    Ore(double cap = 1000.0) : Resource(cap) {}
    
    void addDeposit(double amount, double rate, bool isOpenPit = true) {
        deposits.emplace_back(amount, rate, isOpenPit);
    }

    void updateWeatherConditions(const WeatherInfluence& weather) {
        currentWeather = weather;
        // Update mining efficiency for each deposit
        for (auto& deposit : deposits) {
            deposit.currentEfficiency = calculateMiningEfficiency(deposit);
        }
    }
    
    void update(float deltaTime) override {
        for (auto& deposit : deposits) {
            if (deposit.remainingAmount > 0) {
                double effectiveRate = deposit.baseMiningRate * deposit.currentEfficiency;
                double mined = std::min(effectiveRate * deltaTime, deposit.remainingAmount);
                if (addAmount(mined)) {
                    deposit.remainingAmount -= mined;
                }
            }
        }
    }

private:
    double calculateMiningEfficiency(const Deposit& deposit) const {
        double efficiency = 1.0;
        
        if (deposit.isOpenPit) {
            // Open pit mines are affected more by weather
            if (currentWeather.precipitation > 0) {
                // Heavy rain reduces efficiency
                efficiency *= 1.0 - (currentWeather.precipitation * 0.1);
            }
            if (currentWeather.windSpeed > 15.0) {
                // Strong winds affect operations
                efficiency *= 0.8;
            }
        } else {
            // Underground mines are less affected
            if (currentWeather.precipitation > 10.0) {
                // Only very heavy rain affects underground operations
                efficiency *= 0.9;
            }
        }
        
        // Temperature affects worker efficiency
        if (std::abs(currentWeather.temperature - 20.0) > 15.0) {
            // Extreme temperatures reduce efficiency
            efficiency *= 0.9;
        }
        
        return std::max(0.3, efficiency); // Never drop below 30% efficiency
    }
    }
};

/**
 * Central resource management system
 * Coordinates all resource production and consumption with weather influences
 */
class ResourceManager : public IWeatherObserver {
private:
    Energy energy;
    Ore ore;
    WeatherInfluence currentWeather;
    double globalEfficiencyModifier;

public:
    ResourceManager()
        : energy(10000.0), ore(5000.0)
        , globalEfficiencyModifier(1.0) {}
    
    void OnWeatherChanged(const WeatherData& weather) override {
        // Convert WeatherData to WeatherInfluence
        WeatherInfluence influence;
        influence.temperature = weather.temperature;
        influence.windSpeed = weather.windSpeed;
        influence.precipitation = weather.precipitation;
        influence.cloudCover = weather.cloudCover;
        influence.isDay = weather.isDay;

        currentWeather = influence;
        updateResourceEfficiencies();
    }

    void update(float deltaTime) {
        energy.update(deltaTime);
        ore.update(deltaTime);
    }

    Energy& getEnergy() { return energy; }
    Ore& getOre() { return ore; }

    /**
     * Sets a global efficiency modifier for all resource production
     * Can be used for difficulty settings or special game events
     */
    void setGlobalEfficiencyModifier(double modifier) {
        globalEfficiencyModifier = std::clamp(modifier, 0.1, 2.0);
        updateResourceEfficiencies();
    }

private:
    void updateResourceEfficiencies() {
        energy.updateWeatherConditions(currentWeather);
        ore.updateWeatherConditions(currentWeather);
    }
};