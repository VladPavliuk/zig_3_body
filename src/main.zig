const std = @import("std");

const ArrayList = std.ArrayList;
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");

    @cDefine("RLIGHTS_IMPLEMENTATION", "1");
    @cInclude("rlights.h");

    // @cInclude("turn_on_integrated_gpu.h");

    // @cDefine("GRAPHICS_API_OPENGL_43", {});
    // @cDefine("RLGL_IMPLEMENTATION", {});
    // @cDefine("RLGL_SHOW_GL_DETAILS_INFO", {});
    // @cDefine("RLGL_ENABLE_OPENGL_DEBUG_CONTEXT", {});
    // @cInclude("external/glad.h");
    // @cInclude("rlgl.h");
});

const glad = @cImport({
    @cInclude("external/glad.h");
});

fn switchToFullScreen() void {
    const display = raylib.GetCurrentMonitor();
    const x = raylib.GetMonitorWidth(display);
    const y = raylib.GetMonitorHeight(display);

    raylib.ToggleBorderlessWindowed();
    raylib.SetWindowSize(x, y);
}

fn switchToWindowed(x: i32, y: i32) void {
    raylib.ToggleBorderlessWindowed();
    raylib.SetWindowSize(x, y);
}

const GravityObject = struct {
    transformation: raylib.Matrix, // only for shader
    position: @Vector(3, f32),
    speed: @Vector(3, f32),
    radius: f32,
    mass: f32,
    massInverse: f32,
    color: raylib.Vector3
};

const GpuData = struct {
    computeShaderId: c_uint,

    ssboPositionsId: c_uint,
    ssboPositionsBytesLength: c_uint,
    
    ssboSpeedsId: c_uint,
    ssboSpeedsBytesLength: c_uint,

    ssboMassesId: c_uint,
    ssboMassesBytesLength: c_uint,
    
    ssboColorsId: c_uint,
    ssboColorsBytesLength: c_uint,
};

fn generateObjects() !std.MultiArrayList(GravityObject) {
    var objects = std.MultiArrayList(GravityObject){};

    try objects.append(std.heap.c_allocator, .{
        .transformation = raylib.MatrixIdentity(),
        .position = @splat(0.0),
        .speed = @splat(0.0),
        .radius = 0.0,
        .mass = 400.0,
        .massInverse = 1.0 / 400.0,
        .color = .{ .x = 0.0, .y = 0.0, .z = 0.0 }
    });
    
    const objectsCount: i32 = 2048 - 1; // 16384

    //> circle
    const distanceFromCenter: f32 = 50.0;
    const anglePerObject: f32 = raylib.PI * 2.0 / objectsCount;

    for (0..objectsCount) |index| {
        const angle: f32 = @as(f32, @floatFromInt(index)) * anglePerObject;

        // const x: f32 = distanceFromCenter * raylib.cosf(angle) * raylib.sinf(angle);
        // const y: f32 = distanceFromCenter * raylib.sinf(angle) * raylib.sinf(angle);
        // const z: f32 = distanceFromCenter * raylib.cosf(angle);

        const x: f32 = distanceFromCenter * raylib.cosf(angle);
        const y: f32 = distanceFromCenter * raylib.sinf(angle);
        const z: f32 = 0.0;

        const speedAngle = angle + @as(f32, @floatCast(raylib.M_PI_2));

        const initSpeed = 0.05;
        const initSpeedX = initSpeed * raylib.cosf(speedAngle);
        const initSpeedY = initSpeed * raylib.sinf(speedAngle);

        try objects.append(std.heap.c_allocator, .{
            .transformation = raylib.MatrixIdentity(),
            .position = @Vector(3, f32) { x, y, z },
            .speed = @Vector(3, f32) { initSpeedX, initSpeedY, 0.0 },
            .radius = 0.0,
            .mass = 1.0,
            .massInverse = 1.0,
            .color = .{ .x = 0.0, .y = 0.0, .z = 0.0 }
        });    
    }
    //<

    //> grid
    // const size: f32 = 150.0;

    // const areaSize = size * size;

    // const ratio = raylib.sqrtf(areaSize / @as(f32, @floatFromInt(objectsCount)));

    // var y: f32 = -size / 2.0;
    // while (y < size / 2.0) : (y += ratio) {
    //     var x: f32 = -size / 2.0;
    //     while (x < size / 2.0) : (x += ratio) {
    //         try objects.append(std.heap.c_allocator, .{
    //             .transformation = raylib.MatrixIdentity(),
    //             .position = @Vector(3, f32) { x, y, 0.0 },
    //             .speed = @splat(0.0),
    //             .radius = 0.0,
    //             .mass = 1.0,
    //             .massInverse = 1.0
    //         });
    //     }
    // }
    //<

    // const radiusMultiplier = 1.0;
    
    for (objects.items(.radius), objects.items(.mass), objects.items(.transformation)) |*objectRadius, objectMass, *objectTransformation| {
        // objectRadius.* = radiusMultiplier * raylib.sqrtf(objectMass * 3 / (4 * raylib.PI));
        if (objectMass > 10.0) objectRadius.* = 3.0 else objectRadius.* = 0.5;

        objectTransformation.* = raylib.MatrixScale(objectRadius.*, objectRadius.*, objectRadius.*);
    }

    for (objects.items(.color)) |*color| {
        // const red: f32 = @as(f32, @floatFromInt(raylib.GetRandomValue(1, 255))) / 255.0;
        // const green: f32 = @as(f32, @floatFromInt(raylib.GetRandomValue(1, 255))) / 255.0;
        // const blue: f32 = @as(f32, @floatFromInt(raylib.GetRandomValue(1, 255))) / 255.0;
        
        const red: f32 = 1.0;
        const green: f32 = 1.0;
        const blue: f32 = 1.0;

        color.* = .{
            .x = red,
            .y = green,
            .z = blue,
        };
    }

    return objects;
}

fn simulateOnGPU(gpuData: GpuData, objects: std.MultiArrayList(GravityObject).Slice, deltaTime: f32) void {
    raylib.rlEnableShader(gpuData.computeShaderId);
    
    raylib.rlBindShaderBuffer(gpuData.ssboPositionsId, 0);
    raylib.rlBindShaderBuffer(gpuData.ssboSpeedsId, 1);
    raylib.rlBindShaderBuffer(gpuData.ssboMassesId, 2);

    raylib.rlUpdateShaderBuffer(gpuData.ssboSpeedsId, objects.items(.speed).ptr, gpuData.ssboSpeedsBytesLength, 0);
    raylib.rlUpdateShaderBuffer(gpuData.ssboPositionsId, objects.items(.position).ptr, gpuData.ssboPositionsBytesLength, 0);

    glad.glUniform1f(2, deltaTime);
    
    const groupsToDispatch = @divExact(@as(c_uint, @intCast(objects.items(.position).len)), 16);

    raylib.rlComputeShaderDispatch(groupsToDispatch, 1, 1);
    // glad.glMemoryBarrier(glad.GL_SHADER_STORAGE_BARRIER_BIT);
    // raylib.rlComputeShaderDispatch(1, 1, 1);
    raylib.rlReadShaderBuffer(gpuData.ssboSpeedsId, objects.items(.speed).ptr, gpuData.ssboSpeedsBytesLength, 0);

    raylib.rlDisableShader();
}

fn simulate(objects: std.MultiArrayList(GravityObject).Slice, deltaTime: f32) void {
    for (objects.items(.position), objects.items(.mass), objects.items(.massInverse), objects.items(.speed), 0..objects.len) 
        |aObjectPosition, aObjectMass, aObjectMassInverse, *aObjectSpeed, index| {
        for (objects.items(.position)[index + 1..objects.len], objects.items(.mass)[index + 1..objects.len], objects.items(.massInverse)[index+1..objects.len], objects.items(.speed)[index+1..objects.len]) 
            |bObjectPosition, bObjectMass, bObjectMassInverse, *bObjectSpeed| {

            const delta = aObjectPosition - bObjectPosition;

            const distance = delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2] + 0.02;

            const force = 0.001 * deltaTime * aObjectMass * bObjectMass / distance;

            const forceA: @Vector(3, f32) = @splat(force * aObjectMassInverse);
            const forceB: @Vector(3, f32) = @splat(force * bObjectMassInverse);
            
            aObjectSpeed.* -= delta * forceA; 
            bObjectSpeed.* += delta * forceB;
        }
    }
}

fn updateObjectsTransformation(objects: std.MultiArrayList(GravityObject).Slice) void {
    for (objects.items(.speed), objects.items(.position), objects.items(.transformation), objects.items(.radius)) 
        |*speed, *position, *transformation, radius| {
        position.* += speed.*;

        const objectScale = raylib.MatrixScale(radius, radius, radius);

        transformation.* = raylib.MatrixMultiply(
            objectScale,
            raylib.MatrixTranslate(position[0], position[1], position[2]));
    }
}

pub fn main() !void {
    const screenWidth = 1200;
    const screenHeight = 800;

    raylib.SetConfigFlags(raylib.FLAG_MSAA_4X_HINT);
    raylib.InitWindow(screenWidth, screenHeight, "3d objects");
    defer raylib.CloseWindow();
    //switchToFullScreen();
    raylib.SetTargetFPS(144);

    const cameraZoom: f32 = 150.0;
    // const cameraZoom: f32 = 60.0;
    const camera: raylib.Camera = .{ 
        .position = .{ .x = 0.0, .y = 50.0, .z = -200.0 },
        .target = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = cameraZoom,
        .projection = raylib.CAMERA_ORTHOGRAPHIC
    };

    // var objects2 = std.MultiArrayList(GravityObject){};

    // objects2.append(std.heap.c_allocator, .{
    //     //GravityObject
    // })

    var objects = try generateObjects();
    updateObjectsTransformation(objects.slice());
    defer objects.deinit(std.heap.c_allocator);

    //> Compute shader
    const positionsBytesLength = @as(c_uint, @intCast(objects.len * @sizeOf(@Vector(3, f32))));
    const speedsBytesLength = @as(c_uint, @intCast(objects.len * @sizeOf(@Vector(3, f32))));
    const massesBytesLength = @as(c_uint, @intCast(objects.len * @sizeOf(f32)));
    const colorsBytesLength = @as(c_uint, @intCast(objects.len * @sizeOf(raylib.Vector3)));

    const ssboPositions = raylib.rlLoadShaderBuffer(positionsBytesLength, 
        null, raylib.RL_DYNAMIC_COPY); // RL_DYNAMIC_READ
    defer raylib.rlUnloadShaderBuffer(ssboPositions);

    const ssboSpeeds = raylib.rlLoadShaderBuffer(speedsBytesLength, 
        null, raylib.RL_DYNAMIC_COPY);
    defer raylib.rlUnloadShaderBuffer(ssboSpeeds);

    const ssboMasses = raylib.rlLoadShaderBuffer(massesBytesLength, 
        objects.items(.mass).ptr, raylib.RL_DYNAMIC_COPY);
    defer raylib.rlUnloadShaderBuffer(ssboMasses);

    const ssboColors = raylib.rlLoadShaderBuffer(colorsBytesLength, 
        objects.items(.color).ptr, raylib.RL_DYNAMIC_COPY);
    defer raylib.rlUnloadShaderBuffer(ssboColors);

    const computeShaderSource = raylib.LoadFileText("compute_shader.glsl");
    const computeShaderShader = raylib.rlCompileShader(computeShaderSource, raylib.RL_COMPUTE_SHADER);
    const computeShaderProgram = raylib.rlLoadComputeShaderProgram(computeShaderShader);

    raylib.UnloadFileText(computeShaderSource);
    const gpuData: GpuData = .{
        .computeShaderId = computeShaderProgram,
        .ssboPositionsId = ssboPositions,
        .ssboPositionsBytesLength = positionsBytesLength,
        .ssboSpeedsId = ssboSpeeds,
        .ssboSpeedsBytesLength = speedsBytesLength,
        .ssboMassesId = ssboMasses,
        .ssboMassesBytesLength = massesBytesLength,
        .ssboColorsId = ssboColors,
        .ssboColorsBytesLength = colorsBytesLength,
    };

    // raylib.rlEnableShader(computeShaderProgram);
    // raylib.rlBindShaderBuffer(ssboPositions, 0);
    // raylib.rlComputeShaderDispatch(@as(c_uint, @intCast(objects.items(.position).len)), 1, 1);
    // raylib.rlDisableShader();

    // // var size: i64 = 0;
    // // glad.glGetBufferParameteri64v(glad.GL_SHADER_STORAGE_BUFFER, glad.GL_BUFFER_SIZE, &size);

    // raylib.rlReadShaderBuffer(ssboPositions, objects.items(.position).ptr, positionsLength, 0);
    
    //<

    //var model: raylib.Model = raylib.LoadModel("ball.glb");
    //raylib.LoadShaderFromMemory(vsCode: [*c]const u8, fsCode: [*c]const u8)
    const shader: raylib.Shader = raylib.LoadShader("lighting_instanced.vs", "lighting.fs");
    
    shader.locs[raylib.SHADER_LOC_MATRIX_MVP] = raylib.GetShaderLocation(shader, "mvp");
    shader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(shader, "viewPos");
    shader.locs[raylib.SHADER_LOC_MATRIX_MODEL] = raylib.GetShaderLocationAttrib(shader, "instanceTransform");

    const ambientLoc = raylib.GetShaderLocation(shader, "ambient");
    const test1: [4]f32 = .{ 0.1, 0.1, 0.1, 1.0 };
    raylib.SetShaderValue(shader, ambientLoc, test1[0..4], raylib.SHADER_UNIFORM_VEC4);

    const light: raylib.Light = raylib.CreateLight(raylib.LIGHT_DIRECTIONAL, 
        .{ .x = 20.0, .y = 0.0, .z = -0.0 }, raylib.Vector3Zero(), raylib.WHITE, shader);

    raylib.UpdateLightValues(shader, light);

    const sphereMesh = raylib.GenMeshSphere(1.0, 10, 15);
    var sphereMaterial = raylib.LoadMaterialDefault();

    sphereMaterial.shader = shader;
    sphereMaterial.maps[raylib.MATERIAL_MAP_DIFFUSE].color = raylib.WHITE;

    // const pitch: f32 = 0.0;
    // const roll: f32 = 0.0;
    // const yaw: f32 = 0.0;
    
    var firstObjectPosition = &objects.items(.position)[0];
    const firstObjectSpeed = &objects.items(.speed)[0];
    //const firstObjectTransformation = objects.items(.transformation)[0];

    //var firstObject = &objects.get(0);

    var stopSimulation = true;
    var isFullScreen = false;
    var stopWatchTotal: i64 = 0;
    var stopWatchCount: i64 = 1;
    var isGpuSimulation = true;
    while (!raylib.WindowShouldClose()) {
        const deltaTime = raylib.GetFrameTime();
        //if (deltaTime > 0.01) deltaTime = 0.01;

        // if (!raylib.IsWindowFullscreen())
        // {
        //     continue;
        // }
        //testObjectPosition1.position.x += raylib.GetFrameTime(); 
        //model.transform = raylib.MatrixRotateXYZ(.{ .x = raylib.DEG2RAD * pitch, .y = raylib.DEG2RAD * yaw, .z = raylib.DEG2RAD * roll });

        if (raylib.IsKeyReleased(raylib.KEY_SPACE)) {
            stopSimulation = !stopSimulation;
        }

        if (raylib.IsKeyReleased(raylib.KEY_F)) {
            isFullScreen = !isFullScreen;

            if (isFullScreen) {
                switchToFullScreen();
            } else {
                switchToWindowed(screenWidth, screenHeight);
            }
        }

        if (raylib.IsKeyReleased(raylib.KEY_G)) {
            isGpuSimulation = !isGpuSimulation;
        }

        if (raylib.IsKeyDown(raylib.KEY_LEFT_CONTROL)) {
            const mousePosition = raylib.GetMousePosition();

            const currentScreenWidth: f32 = @floatFromInt(raylib.GetScreenWidth());
            const currentScreenHeight: f32 = @floatFromInt(raylib.GetScreenHeight());

            // TODO: WEIRD PROJECTION NUMBERS???
            const xProjected = -(cameraZoom * 1.5) * mousePosition.x / currentScreenWidth + (cameraZoom * 0.75);
            const yProjected = -(cameraZoom * 1.5) * (currentScreenHeight / currentScreenWidth) * mousePosition.y / currentScreenHeight + (cameraZoom/2.0);

            firstObjectPosition[0] = xProjected;
            firstObjectPosition[1] = yProjected;
            firstObjectSpeed.* = @splat(0.0);
        }
       
        // raylib.rlUpdateShaderBuffer(ssboSpeeds, objects.items(.speed).ptr, speedsBytesLength, 0);
        // raylib.rlUpdateShaderBuffer(ssboPositions, objects.items(.position).ptr, positionsBytesLength, 0);

        // raylib.rlEnableShader(computeShaderProgram);
        // glad.glUniform1f(2, deltaTime);
        
        // raylib.rlBindShaderBuffer(ssboPositions, 0);
        // raylib.rlBindShaderBuffer(ssboSpeeds, 1);
        // raylib.rlBindShaderBuffer(ssboMasses, 2);
        
        // raylib.rlComputeShaderDispatch(@as(c_uint, @intCast(objects.items(.position).len)), 1, 1);
        // raylib.rlDisableShader();
        // raylib.rlReadShaderBuffer(ssboSpeeds, objects.items(.speed).ptr, speedsBytesLength, 0);

        if (!stopSimulation) {
            const beforeSimulation = std.time.microTimestamp();
            const objectsSlice = objects.slice();

            if (isGpuSimulation) {
                simulateOnGPU(gpuData, objectsSlice, deltaTime);
            } else {
                simulate(objectsSlice, deltaTime);
            }

            // const test32 = objects.items(.speed)[0];
            // _=test32;
            stopWatchTotal += std.time.microTimestamp() - beforeSimulation;
            stopWatchCount += 1;

            updateObjectsTransformation(objects.slice());
        }

        // const firstObject = objects.items[0];
        // light.position.x = firstObjectPosition[0];
        // light.position.y = firstObjectPosition[1];
        // light.position.z = firstObjectPosition[2];

        raylib.UpdateLightValues(shader, light);

        const cameraPos: [3]i32 = .{ camera.position.x, camera.position.y, camera.position.z };

        raylib.SetShaderValue(shader, shader.locs[raylib.SHADER_LOC_VECTOR_VIEW], 
        cameraPos[0..3], raylib.SHADER_UNIFORM_VEC3);

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.DARKGRAY);
        // glad.glClear(glad.GL_DEPTH_BUFFER_BIT);

        // const transforms = .{firstObject.transformation};

        raylib.BeginMode3D(camera);
            //raylib.BeginShaderMode(shader);
                // raylib.DrawModel(model, .{ .x = 0.0, .y = 10.0, .z = 0.0 }, 10.0, raylib.GREEN);
                // raylib.DrawMesh(sphereMesh, sphereMaterial, firstObject.transformation);
                
                // const ttt = objects.items(.transformation)[0];
                
                raylib.rlBindShaderBuffer(gpuData.ssboColorsId, 0);

                const count = @as(c_int, @intCast(objects.items(.transformation).len));
                raylib.DrawMeshInstanced(sphereMesh, sphereMaterial, objects.items(.transformation).ptr, count);
                // raylib.DrawMeshInstanced(sphereMesh, sphereMaterial, &firstObjectTransformation, 1);

                // for (objects.items(.position), objects.items(.radius)) |objectPosition, objectRadius| {    
                //     raylib.DrawSphere(objectPosition, objectRadius, raylib.WHITE);
                // }
            //raylib.EndShaderMode();
            // raylib.DrawGrid(10, 10.0);
        raylib.EndMode3D();

        if (isGpuSimulation) {
            raylib.DrawText("GPU simulation", 0,20, 20, raylib.RED);
        } else {
            raylib.DrawText("CPU simulation", 0,20, 20, raylib.BLUE);
        }
        raylib.DrawFPS(0, 0);
        raylib.EndDrawing();
    }

    const stdout = std.io.getStdOut().writer();
    const test3 = @divTrunc(stopWatchTotal, stopWatchCount);
    try stdout.print("YEAH {d}\n", .{test3});
}
