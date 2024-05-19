const std = @import("std");

const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cDefine("RLIGHTS_IMPLEMENTATION", "1");
    @cInclude("rlights.h");
});

fn switchToFullScreen() void {
    const display = raylib.GetCurrentMonitor();
    raylib.SetWindowSize(raylib.GetMonitorWidth(display), raylib.GetMonitorHeight(display));
    raylib.ToggleFullscreen();
}

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 800;

    raylib.SetConfigFlags(raylib.FLAG_MSAA_4X_HINT);
    raylib.InitWindow(screenWidth, screenHeight, "3d objects");
    defer raylib.CloseWindow();
    //switchToFullScreen();
    raylib.SetTargetFPS(144);

    const camera: raylib.Camera = .{ 
        .position = .{ .x = 0.0, .y = 50.0, .z = -220.0 },
        .target = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 30.0,
        .projection = raylib.CAMERA_PERSPECTIVE
    };

    //var model: raylib.Model = raylib.LoadModel("ball.glb");

    const shader: raylib.Shader = raylib.LoadShader("lighting.vs", "lighting.fs");
    shader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(shader, "viewPos");

    const ambientLoc = raylib.GetShaderLocation(shader, "ambient");
    const test1: [4]f32 = .{ 0.1, 0.1, 0.1, 1.0 };
    raylib.SetShaderValue(shader, ambientLoc, test1[0..4], raylib.SHADER_UNIFORM_VEC4);

    const light: raylib.Light = raylib.CreateLight(raylib.LIGHT_POINT, 
        .{ .x = 20, .y = 0, .z = 0 }, raylib.Vector3Zero(), raylib.YELLOW, shader);
    raylib.UpdateLightValues(shader, light);
    
    // const pitch: f32 = 0.0;
    // const roll: f32 = 0.0;
    // const yaw: f32 = 0.0;

    while (!raylib.WindowShouldClose()) {
        //model.transform = raylib.MatrixRotateXYZ(.{ .x = raylib.DEG2RAD * pitch, .y = raylib.DEG2RAD * yaw, .z = raylib.DEG2RAD * roll });

        const cameraPos: [3]i32 = .{ camera.position.x, camera.position.y, camera.position.z };

        raylib.SetShaderValue(shader, shader.locs[raylib.SHADER_LOC_VECTOR_VIEW], 
        cameraPos[0..3], raylib.SHADER_UNIFORM_VEC3);

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.DARKGRAY);

        raylib.BeginMode3D(camera);
            raylib.BeginShaderMode(shader);
                //raylib.DrawModel(model, .{ .x = 0.0, .y = 10.0, .z = 0.0 }, 10.0, raylib.GREEN);
                
                // raylib.DrawCube(raylib.Vector3Zero(), 20.0, 20.0, 20.0, raylib.WHITE);
                raylib.DrawSphere(.{ .x = 0.0, .y = 0.0, .z = 0.0 }, 5.0, raylib.WHITE);
                // raylib.DrawCircle3D(.{ .x = 0.0, .y = 0.0, .z = 0.0 }, 10.0, .{ .x = 0.0, .y = 0.0, .z = 0.0 }, 0.0, raylib.WHITE);
            raylib.EndShaderMode();
            raylib.DrawGrid(10, 10.0);
        raylib.EndMode3D();

        raylib.DrawFPS(0, 0);
        raylib.EndDrawing();
    }
}
