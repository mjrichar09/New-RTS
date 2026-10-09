// RTS Game Class Hierarchy

#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Components/SceneComponent.h"

// Base RTS Actor
class MYRTS_API ARTSActor : public AActor
{
    GENERATED_BODY()

public:
    ARTSActor();

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaTime) override;
};

// RTS Unit Base Class
class MYRTS_API ARTSUnit : public ARTSActor
{
    GENERATED_BODY()

public:
    ARTSUnit();

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Unit")
    float Health;

    UPROPERTY(EditDefaultsOnly, Category = "Unit")
    float MovementSpeed;

    class UHealthComponent* HealthComponent;
    class UMovementComponent* MovementComponent;
};

// Unit Components
class MYRTS_API UHealthComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Health")
    void TakeDamage(float DamageAmount);

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Health")
    float MaxHealth;

    UPROPERTY(Replicated)
    float CurrentHealth;
};

// Building Base Class
class MYRTS_API ARTSBuilding : public ARTSActor
{
    GENERATED_BODY()

public:
    ARTSBuilding();

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Building")
    float ConstructionTime;

    UPROPERTY(EditDefaultsOnly, Category = "Building")
    bool bIsConstructed;
};

// Resource Base Class
class MYRTS_API ARTSResource : public ARTSActor
{
    GENERATED_BODY()

public:
    ARTSResource();

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Resource")
    int32 ResourceAmount;

    UPROPERTY(EditDefaultsOnly, Category = "Resource")
    FString ResourceType;
};