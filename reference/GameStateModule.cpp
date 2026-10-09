// RTSGameState.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameStateBase.h"
#include "RTSGameState.generated.h"

USTRUCT(BlueprintType)
struct FPlayerState
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadWrite, Category = "RTS")
    int32 Gold;

    UPROPERTY(BlueprintReadWrite, Category = "RTS")
    int32 Wood;

    UPROPERTY(BlueprintReadWrite, Category = "RTS")
    int32 Population;

    UPROPERTY(BlueprintReadWrite, Category = "RTS")
    int32 MaxPopulation;
};

UCLASS()
class YOURGAME_API ARTSGameState : public AGameStateBase
{
    GENERATED_BODY()

public:
    ARTSGameState();

    UFUNCTION(BlueprintCallable, Category = "RTS")
    void InitializePlayer(int32 PlayerID);

    UFUNCTION(BlueprintCallable, Category = "RTS")
    bool ModifyResource(int32 PlayerID, FString ResourceType, int32 Amount);

    UFUNCTION(BlueprintCallable, Category = "RTS")
    bool CheckWinCondition(int32 PlayerID);

protected:
    UPROPERTY(Replicated, BlueprintReadOnly, Category = "RTS")
    TMap<int32, FPlayerState> PlayerStates;

    UPROPERTY(Replicated, BlueprintReadOnly, Category = "RTS")
    bool bGameOver;

    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
};

// RTSGameState.cpp
#include "RTSGameState.h"
#include "Net/UnrealNetwork.h"

ARTSGameState::ARTSGameState()
{
    bGameOver = false;
}

void ARTSGameState::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    
    DOREPLIFETIME(ARTSGameState, PlayerStates);
    DOREPLIFETIME(ARTSGameState, bGameOver);
}

void ARTSGameState::InitializePlayer(int32 PlayerID)
{
    FPlayerState NewState;
    NewState.Gold = 1000;
    NewState.Wood = 500;
    NewState.Population = 0;
    NewState.MaxPopulation = 200;
    
    PlayerStates.Add(PlayerID, NewState);
}

bool ARTSGameState::ModifyResource(int32 PlayerID, FString ResourceType, int32 Amount)
{
    if (!PlayerStates.Contains(PlayerID))
        return false;

    FPlayerState& State = PlayerStates[PlayerID];
    
    if (ResourceType == "Gold")
    {
        if (State.Gold + Amount >= 0)
        {
            State.Gold += Amount;
            return true;
        }
    }
    else if (ResourceType == "Wood")
    {
        if (State.Wood + Amount >= 0)
        {
            State.Wood += Amount;
            return true;
        }
    }
    else if (ResourceType == "Population")
    {
        if (State.Population + Amount >= 0 && State.Population + Amount <= State.MaxPopulation)
        {
            State.Population += Amount;
            return true;
        }
    }
    
    return false;
}

bool ARTSGameState::CheckWinCondition(int32 PlayerID)
{
    // This is a basic implementation. You can modify the win conditions based on your game rules
    if (!PlayerStates.Contains(PlayerID))
        return false;

    // Example win condition: Player has accumulated 10000 gold
    return PlayerStates[PlayerID].Gold >= 10000;
}