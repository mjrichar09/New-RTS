#include <unordered_map>
#include <string>
#include <memory>

// Weather conditions enum
enum class WeatherType {
    CLEAR,
    RAIN,
    SNOW,
    FOG,
    STORM
};

// Struct to hold modification values
struct WeatherModifiers {
    float movementSpeedMod;
    float visibilityRangeMod;
    float combatEffectivenessMod;
    
    WeatherModifiers(float speed = 1.0f, float vision = 1.0f, float combat = 1.0f)
        : movementSpeedMod(speed), visibilityRangeMod(vision), combatEffectivenessMod(combat) {}
};

// Unit type enum
enum class UnitType {
    INFANTRY,
    VEHICLE,
    AIRCRAFT
};

class Unit {
private:
    UnitType type;
    float baseMovementSpeed;
    float baseVisibilityRange;
    float baseCombatEffectiveness;
    WeatherModifiers currentModifiers;

public:
    Unit(UnitType unitType, float speed, float visibility, float combat)
        : type(unitType), 
          baseMovementSpeed(speed),
          baseVisibilityRange(visibility),
          baseCombatEffectiveness(combat),
          currentModifiers() {}

    void applyWeatherEffects(const WeatherModifiers& mods) {
        currentModifiers = mods;
    }

    float getCurrentMovementSpeed() const {
        return baseMovementSpeed * currentModifiers.movementSpeedMod;
    }

    float getCurrentVisibility() const {
        return baseVisibilityRange * currentModifiers.visibilityRangeMod;
    }

    float getCurrentCombatEffectiveness() const {
        return baseCombatEffectiveness * currentModifiers.combatEffectivenessMod;
    }
};

class WeatherSystem {
private:
    std::unordered_map<WeatherType, std::unordered_map<UnitType, WeatherModifiers>> weatherEffects;
    WeatherType currentWeather;

public:
    WeatherSystem() : currentWeather(WeatherType::CLEAR) {
        // Configure default weather effects
        initializeWeatherEffects();
    }

    void initializeWeatherEffects() {
        // Example configuration
        weatherEffects[WeatherType::RAIN] = {
            {UnitType::INFANTRY, WeatherModifiers(0.8f, 0.7f, 0.9f)},
            {UnitType::VEHICLE, WeatherModifiers(0.9f, 0.8f, 0.95f)},
            {UnitType::AIRCRAFT, WeatherModifiers(0.7f, 0.6f, 0.8f)}
        };
        // Add more weather configurations as needed
    }

    void setWeather(WeatherType weather) {
        currentWeather = weather;
    }

    void applyWeatherEffects(Unit& unit, UnitType type) {
        auto& modifiers = weatherEffects[currentWeather][type];
        unit.applyWeatherEffects(modifiers);
    }

    void configureWeatherEffect(WeatherType weather, UnitType unitType, const WeatherModifiers& mods) {
        weatherEffects[weather][unitType] = mods;
    }
};