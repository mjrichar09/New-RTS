#include <cmath>
#include <ctime>

class Unit {
public:
    Unit(float baseSight = 100.0f) : baseLineOfSight(baseSight) {}
    float baseLineOfSight;
    bool hasNightVision = false;
    bool hasFogLights = false;
};

class FogOfWar {
private:
    float timeOfDayFactor;
    float weatherFactor;
    
    enum Weather {
        CLEAR,
        CLOUDY,
        RAIN,
        HEAVY_RAIN,
        FOG
    };

    enum TimeOfDay {
        DAWN,
        DAY,
        DUSK,
        NIGHT
    };

public:
    FogOfWar() : timeOfDayFactor(1.0f), weatherFactor(1.0f) {}

    float calculateVisibilityRange(const Unit& unit, Weather weather, TimeOfDay time) {
        updateWeatherFactor(weather);
        updateTimeOfDayFactor(time);
        
        float finalVisibility = unit.baseLineOfSight * weatherFactor * timeOfDayFactor;
        
        if (unit.hasNightVision && (time == NIGHT || time == DUSK || time == DAWN)) {
            finalVisibility *= 1.5f;
        }
        
        if (unit.hasFogLights && (weather == FOG || weather == HEAVY_RAIN)) {
            finalVisibility *= 1.3f;
        }

        return std::max(finalVisibility, 10.0f);
    }

private:
    // ... keep existing updateWeatherFactor and updateTimeOfDayFactor methods ...
};
