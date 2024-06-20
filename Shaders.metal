//
//  Shaders.metal
//  MetalStart
//
//  Created by Peter Vine on 05/06/2024.
//

#include <metal_stdlib>
#include "Loki/loki_header.metal"
using namespace metal;
#define Pi 3.1415926535

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

Agent moveAgent(Agent agent) {
    
    agent.position.x += agent.velocity * sin(agent.angle);
    agent.position.y -= agent.velocity * cos(agent.angle);

    return agent;
}

Agent collisionAgent(Agent agent, int width, int height) {
    
    Loki randomizer = Loki(agent.angle, agent.position.x, agent.position.y);

    
    if (agent.position.y > height) {
        agent.position.y = height;
        agent.angle = Pi / 2 - randomizer.rand() * Pi;

        
        
    } else if (agent.position.y < 0){
        agent.position.y = 0;
        agent.angle = Pi / 2 + randomizer.rand() * Pi;

    }
    
    if (agent.position.x < 0) {
        agent.position.x = 0;
        agent.angle = randomizer.rand() * Pi;

        
        
    } else if (agent.position.x > width){
        agent.position.x = width;
        agent.angle = Pi + randomizer.rand() * Pi;

    }
    
    return agent;
}

Agent agentPoint(Agent agent, AgentData data, texture2d<half, access::read> texture, float3 agentColour) {
    
    float probeStrengths[3];
    float probeAngles[3] = {agent.angle, agent.angle - data.sensorAngle, agent.angle + data.sensorAngle};
    
    
    for (int i = 0; i < 3; i++) {
        
        uint2 probePosition = {uint(agent.position.x + data.sensorDistance * sin(probeAngles[i])),
                               uint(agent.position.y - data.sensorDistance * cos(probeAngles[i]))};
        
        float colourScore;
            
            
            
        if (probePosition.x > uint(data.width) || probePosition.x == 0 || probePosition.y > uint(data.height) || probePosition.y == 0) {
            
            colourScore = -INFINITY;

        } else {
            
            half3 pixel = texture.read(probePosition).rgb;
            
            colourScore = -sqrt(pow(pixel.r - agentColour.r, 2) +
                                pow(pixel.g - agentColour.g, 2) +
                                pow(pixel.b - agentColour.b, 2));
            
        }
        
        
        probeStrengths[i] = colourScore;
        
    }

    Loki randomizer = Loki(agent.position.x, agent.angle, probeStrengths[0]);
    
    if (probeStrengths[0] == -INFINITY && probeStrengths[1] == -INFINITY && probeStrengths[2] == -INFINITY ) {
        agent.angle += (randomizer.rand() - 0.5) * 2 * data.maxTurn;
    } else if (probeStrengths[0] > probeStrengths[1] && probeStrengths[0] > probeStrengths[2]) {
        agent.angle += 0;
    } else if (probeStrengths[0] < probeStrengths[1] && probeStrengths[0] < probeStrengths[2]) {
        agent.angle += (randomizer.rand() - 0.5) * 2 * data.maxTurn;
    } else if (probeStrengths[1] > probeStrengths[2]) {
        agent.angle -= randomizer.rand() * data.maxTurn;
        
    } else if (probeStrengths[1] < probeStrengths[2]) {
        agent.angle += randomizer.rand() * data.maxTurn;
        
    }
    
    return agent;
}

kernel void calculateAgent(device Agent* agents,
                           device float3* species,
                           constant AgentData &data[[buffer(1)]],
                           texture2d<half, access::read>  prevText  [[texture(0)]],
                           texture2d<half, access::write> newText   [[texture(1)]],
                           uint index [[thread_position_in_grid]]) {
    Agent agent = agents[index];
    float3 agentColour = species[agent.index % data.numberSpecies];
    
    int height = newText.get_height();
    int width = newText.get_width();
    
    
    agent = agentPoint(agent, data, prevText, agentColour);
    agent = collisionAgent(agent, width, height);
    agent = moveAgent(agent);
    
    
    half4 colour = half4(half3(agentColour), 1.0);
    newText.write(colour, uint2(agent.position));
    agents[index] = agent;
}





kernel void blurReduceBright(texture2d<half, access::read>  prevFrame  [[texture(0)]],
                             texture2d<half, access::read>  unblurredText  [[texture(1)]],
                             texture2d<half, access::write> blurredText   [[texture(2)]],
                             uint2 position [[thread_position_in_grid]]) {
    float reduceAmount = 0.004;
    
    
    
    half4 originalColour = max(unblurredText.read(position), prevFrame.read(position));
    
    
    int size = 3;
    half4 addedBright = 0;
    for (int i = -1; i < size -1; i++) {
        for (int j = -1; j < size -1; j++) {
            
            addedBright += min(1, prevFrame.read(position + uint2(i, j)) + unblurredText.read(position + uint2(i, j)));
        }
        
    }
    
    half4 average = addedBright / 9;
    
    float diffusionSpeed = 0.2;
    half4 diffused = mix(originalColour, average, diffusionSpeed);
    
    
    half4 colour = max(0, diffused - reduceAmount);
    colour = min(colour, 1);
    
 
    blurredText.write(colour, position);
}
