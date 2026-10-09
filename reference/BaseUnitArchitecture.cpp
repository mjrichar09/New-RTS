// RTSUnit.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "RTSUnit.generated.h"

UCLASS()
class RTSCORE_API ARTSUnit : public APawn
{
    GENERATED_BODY()

public:
    ARTSUnit();

    virtual void Tick(float DeltaTime) override;
    virtual void BeginPlay() override;

protected:
    // Core components
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "RTS|Components")
    class UHealthComponent* HealthComponent;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "RTS|Components")
    class USelectableComponent* SelectableComponent;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "RTS|Components")
    class UMovementComponent* MovementComponent;

    // Additional components
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "RTS|Components")
    class UWeatherSensitiveComponent* WeatherComponent;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "RTS|Components")
    class UVisionComponent* VisionComponent;

    // Mesh component
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "RTS|Components")
    class UStaticMeshComponent* MeshComponent;

public:
    // Getters for components
    FORCEINLINE UHealthComponent* GetHealthComponent() const { return HealthComponent; }
    FORCEINLINE USelectableComponent* GetSelectableComponent() const { return SelectableComponent; }
    FORCEINLINE UMovementComponent* GetMovementComponent() const { return MovementComponent; }
    FORCEINLINE UWeatherSensitiveComponent* GetWeatherComponent() const { return WeatherComponent; }
    FORCEINLINE UVisionComponent* GetVisionComponent() const { return VisionComponent; }
};