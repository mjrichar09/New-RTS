#pragma once

namespace RTS {
namespace Vision {

// Forward declarations
class VisionChunk;
class FogOfWarSystem;

/**
 * Represents a team in the game for vision sharing
 */
struct TeamID {
    int id;
    explicit TeamID(int teamId) : id(teamId) {}
    bool operator==(const TeamID& other) const { return id == other.id; }
    bool operator!=(const TeamID& other) const { return id != other.id; }
};

/**
 * Weather information relevant to vision calculations
 */
struct VisionWeatherInfo {
    float precipitation;   // Current precipitation level (0-1)
    float cloudCover;     // Cloud/fog density (0-1)
    bool isDay;           // Whether it's currently daytime
    float temperature;    // Current temperature

    VisionWeatherInfo()
        : precipitation(0.0f)
        , cloudCover(0.0f)
        , isDay(true)
        , temperature(20.0f)
    {}
};

/**
 * Capabilities affecting unit vision
 */
struct VisionCapabilities {
    float baseLineOfSight;   // Base vision range in game units
    bool hasNightVision;     // Ability to see better at night
    bool hasFogLights;       // Ability to see better in fog/rain
    bool hasInfraredVision;  // Can detect units through some obstacles
    float elevationBonus;    // Additional visibility from height
    
    VisionCapabilities(float sight = 100.0f)
        : baseLineOfSight(sight)
        , hasNightVision(false)
        , hasFogLights(false)
        , hasInfraredVision(false)
        , elevationBonus(0.0f)
    {}
};

} // namespace Vision
} // namespace RTS