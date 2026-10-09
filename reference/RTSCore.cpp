// RTSGame.Build.cs
using UnrealBuildTool;

public class RTSGame : ModuleRules
{
    public RTSGame(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] 
        { 
            "Core",
            "CoreUObject", 
            "Engine",
            "InputCore",
            "RTSCore",
            "WeatherSystem",
            "GameplaySystems"
        });

        PrivateDependencyModuleNames.AddRange(new string[] 
        {
        });
    }
}

// RTSCore.Build.cs
public class RTSCore : ModuleRules
{
    public RTSCore(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] 
        { 
            "Core",
            "CoreUObject", 
            "Engine",
            "InputCore"
        });
    }
}

// WeatherSystem.Build.cs
public class WeatherSystem : ModuleRules
{
    public WeatherSystem(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] 
        { 
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

        PublicDependencyModuleNames.AddRange(new string[] 
        { 
            "Core",
            "CoreUObject", 
            "Engine",
            "RTSCore",
            "WeatherSystem"
        });
    }
}