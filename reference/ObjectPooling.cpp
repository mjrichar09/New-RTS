#include <vector>
#include <queue>
#include <memory>

// Forward declaration
class WeatherObject;

class ObjectPool {
public:
    static const int MAX_POOL_SIZE = 1000;

    // Initialize pool with default size
    ObjectPool(int initialSize = 100) {
        for (int i = 0; i < initialSize; i++) {
            WeatherObject* obj = createNewObject();
            if (obj) {
                availableObjects.push(obj);
            }
        }
    }

    ~ObjectPool() {
        while (!availableObjects.empty()) {
            delete availableObjects.front();
            availableObjects.pop();
        }
        
        for (auto obj : activeObjects) {
            delete obj;
        }
        activeObjects.clear();
    }

    // Get object from pool
    WeatherObject* acquireObject() {
        WeatherObject* obj = nullptr;
        
        if (availableObjects.empty() && activeObjects.size() < MAX_POOL_SIZE) {
            obj = createNewObject();
        } else if (!availableObjects.empty()) {
            obj = availableObjects.front();
            availableObjects.pop();
        }

        if (obj) {
            activeObjects.push_back(obj);
        }
        return obj;
    }

    // Return object to pool
    void releaseObject(WeatherObject* obj) {
        if (!obj) return;

        auto it = std::find(activeObjects.begin(), activeObjects.end(), obj);
        if (it != activeObjects.end()) {
            activeObjects.erase(it);
            obj->reset();  // Reset object state
            availableObjects.push(obj);
        }
    }

private:
    WeatherObject* createNewObject() {
        return new WeatherObject();  // Replace with your weather object implementation
    }

    std::queue<WeatherObject*> availableObjects;
    std::vector<WeatherObject*> activeObjects;
};

// Example weather object class
class WeatherObject {
public:
    WeatherObject() : active(false), lifetime(0.0f) {}
    
    void reset() {
        active = false;
        lifetime = 0.0f;
        position = {0.0f, 0.0f, 0.0f};
    }

    // Add your weather object properties and methods
    bool active;
    float lifetime;
    struct {
        float x, y, z;
    } position;
};