#pragma once

#include "VisionTypes.h"
#include "WeatherTypes.h"

namespace RTS {
namespace Vision {

// Constants
constexpr int MAX_TEAMS = 16;
constexpr int MAX_CHUNKS_X = 64;
constexpr int MAX_CHUNKS_Y = 64;
constexpr int MAX_VISIONS_PER_CHUNK = 16;

namespace Constants {
    constexpr float MIN_VISIBILITY = 10.0f;
    constexpr float BASE_DAY_VISIBILITY = 100.0f;
    constexpr float BASE_NIGHT_VISIBILITY = 40.0f;
    constexpr int MAP_CHUNK_SIZE = 32;
    constexpr int MAX_MAP_SIZE = 256;
}

class VisionChunk {
public:
    enum class VisibilityState {
        UNEXPLORED,     // Never seen
        PREVIOUSLY_SEEN, // Seen before but not currently visible
        VISIBLE         // Currently visible
    };

    VisionChunk() : currentState(VisibilityState::UNEXPLORED), visibilityFactor(0.0f), lastUpdateTime(0.0f) {}
    
    void updateVisibility(VisibilityState newState) {
        currentState = newState;
        switch (newState) {
            case VisibilityState::VISIBLE: visibilityFactor = 1.0f; break;
            case VisibilityState::PREVIOUSLY_SEEN: visibilityFactor = 0.5f; break;
            case VisibilityState::UNEXPLORED: visibilityFactor = 0.0f; break;
        }
    }
    
    VisibilityState getState() const { return currentState; }
    float getVisibilityFactor() const { return visibilityFactor; }

private:
    VisibilityState currentState;
    float visibilityFactor;
    float lastUpdateTime;
};

// Forward declaration of TeamVision
class TeamVision;

/**
 * Manages the fog of war and visibility calculations
 */
class FogOfWarSystem {
public:
    // Team management
    void registerTeam(TeamID team);
    void unregisterTeam(TeamID team);
    bool hasTeamVision(TeamID team, int x, int y) const;
    void shareVision(TeamID fromTeam, TeamID toTeam, bool share);
    FogOfWarSystem(int mapWidth, int mapHeight);
    
    // Vision calculations
    float calculateVisibilityRange(const VisionCapabilities& unit, const VisionWeatherInfo& weather) const;
    bool isPositionVisible(float x, float y, float z) const;
    void updateVision(float x, float y, float z, const VisionCapabilities& observer);
    
    // Map queries
    bool hasLineOfSight(float startX, float startY, float endX, float endY) const;
    float getTerrainHeight(float x, float y) const;
    bool isTerrainBlockingVision(float x, float y) const;

private:
    struct TeamVisionData {
        VisionChunk* chunk;
        int teamId;
    };
    
    struct MapChunk {
        TeamVisionData visions[MAX_VISIONS_PER_CHUNK];
        int visionCount;
        float height;
        bool blocksVision;
        
        MapChunk() : visionCount(0), height(0.0f), blocksVision(false) {}
    };

    MapChunk mapChunks[MAX_CHUNKS_X][MAX_CHUNKS_Y];
    bool visibilityMask[MAX_CHUNKS_X][MAX_CHUNKS_Y];
    TeamVision* teams[MAX_TEAMS];
    int teamCount;
    
    struct VisionSharingPair {
        int fromTeam;
        int toTeam;
    };
    VisionSharingPair visionSharing[MAX_TEAMS * MAX_TEAMS];
    int visionSharingCount;
    
    // Helper methods
    void calculateVisibilityMask(float x, float y, float range);
    float calculateWeatherFactor(const VisionWeatherInfo& weather) const;
    float calculateTimeOfDayFactor(const VisionWeatherInfo& weather) const;
    float calculateElevationBonus(float observerHeight, float targetHeight) const;
    
    // Optimization methods
    void updateChunkVisibility(int x, int y, VisionChunk::VisibilityState newState);
    void cleanupStaleVision();
};

class TeamVision {
public:
    explicit TeamVision(TeamID id) : teamId(id), chunkCount(0) {}
    
    void addChunkVision(VisionChunk* chunk) {
        if (chunkCount < MAX_CHUNKS_X * MAX_CHUNKS_Y && chunk) {
            teamChunks[chunkCount++] = chunk;
        }
    }
    
    void removeChunkVision(const VisionChunk* chunk) {
        for (int i = 0; i < chunkCount; ++i) {
            if (teamChunks[i] == chunk) {
                if (i < chunkCount - 1) {
                    teamChunks[i] = teamChunks[chunkCount - 1];
                }
                --chunkCount;
                break;
            }
        }
    }
    
    void updateTeamVision() {
        // Clean up expired chunks
        int j = 0;
        for (int i = 0; i < chunkCount; ++i) {
            if (teamChunks[i] && teamChunks[i]->getState() != VisionChunk::VisibilityState::UNEXPLORED) {
                if (i != j) {
                    teamChunks[j] = teamChunks[i];
                }
                ++j;
            }
        }
        chunkCount = j;
    }
    
    bool hasVisionAt(int x, int y) const {
        for (int i = 0; i < chunkCount; ++i) {
            if (teamChunks[i] && teamChunks[i]->getState() == VisionChunk::VisibilityState::VISIBLE) {
                return true;
            }
        }
        return false;
    }

private:
    TeamID teamId;
    VisionChunk* teamChunks[MAX_CHUNKS_X * MAX_CHUNKS_Y];
    int chunkCount;
};

} // namespace Vision
} // namespace RTS