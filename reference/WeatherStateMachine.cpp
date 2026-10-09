#include <iostream>
#include <random>
#include <chrono>
#include <map>

class WeatherStateMachine {
public:
    enum class Weather {
        Clear,
        Rain,
        Storm,
        Fog,
        Snow
    };

private:
    Weather currentWeather;
    std::mt19937 rng;
    int transitionTimer;
    const int minTransitionTime = 10;
    
    // Map to store transition probabilities: from -> (to -> probability)
    std::map<Weather, std::map<Weather, int>> transitionProbabilities;

public:
    WeatherStateMachine() : currentWeather(Weather::Clear), transitionTimer(0) {
        rng.seed(std::chrono::steady_clock::now().time_since_epoch().count());
        initializeDefaultProbabilities();
    }

    void setTransitionProbability(Weather from, Weather to, int probability) {
        if (probability >= 0 && probability <= 100) {
            transitionProbabilities[from][to] = probability;
        }
    }

    void update() {
        if (++transitionTimer < minTransitionTime) {
            return;
        }

        std::uniform_int_distribution<int> dist(0, 100);
        int chance = dist(rng);
        int cumulativeProbability = 0;

        for (const auto& transition : transitionProbabilities[currentWeather]) {
            cumulativeProbability += transition.second;
            if (chance < cumulativeProbability) {
                setWeather(transition.first);
                break;
            }
        }
    }

private:
    void initializeDefaultProbabilities() {
        // Clear weather transitions
        setTransitionProbability(Weather::Clear, Weather::Rain, 10);
        setTransitionProbability(Weather::Clear, Weather::Fog, 5);

        // Rain weather transitions
        setTransitionProbability(Weather::Rain, Weather::Clear, 20);
        setTransitionProbability(Weather::Rain, Weather::Storm, 10);

        // Storm weather transitions
        setTransitionProbability(Weather::Storm, Weather::Rain, 40);
        setTransitionProbability(Weather::Storm, Weather::Snow, 5);

        // Fog weather transitions
        setTransitionProbability(Weather::Fog, Weather::Clear, 30);
        setTransitionProbability(Weather::Fog, Weather::Rain, 10);

        // Snow weather transitions
        setTransitionProbability(Weather::Snow, Weather::Rain, 20);
        setTransitionProbability(Weather::Snow, Weather::Fog, 10);
    }

    // ... rest of the class implementation remains the same ...
};
