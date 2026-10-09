// Base interface for selectable units
class ISelectable {
public:
    virtual ~ISelectable() = default;
    virtual void select() = 0;
    virtual void deselect() = 0;
    virtual bool isSelected() const = 0;
};

// Interface for objects affected by weather
class IWeatherAffected {
public:
    virtual ~IWeatherAffected() = default;
    virtual void applyWeatherEffect(float temperature, float precipitation) = 0;
    virtual float getWeatherResistance() const = 0;
};

// Interface for power generating structures
class IPowerGenerator {
public:
    virtual ~IPowerGenerator() = default;
    virtual void startGenerating() = 0;
    virtual void stopGenerating() = 0;
    virtual float getCurrentOutput() const = 0;
    virtual float getMaxCapacity() const = 0;
};