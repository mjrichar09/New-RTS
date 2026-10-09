#pragma once

#include "CoreMinimal.h"
#include "WeatherTypes.generated.h"

UENUM(BlueprintType)
enum class EWeatherType : uint8
{
    Clear       UMETA(DisplayName = "Clear"),
    Rain        UMETA(DisplayName = "Rain"),
    Snow        UMETA(DisplayName = "Snow"),
    Fog         UMETA(DisplayName = "Fog"),
    Storm       UMETA(DisplayName = "Storm")
};

// Delegate declaration for weather change events
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnWeatherChanged, EWeatherType, NewWeather, float, Intensity);