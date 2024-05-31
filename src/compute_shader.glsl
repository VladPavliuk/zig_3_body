#version 430

layout (local_size_x = 16, local_size_y = 1, local_size_z = 1) in;

layout (std430, binding = 0) readonly restrict buffer positionLayout {
    vec4 positions[];
};

layout (std430, binding = 1) restrict buffer speedLayout {
    vec4 speeds[];
};

layout (std430, binding = 2) readonly restrict buffer massLayout {
    float masses[];
};

layout(location = 2) uniform float deltaTime;

void main() 
{   
    // THREAD SAFE IMPLEMENTATION
    // uint aIndex = gl_WorkGroupID.x;

    // uint aIndex = gl_GlobalInvocationID.x;

    uint aIndex = gl_WorkGroupID.x * gl_WorkGroupSize.x + gl_LocalInvocationID.x;

    uint length = positions.length();

    vec3 aPosition = positions[aIndex].xyz;
    float aMass = masses[aIndex];
    float aMassInverted = 1.0f / aMass;

    for (int bIndex = 0; bIndex < length; bIndex++) {
        if (aIndex == bIndex) continue;

        vec3 bPosition = positions[bIndex].xyz;
        float bMass = masses[bIndex];
        float bMassInverted = 1.0f / bMass;

        vec3 delta = aPosition - bPosition;

        float distance = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z + 0.02f;
        float force = (0.01f * deltaTime * aMass * bMass) / distance;

        vec3 forceA = delta * force * aMassInverted;
        vec3 forceB = delta * force * bMassInverted;

        speeds[aIndex].x -= forceA.x;
        speeds[aIndex].y -= forceA.y;
        speeds[aIndex].z -= forceA.z;
    }

    // gl_GlobalInvocationID.x
    // uint aIndex = gl_WorkGroupID.x * gl_LocalInvocationID.x;
    // uint bIndex = gl_WorkGroupID.y * gl_LocalInvocationID.y;

    // uint aIndex = gl_GlobalInvocationID.x;
    // uint bIndex = gl_GlobalInvocationID.y;

    // if (aIndex == bIndex) return;

    // vec3 aPosition = positions[aIndex].xyz;
    // vec3 aSpeed = speeds[aIndex].xyz;
    // float aMass = masses[aIndex];
    // float aMassInverted = 1 / aMass;
    
    // vec3 bPosition = positions[bIndex].xyz;
    // vec3 bSpeed = speeds[bIndex].xyz;
    // float bMass = masses[bIndex];
    
    // vec3 delta = aPosition - bPosition;
    // float distance = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z + 0.02f;
    // float force = (0.001f * 0.033f * aMass * bMass) / distance;
    
    // vec3 forceA = delta * force * aMassInverted;

    // // barrier(CLK_GLOBAL_MEM_FENCE);

    // // atomicAdd(&speeds[aIndex].x, -forceA.x);
    // // atomicAdd(&speeds[aIndex].y, -forceA.y);
    // // atomicAdd(&speeds[aIndex].z, -forceA.z);
    // speeds[aIndex].x -= forceA.x;
    // speeds[aIndex].y -= forceA.y;
    // speeds[aIndex].z -= forceA.z;

    // speeds[aIndex].x *= 0.999;
    // speeds[aIndex].y *= 0.999;
    // speeds[aIndex].z *= 0.999;

    // SECOND IMPL

    //uint index = gl_LocalInvocationID.x;
    // uint index = gl_WorkGroupID.x;
    
    // uint length = positions.length();

    // uint aIndex = index;  
    // vec4 aPosition = positions[index];
    // float aMass = masses[index];
    // float aMassInverted = 1.0f / aMass;

    // index++;
    // while (index < length) {    
    //     vec4 bPosition = positions[index];
    //     float bMass = masses[index];
    //     float bMassInverted = 1.0f / bMass;

    //     vec3 delta = aPosition.xyz - bPosition.xyz;

    //     float distance = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z + 0.02f;
    //     float force = (0.001f * deltaTime * aMass * bMass) / distance;

    //     vec3 forceA = delta * force * aMassInverted;
    //     vec3 forceB = delta * force * bMassInverted;

    //     speeds[aIndex].x -= forceA.x;
    //     speeds[aIndex].y -= forceA.y;
    //     speeds[aIndex].z -= forceA.z;

    //     speeds[index].x += forceB.x;
    //     speeds[index].y += forceB.y;
    //     speeds[index].z += forceB.z;

    //     index++;
    // }
}