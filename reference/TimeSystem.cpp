#include <cmath>
#include <algorithm>

class TimeOfDaySystem {
private:
    float currentTime; // Current time in hours (0-24)
    float dayLengthInSeconds; // Length of one full day in seconds
    float sunriseTime; // Hour when sunrise begins (0-24)
    float sunsetTime; // Hour when sunset begins (0-24)

public:
    TimeOfDaySystem(float dayLength = 1200.0f, float sunrise = 6.0f, float sunset = 18.0f) 
        : currentTime(12.0f), dayLengthInSeconds(dayLength), sunriseTime(sunrise), sunsetTime(sunset) {}

    void update(float deltaTime) {
        // Update current time
        currentTime += (deltaTime * 24.0f) / dayLengthInSeconds;
        if (currentTime >= 24.0f) {
            currentTime -= 24.0f;
        }
    }

    float getSunPosition() const {
        // Returns sun position in radians (0 = sunrise, π = sunset)
        return (currentTime - sunriseTime) * M_PI / (sunsetTime - sunriseTime);
    }

    float getLightIntensity() const {
        // Calculate light intensity (0.0 to 1.0)
        if (currentTime < sunriseTime || currentTime > sunsetTime) {
            return 0.0f; // Night time
        }

        float sunPos = getSunPosition();
        return std::max(0.0f, std::sin(sunPos));
    }

    float getCurrentTime() const { return currentTime; }
    bool isNight() const { return currentTime < sunriseTime || currentTime > sunsetTime; }
    bool isDay() const { return !isNight(); }
};