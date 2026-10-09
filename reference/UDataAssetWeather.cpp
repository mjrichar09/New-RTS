// WeatherConfigDataAsset.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Sound/SoundCue.h"
#include "Particles/ParticleSystem.h"
#include "WeatherConfigDataAsset.generated.h"

USTRUCT(BlueprintType)
struct FWeatherGameplayModifiers
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather")
    float MovementSpeedMultiplier = 1.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather")
    float VisibilityRange = 10000.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather")
    float DamageMultiplier = 1.0f;
};

UCLASS(BlueprintType)
class YOUR_API_EXPORT UWeatherConfigDataAsset : public UDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|VFX")
    UParticleSystem* WeatherParticleSystem;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|VFX")
    float ParticleSpawnRate = 1.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|Audio")
    USoundCue* AmbientSound;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|Audio")
    float SoundVolume = 1.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|Gameplay")
    FWeatherGameplayModifiers GameplayModifiers;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|Settings")
    FString WeatherName;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Weather|Settings")
    float TransitionDuration = 2.0f;
};