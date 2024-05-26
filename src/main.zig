const std = @import("std");

const ArrayList = std.ArrayList;
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cDefine("RLIGHTS_IMPLEMENTATION", "1");
    @cInclude("rlights.h");
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
};

fn generateObjects() !std.MultiArrayList(GravityObject) {
    var objects = std.MultiArrayList(GravityObject){};

    try objects.append(std.heap.c_allocator, .{
        .transformation = raylib.MatrixIdentity(),
        .position = @splat(0.0),
        .speed = @splat(0.0),
        .radius = 0.0,
        .mass = 40.0,
        .massInverse = 1.0 / 20.0
    });
    
    const objectsCount: i32 = 1000;

    //> circle
    const distanceFromCenter: f32 = 50.0;
    const anglePerObject: f32 = raylib.PI * 2.0 / objectsCount;

    for (0..objectsCount) |index| {
        const angle: f32 = @as(f32, @floatFromInt(index)) * anglePerObject;

        const x: f32 = distanceFromCenter * raylib.cosf(angle);
        const y: f32 = distanceFromCenter * raylib.sinf(angle);

        const speedAngle = angle + @as(f32, @floatCast(raylib.M_PI_2));

        const initSpeed = 0.02;
        const initSpeedX = initSpeed * raylib.cosf(speedAngle);
        const initSpeedY = initSpeed * raylib.sinf(speedAngle);

        try objects.append(std.heap.c_allocator, .{
            .transformation = raylib.MatrixIdentity(),
            .position = @Vector(3, f32) { x, y, 0.0 },
            .speed = @Vector(3, f32) { initSpeedX, initSpeedY, 0.0 },
            .radius = 0.0,
            .mass = 1.0,
            .massInverse = 1.0
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
    //             .position = .{ .x = x, .y = y, .z = 0.0 },
    //             .speed = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
    //             .radius = 0.0,
    //             .mass = 1.0,
    //             .massInverse = 1.0
    //         });
    //     }
    // }
    //<

    const radiusMultiplier = 1.0;
    
    for (objects.items(.radius), objects.items(.mass), objects.items(.transformation)) |*objectRadius, objectMass, *objectTransformation| {
        objectRadius.* = radiusMultiplier * raylib.sqrtf(objectMass * 3 / (4 * raylib.PI));
        objectTransformation.* = raylib.MatrixScale(objectRadius.*, objectRadius.*, objectRadius.*);
    }

    return objects;
}

fn simulate(objects: std.MultiArrayList(GravityObject).Slice, deltaTime: f32) void {
    for (objects.items(.position), objects.items(.mass), objects.items(.massInverse), objects.items(.speed), 0..objects.len) 
        |aObjectPosition, aObjectMass, aObjectMassInverse, *aObjectSpeed, index| {
        for (objects.items(.position)[index..objects.len], objects.items(.mass)[index..objects.len], objects.items(.massInverse)[index..objects.len], objects.items(.speed)[index..objects.len]) 
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

    for (objects.items(.speed), objects.items(.position), objects.items(.transformation), objects.items(.radius)) |*speed, *position, *transformation, radius| {
        // const speedVectorLength = raylib.Vector3Length(object.speed);
        // const maxSpeed = 5.1;
        // if (speedVectorLength > maxSpeed) {
        //     object.speed = raylib.Vector3Normalize(object.speed);

        //     object.speed.x *= maxSpeed;
        //     object.speed.y *= maxSpeed;
        //     object.speed.z *= maxSpeed;
        // }

        // const maxSpeed = 5.0;

        // if (object.speed.x > maxSpeed) { object.speed.x = maxSpeed; }
        // else if (object.speed.x < -maxSpeed) object.speed.x = -maxSpeed;

        // if (object.speed.y > maxSpeed) { object.speed.y = maxSpeed; }
        // else if (object.speed.y < -maxSpeed) object.speed.y = -maxSpeed;

        // if (object.speed.z > maxSpeed) { object.speed.z = maxSpeed; }
        // else if (object.speed.z < -maxSpeed) object.speed.z = -maxSpeed;

        // speed.x *= 0.98;
        // speed.y *= 0.98;
        // speed.z *= 0.98;

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
    const camera: raylib.Camera = .{ 
        .position = .{ .x = 0.0, .y = 50.0, .z = -220.0 },
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
    defer objects.deinit(std.heap.c_allocator);
    //var model: raylib.Model = raylib.LoadModel("ball.glb");
    //raylib.LoadShaderFromMemory(vsCode: [*c]const u8, fsCode: [*c]const u8)
    const shader: raylib.Shader = raylib.LoadShader("lighting_instanced.vs", "lighting.fs");
    
    shader.locs[raylib.SHADER_LOC_MATRIX_MVP] = raylib.GetShaderLocation(shader, "mvp");
    shader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(shader, "viewPos");
    shader.locs[raylib.SHADER_LOC_MATRIX_MODEL] = raylib.GetShaderLocationAttrib(shader, "instanceTransform");

    const ambientLoc = raylib.GetShaderLocation(shader, "ambient");
    const test1: [4]f32 = .{ 0.1, 0.1, 0.1, 1.0 };
    raylib.SetShaderValue(shader, ambientLoc, test1[0..4], raylib.SHADER_UNIFORM_VEC4);

    var light: raylib.Light = raylib.CreateLight(raylib.LIGHT_DIRECTIONAL, 
        .{ .x = 20.0, .y = 0.0, .z = -0.0 }, raylib.Vector3Zero(), raylib.YELLOW, shader);

    raylib.UpdateLightValues(shader, light);
    
    const sphereMesh = raylib.GenMeshSphere(1.0, 10, 10);
    var sphereMaterial = raylib.LoadMaterialDefault();

    sphereMaterial.shader = shader;
    sphereMaterial.maps[raylib.MATERIAL_MAP_DIFFUSE].color = raylib.RED;

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
    var stopWatchCount: i64 = 0;
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

        if (!stopSimulation) {
            const beforeSimulation = std.time.microTimestamp();
            const objectsSlice = objects.slice();
            simulate(objectsSlice, deltaTime);
            stopWatchTotal += std.time.microTimestamp() - beforeSimulation;
            stopWatchCount += 1;
        }

        // const firstObject = objects.items[0];
        light.position.x = firstObjectPosition[0];
        light.position.y = firstObjectPosition[1];
        light.position.z = firstObjectPosition[2];

        raylib.UpdateLightValues(shader, light);

        const cameraPos: [3]i32 = .{ camera.position.x, camera.position.y, camera.position.z };

        raylib.SetShaderValue(shader, shader.locs[raylib.SHADER_LOC_VECTOR_VIEW], 
        cameraPos[0..3], raylib.SHADER_UNIFORM_VEC3);

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.DARKGRAY);

        // const transforms = .{firstObject.transformation};

        raylib.BeginMode3D(camera);
            //raylib.BeginShaderMode(shader);
                // raylib.DrawModel(model, .{ .x = 0.0, .y = 10.0, .z = 0.0 }, 10.0, raylib.GREEN);
                // raylib.DrawMesh(sphereMesh, sphereMaterial, firstObject.transformation);
                
                // const ttt = objects.items(.transformation)[0];

                const count = @as(c_int, @intCast(objects.items(.transformation).len));

                //objects.items(.transformation).len
                raylib.DrawMeshInstanced(sphereMesh, sphereMaterial, objects.items(.transformation).ptr, count);
                // raylib.DrawMeshInstanced(sphereMesh, sphereMaterial, &firstObjectTransformation, 1);

                // for (objects.items(.position), objects.items(.radius)) |objectPosition, objectRadius| {    
                //     raylib.DrawSphere(objectPosition, objectRadius, raylib.WHITE);
                // }
            //raylib.EndShaderMode();
            // raylib.DrawGrid(10, 10.0);
        raylib.EndMode3D();

        raylib.DrawFPS(0, 0);
        raylib.EndDrawing();
    }

    const stdout = std.io.getStdOut().writer();
    const test3 = @divTrunc(stopWatchTotal, stopWatchCount);
    try stdout.print("YEAH {d}\n", .{test3});
}
