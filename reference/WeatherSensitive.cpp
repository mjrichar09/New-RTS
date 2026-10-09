// WeatherSensitiveComponent.h

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "WeatherSensitiveComponent.generated.h"

/**
 * Struct containing weather effect modifiers and vulnerability flags for units
 * Defines how different weather conditions affect unit performance and capabilities
 */
USTRUCT(BlueprintType)
struct FWeatherEffectData
{
    GENERATED_BODY()

    // Movement speed modifier in different weather conditions
    /** Movement speed multiplier during rain (0.8 = 20% slower) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather Effects", Meta = (ClampMin = "0.0", ClampMax = "2.0", ToolTip = "Movement speed multiplier in rain"))
    float SpeedModifierInRain = 0.8f;

    /** Movement speed multiplier during snow (0.6 = 40% slower) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather Effects", Meta = (ClampMin = "0.0", ClampMax = "2.0", ToolTip = "Movement speed multiplier in snow"))
    float SpeedModifierInSnow = 0.6f;

    // Combat effectiveness modifiers
    /** Accuracy multiplier during foggy conditions (0.7 = 30% reduced accuracy) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather Effects", Meta = (ClampMin = "0.0", ClampMax = "1.0", ToolTip = "Accuracy multiplier in fog"))
    float AccuracyModifierInFog = 0.7f;

    /** Damage multiplier during storms (0.9 = 10% reduced damage) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather Effects", Meta = (ClampMin = "0.0", ClampMax = "1.0", ToolTip = "Damage multiplier in storms"))
    float DamageModifierInStorm = 0.9f;

    // Vulnerability flags
    /** If true, unit takes additional damage during storms due to lightning strikes */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather Effects", Meta = (ToolTip = "Whether the unit is vulnerable to lightning damage"))
    bool bVulnerableToLightning = false;

    /** If true, unit has reduced performance in heavy rain and flood conditions */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather Effects", Meta = (ToolTip = "Whether the unit is vulnerable to flooding effects"))
    bool bVulnerableToFlooding = false;
};

/**
 * Component that makes an actor sensitive to weather conditions
 * Handles the modification of unit attributes based on current weather
 * Can be attached to any actor that needs to react to weather changes
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class WEATHERSYSTEM_API UWeatherSensitiveComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    /** Constructor for the weather sensitive component */
    UWeatherSensitiveComponent();

    /** 
     * Configuration data for weather effects on this unit
     * Contains modifiers for speed, accuracy, and damage, plus vulnerability flags
     */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Weather", Meta = (ToolTip = "Weather effect configuration data"))
    FWeatherEffectData WeatherEffects;

    // Apply weather effects to the unit
    UFUNCTION(BlueprintCallable, Category = "Weather")
    float GetSpeedModifier(EWeatherType CurrentWeather) const;

    UFUNCTION(BlueprintCallable, Category = "Weather")
    float GetCombatModifier(EWeatherType CurrentWeather) const;

protected:
    /** 
     * Called when the game starts or when spawned
     * Initializes the component and registers with the weather system
     */
    virtual void BeginPlay() override;
    
private:
    /** Current speed modification factor applied to the unit */
    float CurrentSpeedModifier = 1.0f;

    /** Current combat effectiveness modification factor applied to the unit */
    float CurrentCombatModifier = 1.0f;

    /**
     * Calculates the movement speed modifier based on current weather conditions
     * @param CurrentWeather - The current weather type affecting the unit
     * @return float - Movement speed multiplier (1.0 = normal speed, <1.0 = slower, >1.0 = faster)
     * 
     * Modification factors:
     * - Rain: Uses SpeedModifierInRain
     * - Snow: Uses SpeedModifierInSnow
     * - Storm: Combines rain and snow effects with additional penalty
     * - Fog: Slight speed reduction
     * - Clear: No modification (1.0)
     */
    float GetSpeedModifier(EWeatherType CurrentWeather) const
    {
        switch (CurrentWeather)
        {
            case EWeatherType::Rain:
                return WeatherEffects.SpeedModifierInRain;
            case EWeatherType::Snow:
                return WeatherEffects.SpeedModifierInSnow;
            case EWeatherType::Storm:
                return FMath::Min(WeatherEffects.SpeedModifierInRain, WeatherEffects.SpeedModifierInSnow) * 0.8f; // Additional penalty in storms
            case EWeatherType::Fog:
                return 0.9f; // Slight speed reduction in fog
            default: // Clear weather
                return 1.0f;
        }
    }

    /**
     * Calculates the combat effectiveness modifier based on current weather conditions
     * @param CurrentWeather - The current weather type affecting the unit
     * @return float - Combat effectiveness multiplier (1.0 = normal, <1.0 = reduced effectiveness)
     * 
     * Modification factors:
     * - Fog: Reduces accuracy based on AccuracyModifierInFog
     * - Storm: Applies DamageModifierInStorm with additional penalty for lightning-vulnerable units
     * - Rain: Reduces effectiveness for flood-vulnerable units
     * - Snow: General combat penalty
     * 
     * Special considerations:
     * - Lightning vulnerability adds 30% additional penalty in storms
     * - Flooding vulnerability adds 15% penalty in rain
     */
    float GetCombatModifier(EWeatherType CurrentWeather) const
    {
        float BaseCombatMod = 1.0f;

        switch (CurrentWeather)
        {
            case EWeatherType::Fog:
                BaseCombatMod = WeatherEffects.AccuracyModifierInFog;
                break;
            case EWeatherType::Storm:
                BaseCombatMod = WeatherEffects.DamageModifierInStorm;
                // Additional damage if vulnerable to lightning
                if (WeatherEffects.bVulnerableToLightning)
                {
                    BaseCombatMod *= 0.7f;
                }
                break;
            case EWeatherType::Rain:
                // Reduced combat effectiveness if vulnerable to flooding
                if (WeatherEffects.bVulnerableToFlooding)
                {
                    BaseCombatMod *= 0.85f;
                }
                break;
            case EWeatherType::Snow:
                BaseCombatMod *= 0.9f; // General combat penalty in snow
                break;
        }

        return BaseCombatMod;
    }
};