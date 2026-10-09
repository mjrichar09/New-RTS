// RTSCore.Build.cs
using UnrealBuildTool;

public class RTSCore : ModuleRules
{
    public RTSCore(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] {
            "Core",
            "CoreUObject",
            "Engine",
            "InputCore",
            "GameplayTags"
        });

        PrivateDependencyModuleNames.AddRange(new string[] {
            "Slate",
            "SlateCore",
            "UMG"
        });
    }
}

// WeatherSystem.Build.cs
public class WeatherSystem : ModuleRules
{
    public WeatherSystem(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] {
            "Core",
            "CoreUObject",
            "Engine",
            "RTSCore"
        });
    }
}

// GameplaySystems.Build.cs
public class GameplaySystems : ModuleRules
{
    public GameplaySystems(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] {
            "Core",
            "CoreUObject", 
            "Engine",
            "RTSCore",
            "WeatherSystem",
            "AIModule",
            "NavigationSystem"
        });

        PrivateDependencyModuleNames.AddRange(new string[] {
            "GameplayTasks",
            "GameplayAbilities"
        });
    }
}