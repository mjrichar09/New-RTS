// HealthComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "HealthComponent.generated.h"

UCLASS(ClassGroup=(RTS), meta=(BlueprintSpawnableComponent))
class GAME_API UHealthComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
    float MaxHealth = 100.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
    float CurrentHealth;

protected:
    virtual void BeginPlay() override;
};

// MovementComponent.h
UCLASS(ClassGroup=(RTS), meta=(BlueprintSpawnableComponent))
class GAME_API URTSMovementComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Movement")
    float MovementSpeed = 300.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Movement")
    float RotationRate = 90.0f;
};

// SelectionComponent.h
UCLASS(ClassGroup=(RTS), meta=(BlueprintSpawnableComponent))
class GAME_API USelectionComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Selection")
    bool bIsSelected = false;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Selection")
    UMaterialInterface* SelectionDecalMaterial;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Selection")
    float SelectionDecalSize = 100.0f;
};