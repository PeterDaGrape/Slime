//
//  Shaders.metal
//  MetalStart
//
//  Created by Peter Vine on 05/06/2024.
//

#include <metal_stdlib>
#include "Loki/loki_header.metal"
using namespace metal;
#define Pi 3.14159265358979323846

#include "definitions.h"

struct Fragment {
    
    float4 position [[position]];
    float2 textureCoord [[attribute(1)]];
    
    float4 colour;
};

vertex Fragment vertexShader(const device Vertex *vertexArray[[buffer(0)]], unsigned int vid [[vertex_id]]) {
    
    Vertex input = vertexArray[vid];
    
    Fragment output;
    output.textureCoord = input.textureCoord;
    output.position = float4(input.position.x, input.position.y, 0, 1);

    return output;
}

fragment float4 fragmentShader(Fragment input [[stage_in]], texture2d<float> newFrameTexture [[texture(0)]]) {
 
    constexpr sampler colourSampler(mip_filter::nearest, mag_filter::nearest, min_filter::nearest);

    float4 colour = newFrameTexture.sample(colourSampler, input.textureCoord);
   
    return colour;
}

Agent moveAgent(Agent agent, float velocity) {
    
    agent.position.x += velocity * sin(agent.angle);
    agent.position.y -= velocity * cos(agent.angle);

    return agent;
}

Agent collisionAgent(Agent agent, int width, int height) {
    
    Loki randomizer = Loki(agent.index, agent.position.x, agent.position.y);
    if (agent.position.y > height) {
        agent.position.y = randomizer.rand() * height;
        agent.angle = randomizer.rand() * 2 * Pi;

        
        
    } else if (agent.position.y < 0){
        agent.position.y = randomizer.rand() * height;
        agent.angle = randomizer.rand() * 2 * Pi;

    }
    
    if (agent.position.x < 0) {
        agent.position.x = randomizer.rand() * width;
        agent.angle = randomizer.rand() * 2 * Pi;

        
        
    } else if (agent.position.x > width){
        agent.position.x = randomizer.rand() * width;
        agent.angle = randomizer.rand() * 2 * Pi;

    }

    return agent;
}
Agent agentPoint(Agent agent, AgentData data, texture2d<half, access::read> texture, float3 agentColour) {
    
    float probeStrengths[3];
    float probeAngles[3] = {
        agent.angle,                        // Forward
        agent.angle - data.sensorAngle,     // Left
        agent.angle + data.sensorAngle      // Right
    };
    
    for (int i = 0; i < 3; i++) {
        float2 probePosition = {
            agent.position.x + data.sensorDistance * sin(probeAngles[i]),
            agent.position.y - data.sensorDistance * cos(probeAngles[i])
        };
        
        float colourScore;
        
        // Correct bounds checking
        if (probePosition.x >= texture.get_width() || probePosition.x < 0 ||
            probePosition.y >= texture.get_height() || probePosition.y < 0) {
            colourScore = 0;
        } else {
            half3 pixel = texture.read(uint2(probePosition)).rgb;
            colourScore = -sqrt(pow(pixel.r - agentColour.r, 2) +
                                pow(pixel.g - agentColour.g, 2) +
                                pow(pixel.b - agentColour.b, 2));
        }
        
        probeStrengths[i] = colourScore;
    }

    Loki randomizer = Loki(agent.position.x, agent.angle, probeStrengths[0]);
    
    // Find the index with the maximum probe strength
    int maxIndex = 0;
    float maxStrength = probeStrengths[0];
    for (int i = 1; i < 3; i++) {
        if (probeStrengths[i] > maxStrength) {
            maxStrength = probeStrengths[i];
            maxIndex = i;
        }
    }
    
    // Update the agent's angle based on the maximum probe strength
    if (maxStrength == -INFINITY) {
        // Random turn when no direction is attractive
        agent.angle += (randomizer.rand() - 0.5) * 2 * data.maxTurn;
    } else if (maxIndex == 0) {
        // Go straight
        agent.angle += 0;
    } else if (maxIndex == 1) {
        // Turn left
        agent.angle -= randomizer.rand() * data.maxTurn;
    } else if (maxIndex == 2) {
        // Turn right
        agent.angle += randomizer.rand() * data.maxTurn;
    }
    
    return agent;
}


kernel void calculateAgent(device Agent* agents,
                           device float3* species, //from buffer 2
                           constant AgentData &agentData[[buffer(1)]],
                           constant ShaderOptions &shaderOptions[[buffer(3)]],
                           texture2d<half, access::read>  prevText  [[texture(0)]],
                           texture2d<half, access::read_write> newText   [[texture(1)]],
                           uint index [[thread_position_in_grid]]) {
    
    
    Agent agent = agents[index];
    float3 agentColour = species[agent.index % agentData.numberSpecies];
    
    int height = newText.get_height();
    int width = newText.get_width();
    
    agent = agentPoint(agent, agentData, prevText, agentColour);
    agent = collisionAgent(agent, width, height);
    agent = moveAgent(agent, agentData.velocity);
    

    half4 colour =  prevText.read(uint2(agent.position)) + (1 - prevText.read(uint2(agent.position))) * half4(half3(agentColour), 1) * shaderOptions.drawStrength;
    
    //colour = half4(half3(agentColour), 1);
    
    newText.write(colour, uint2(agent.position));
    agents[index] = agent;
}

kernel void blurReduceBright(constant ShaderOptions &shaderOptions[[buffer(0)]],
                             texture2d<half, access::read>  prevFrame  [[texture(0)]],
                             texture2d<half, access::read>  unblurredText  [[texture(1)]],
                             texture2d<half, access::write> blurredText   [[texture(2)]],
                             uint2 position [[thread_position_in_grid]]) {
    
    float reduceAmount = shaderOptions.reduceAmount;
    
    half4 originalColour = max(unblurredText.read(position), prevFrame.read(position) - reduceAmount);
    
    
    int distance = shaderOptions.maxBlurDistance;
    int iterations = 0;
    half4 addedBright = 0;
    for (int i = -distance; i <= distance; i++) {
        for (int j = -distance; j <= distance; j++) {
            
            addedBright += max(prevFrame.read(position + uint2(i, j)) - reduceAmount, unblurredText.read(position + uint2(i, j)));
            iterations += 1;
            

        }
        
    }
    
    half4 average = addedBright / iterations;
    
    float diffusionSpeed = shaderOptions.diffusionAmount;
    half4 diffused = mix(originalColour, average, diffusionSpeed);
    
    
    half4 colour = max(0, diffused);
    colour = min(colour, 1);
    
    blurredText.write(colour, position);

}
