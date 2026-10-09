// YourGameName.h - Primary game module header
#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

class FYourGameNameModule : public IModuleInterface
{
public:
    virtual void StartupModule() override;
    virtual void ShutdownModule() override;
};

// In YourGameName.Build.cs
public class YourGameName : ModuleRules
{
    public YourGameName(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        
        PublicDependencyModuleNames.AddRange(new string[] { 
            "Core", 
            "CoreUObject", 
            "Engine"
        });

        PrivateDependencyModuleNames.AddRange(new string[] {
            "YourGameCore",    // Your custom core module
            "YourGameUI"       // Your custom UI module
        });
    }
}

// Example custom module header - YourGameCore.h
#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleInterface.h"

class FYourGameCoreModule : public IModuleInterface
{
public:
    virtual void StartupModule() override;
    virtual void ShutdownModule() override;
};