//
//  definitions.h
//  Slime
//
//  Created by Peter Vine on 13/06/2024.
//

#ifndef definitions_h
#define definitions_h


#endif /* definitions_h */

#include <simd/simd.h>




struct Vertex {
    
    vector_float2 position;
    vector_float2 textureCoord;

};

struct Agent {

    vector_float2 position;
    float angle;
    int index;
    
};

struct ShaderOptions {
    
    float reduceAmount;
    
    float diffusionAmount;
    
    float drawStrength;
    
    int maxBlurDistance;
    
};

struct Options {
    
    int numberAgents;
    int drawTrails;
    int paused;
    
    struct ShaderOptions shaderOptions;
    
    
};

struct AgentData {
    
    int numberSpecies;
    
    float maxTurn;
    float sensorAngle;
    float sensorDistance;
    int width;
    int height;
    float velocity;
    
    
};

