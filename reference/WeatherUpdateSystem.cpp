#include <vector>
#include <unordered_map>

class WeatherSystem {
private:
    struct Area {
        int id;
        bool isActive;
        std::vector<Unit*> units;
        WeatherEffect currentWeather;
    };

    std::unordered_map<int, Area> areas;
    
public:
    enum class WeatherEffect {
        CLEAR,
        RAIN,
        SNOW,
        STORM
    };

    // Add unit to specific area
    void registerUnit(Unit* unit, int areaId) {
        if (areas.count(areaId)) {
            areas[areaId].units.push_back(unit);
        }
    }

    // Set area active/inactive
    void setAreaActive(int areaId, bool active) {
        if (areas.count(areaId)) {
            areas[areaId].isActive = active;
        }
    }

    // Update weather effects only for active areas
    void update(float deltaTime) {
        for (auto& [id, area] : areas) {
            if (area.isActive) {
                for (Unit* unit : area.units) {
                    applyWeatherEffect(unit, area.currentWeather, deltaTime);
                }
            }
        }
    }

private:
    void applyWeatherEffect(Unit* unit, WeatherEffect weather, float deltaTime) {
        switch (weather) {
            case WeatherEffect::RAIN:
                unit->applySpeedModifier(0.8f);
                break;
            case WeatherEffect::SNOW:
                unit->applySpeedModifier(0.6f);
                unit->applyDamageOverTime(1.0f * deltaTime);
                break;
            case WeatherEffect::STORM:
                unit->applySpeedModifier(0.4f);
                unit->applyDamageOverTime(2.0f * deltaTime);
                break;
            default:
                unit->resetModifiers();
                break;
        }
    }
};