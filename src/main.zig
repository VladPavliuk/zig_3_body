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
    position: raylib.Vector3,
    speed: raylib.Vector3,
    radius: f32,
    mass: f32
};

// fn calculateGravity(a: GravityObject, b: GravityObject) raylib.Vector2 {
//     const delta = raylib.Vector3Subtract(a.position, b.position);
//     const distance = raylib.Vector3Distance(a.position, b.position);

//     // distance
//     // const distance = a.position
// }

fn generateObjects() !ArrayList(GravityObject) {
    var objects = ArrayList(GravityObject).init(std.heap.c_allocator);

    const centerLocation: raylib.Vector3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };

    try objects.append(.{
        .position = centerLocation,
        .speed = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .radius = 0.0,
        .mass = 10.0
    });

    const distanceFromCenter: f32 = 20.0;
    const objectsCount: i32 = 100;
    const anglePerObject: f32 = raylib.PI * 2.0 / objectsCount;

    for (0..objectsCount) |index| {
        const angle: f32 = @as(f32, @floatFromInt(index)) * anglePerObject;

        const x: f32 = distanceFromCenter * raylib.cosf(angle);
        const y: f32 = distanceFromCenter * raylib.sinf(angle);

        try objects.append(.{
            .position = .{ .x = x, .y = y, .z = 0.0 },
            .speed = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
            .radius = 0.0,
            .mass = 1.0
        });    
    }

    const radiusMultiplier = 2.0;
    for (objects.items) |*object| {
        object.radius = radiusMultiplier * raylib.sqrtf(object.mass * 3 / (4 * raylib.PI));
    }

    return objects;
}

fn simulate(objects: ArrayList(GravityObject), deltaTime: f32) void {
    for (objects.items, 0..objects.items.len) |*aObject, index| {
        for (objects.items[index..objects.items.len]) |*bObject| {
            const delta = raylib.Vector3Subtract(aObject.position, bObject.position);

            var distance = raylib.sqrtf(((delta.x * delta.x) + (delta.y * delta.y)) + (delta.z * delta.z));

            if (distance < 1.0) distance = 1.0;
            var force = aObject.mass * bObject.mass / (distance * distance);

            force *= 10.0 * deltaTime;

            aObject.speed.x += force * -delta.x * (1.0 / aObject.mass);
            aObject.speed.y += force * -delta.y * (1.0 / aObject.mass);
            aObject.speed.z += force * -delta.z * (1.0 / aObject.mass);
            
            bObject.speed.x += force * delta.x * (1.0 / bObject.mass);
            bObject.speed.y += force * delta.y * (1.0 / bObject.mass);
            bObject.speed.z += force * delta.z * (1.0 / bObject.mass);
        }
    }

    for (objects.items) |*object| {
        object.position.x += object.speed.x;
        object.position.y += object.speed.y;
        object.position.z += object.speed.z;
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

    var objects = try generateObjects();
    defer objects.deinit();
    //var model: raylib.Model = raylib.LoadModel("ball.glb");

    const shader: raylib.Shader = raylib.LoadShader("lighting.vs", "lighting.fs");
    shader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(shader, "viewPos");

    const ambientLoc = raylib.GetShaderLocation(shader, "ambient");
    const test1: [4]f32 = .{ 0.1, 0.1, 0.1, 1.0 };
    raylib.SetShaderValue(shader, ambientLoc, test1[0..4], raylib.SHADER_UNIFORM_VEC4);

    const light: raylib.Light = raylib.CreateLight(raylib.LIGHT_POINT, 
        .{ .x = 20.0, .y = 0.0, .z = -0.0 }, raylib.Vector3Zero(), raylib.YELLOW, shader);

    raylib.UpdateLightValues(shader, light);

    // const pitch: f32 = 0.0;
    // const roll: f32 = 0.0;
    // const yaw: f32 = 0.0;
    var firstObject = &objects.items[0];

    var stopSimulation = true;
    var isFullScreen = false;
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

            firstObject.position.x = xProjected;
            firstObject.position.y = yProjected;
            firstObject.speed = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        }

        if (!stopSimulation) {
            simulate(objects, deltaTime);
        }

        // const firstObject = objects.items[0];
        // light.position.x = firstObject.position.x;
        // light.position.y = firstObject.position.y;
        // light.position.z = firstObject.position.z;

        // raylib.UpdateLightValues(shader, light);

        const cameraPos: [3]i32 = .{ camera.position.x, camera.position.y, camera.position.z };

        raylib.SetShaderValue(shader, shader.locs[raylib.SHADER_LOC_VECTOR_VIEW], 
        cameraPos[0..3], raylib.SHADER_UNIFORM_VEC3);

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.DARKGRAY);

        raylib.BeginMode3D(camera);
            raylib.BeginShaderMode(shader);
                // raylib.DrawModel(model, .{ .x = 0.0, .y = 10.0, .z = 0.0 }, 10.0, raylib.GREEN);
                for (objects.items) |object| {
                    raylib.DrawSphere(object.position, object.radius, raylib.WHITE);
                }
            raylib.EndShaderMode();
            // raylib.DrawGrid(10, 10.0);
        raylib.EndMode3D();

        raylib.DrawFPS(0, 0);
        raylib.EndDrawing();
    }
}
