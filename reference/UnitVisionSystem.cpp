#include "UnitVisionSystem.h"
#include <cmath>
#include <algorithm>
#include <limits>
#include <memory>

namespace RTS {
namespace Vision {

// TeamVision implementation
TeamVision::TeamVision(TeamID id) : teamId(id) {}

void TeamVision::addChunkVision(std::shared_ptr<VisionChunk> chunk) {
    if (chunk) {
        teamChunks.push_back(chunk);
    }
}

void TeamVision::removeChunkVision(const VisionChunk* chunk) {
    teamChunks.erase(
        std::remove_if(teamChunks.begin(), teamChunks.end(),
            [chunk](const std::shared_ptr<VisionChunk>& ptr) {
                return ptr.get() == chunk;
            }),
        teamChunks.end()
    );
}

void TeamVision::updateTeamVision() {
    // Clean up any expired chunks
    teamChunks.erase(
        std::remove_if(teamChunks.begin(), teamChunks.end(),
            [](const std::shared_ptr<VisionChunk>& chunk) {
                return chunk->getState() == VisionChunk::VisibilityState::UNEXPLORED;
            }),
        teamChunks.end()
    );
}

// VisionChunk implementation
VisionChunk::VisionChunk()
    : currentState(VisibilityState::UNEXPLORED)
    , visibilityFactor(0.0f)
    , lastUpdateTime(0.0f)
{
}

void VisionChunk::updateVisibility(VisibilityState newState) {
    currentState = newState;
    switch (newState) {
        case VisibilityState::VISIBLE:
            visibilityFactor = 1.0f;
            break;
        case VisibilityState::PREVIOUSLY_SEEN:
            visibilityFactor = 0.5f;
            break;
        case VisibilityState::UNEXPLORED:
            visibilityFactor = 0.0f;
            break;
    }
}

// FogOfWarSystem implementation
FogOfWarSystem::FogOfWarSystem(int mapWidth, int mapHeight) {
    const int chunksX = (mapWidth + Constants::MAP_CHUNK_SIZE - 1) / Constants::MAP_CHUNK_SIZE;
    const int chunksY = (mapHeight + Constants::MAP_CHUNK_SIZE - 1) / Constants::MAP_CHUNK_SIZE;
    
    mapChunks.resize(chunksX, std::vector<MapChunk>(chunksY));
    visibilityMask.resize(chunksX, std::vector<bool>(chunksY, false));
}

float FogOfWarSystem::calculateVisibilityRange(
    const VisionCapabilities& unit,
    const Weather::WeatherData& weather) const 
{
    float baseRange = unit.baseLineOfSight;
    float weatherMod = calculateWeatherFactor(weather);
    float timeMod = calculateTimeOfDayFactor(weather);
    
    float finalVisibility = baseRange * weatherMod * timeMod;
    
    // Apply special vision capabilities
    if (unit.hasNightVision && !weather.isDay) {
        finalVisibility *= 1.5f;
    }
    
    if (unit.hasFogLights && weather.cloudCover > 0.8f) {
        finalVisibility *= 1.3f;
    }
    
    if (unit.hasInfraredVision) {
        finalVisibility *= 1.2f;
    }
    
    // Apply elevation bonus
    finalVisibility += unit.elevationBonus;
    
    return std::max(finalVisibility, Constants::MIN_VISIBILITY);
}

float FogOfWarSystem::calculateWeatherFactor(const Weather::WeatherData& weather) const {
    float factor = 1.0f;
    
    // Reduce visibility based on precipitation
    if (weather.precipitation > 0.0f) {
        factor *= 1.0f - (weather.precipitation * 0.1f);
    }
    
    // Reduce visibility based on cloud cover
    if (weather.cloudCover > 0.5f) {
        factor *= 1.0f - ((weather.cloudCover - 0.5f) * 0.4f);
    }
    
    // Significant reduction in heavy fog
    if (weather.cloudCover > 0.9f) {
        factor *= 0.5f;
    }
    
    return std::max(0.3f, factor);
}

float FogOfWarSystem::calculateTimeOfDayFactor(const Weather::WeatherData& weather) const {
    if (weather.isDay) {
        return 1.0f;
    }
    
    // Reduced visibility at night
    return 0.6f;
}

float FogOfWarSystem::calculateElevationBonus(float observerHeight, float targetHeight) const {
    float heightDiff = observerHeight - targetHeight;
    if (heightDiff <= 0) return 0.0f;
    
    // Square root scaling for elevation bonus
    return std::sqrt(heightDiff) * 5.0f;
}

bool FogOfWarSystem::hasLineOfSight(float startX, float startY, float endX, float endY) const {
    // Bresenham's line algorithm for LOS checking
    int x1 = static_cast<int>(startX / Constants::MAP_CHUNK_SIZE);
    int y1 = static_cast<int>(startY / Constants::MAP_CHUNK_SIZE);
    int x2 = static_cast<int>(endX / Constants::MAP_CHUNK_SIZE);
    int y2 = static_cast<int>(endY / Constants::MAP_CHUNK_SIZE);
    
    int dx = std::abs(x2 - x1);
    int dy = std::abs(y2 - y1);
    int x = x1;
    int y = y1;
    
    int stepX = (x1 < x2) ? 1 : -1;
    int stepY = (y1 < y2) ? 1 : -1;
    int error = dx - dy;
    
    while (x != x2 || y != y2) {
        if (x < 0 || x >= mapChunks.size() || y < 0 || y >= mapChunks[0].size()) {
            return false;
        }
        
        if (mapChunks[x][y].blocksVision) {
            return false;
        }
        
        int error2 = error * 2;
        if (error2 > -dy) {
            error -= dy;
            x += stepX;
        }
        if (error2 < dx) {
            error += dx;
            y += stepY;
        }
    }
    
    return true;
}



void FogOfWarSystem::registerTeam(TeamID team) {
    if (teams.find(team.id) == teams.end()) {
        teams[team.id] = std::make_unique<TeamVision>(team);
    }
}

void FogOfWarSystem::unregisterTeam(TeamID team) {
    teams.erase(team.id);
    // Remove from vision sharing
    visionSharing.erase(
        std::remove_if(visionSharing.begin(), visionSharing.end(),
            [team](const auto& pair) {
                return pair.first.id == team.id || pair.second.id == team.id;
            }),
        visionSharing.end());
}

bool FogOfWarSystem::hasTeamVision(TeamID team, int x, int y) const {
    if (x < 0 || x >= mapChunks.size() || y < 0 || y >= mapChunks[0].size()) {
        return false;
    }

    // Check direct team vision
    auto it = teams.find(team.id);
    if (it != teams.end() && it->second->hasVisionAt(x, y)) {
        return true;
    }

    // Check shared vision
    for (const auto& sharing : visionSharing) {
        if (sharing.second.id == team.id) {
            auto sourceTeam = teams.find(sharing.first.id);
            if (sourceTeam != teams.end() && sourceTeam->second->hasVisionAt(x, y)) {
                return true;
            }
        }
    }

    return false;
}

void FogOfWarSystem::shareVision(TeamID fromTeam, TeamID toTeam, bool share) {
    if (share) {
        visionSharing.emplace_back(fromTeam, toTeam);
    } else {
        visionSharing.erase(
            std::remove_if(visionSharing.begin(), visionSharing.end(),
                [fromTeam, toTeam](const auto& pair) {
                    return pair.first.id == fromTeam.id && pair.second.id == toTeam.id;
                }),
            visionSharing.end());
    }
}

void FogOfWarSystem::updateVision(float x, float y, float z, const VisionCapabilities& observer) {
    int chunkX = static_cast<int>(x / Constants::MAP_CHUNK_SIZE);
    int chunkY = static_cast<int>(y / Constants::MAP_CHUNK_SIZE);
    
    if (chunkX < 0 || chunkX >= mapChunks.size() || 
        chunkY < 0 || chunkY >= mapChunks[0].size()) {
        return;
    }
    
    // Calculate vision range in chunks
    float range = observer.baseLineOfSight / Constants::MAP_CHUNK_SIZE;
    range += observer.elevationBonus / Constants::MAP_CHUNK_SIZE;
    
    calculateVisibilityMask(x, y, range);
    
    // Update chunk visibility states
    int rangeInt = static_cast<int>(std::ceil(range));
    for (int dx = -rangeInt; dx <= rangeInt; ++dx) {
        for (int dy = -rangeInt; dy <= rangeInt; ++dy) {
            int targetX = chunkX + dx;
            int targetY = chunkY + dy;
            
            if (targetX >= 0 && targetX < mapChunks.size() &&
                targetY >= 0 && targetY < mapChunks[0].size() &&
                visibilityMask[targetX][targetY]) {
                updateChunkVisibility(targetX, targetY, VisionChunk::VisibilityState::VISIBLE);
            }
        }
    }
}

void FogOfWarSystem::updateChunkVisibility(int x, int y, VisionChunk::VisibilityState state) {
    auto& chunk = mapChunks[x][y];
    
    // Update vision for all teams that can see this chunk
    for (auto& teamVision : chunk.teamVision) {
        int teamId = teamVision.first;
        std::shared_ptr<VisionChunk>& visionChunk = teamVision.second;
        
        if (visionChunk) {
            visionChunk->updateVisibility(state);
            
            // Update teams that share vision
            for (const auto& sharing : visionSharing) {
                if (sharing.first == teamId) {
                    auto it = chunk.teamVision.find(sharing.second);
                    if (it != chunk.teamVision.end() && it->second) {
                        it->second->updateVisibility(state);
                    }
                }
            }
        }
    }
}

} // namespace Vision
} // namespace RTS