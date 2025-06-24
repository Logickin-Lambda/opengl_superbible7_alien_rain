// These are the libraries used in the examples,
// you may find the respostories from build.zig.zon
const std = @import("std");
const app = @import("sb7.zig");
const ktx = @import("sb7ktx.zig");
const zm = @import("zm");
const shader = @import("shaders_alien_rain.zig");

var program: app.gl.uint = undefined;
var vao: app.gl.uint = undefined;

var tex_alien_array: app.gl.uint = undefined;
var rain_buffer: app.gl.uint = undefined;

const RAIN_SIZE = 256;
var droplet_x_offset = std.mem.zeroes([RAIN_SIZE]f32);
var droplet_rot_speed = std.mem.zeroes([RAIN_SIZE]f32);
var droplet_fall_speed = std.mem.zeroes([RAIN_SIZE]f32);

pub fn main() !void {
    // Many people seem to hate the dynamic loading part of the program.
    // I also hate it too, but I don't seem to find a good solution (yet)
    // that is aligned with both zig good practice and the book
    // which is unfortunately abstracted all tbe inner details.

    // "override" your program using function pointer,
    // and the run function will process them all\
    app.init = init;
    app.start_up = startup;
    app.render = render;
    app.shutdown = shutdown;
    app.run();
}

fn init() anyerror!void {
    app.info.flags.cursor = app.gl.TRUE;
    std.mem.copyForwards(u8, &app.info.title, "Alien Rain");
}

fn startup() callconv(.c) void {

    // vertex shader
    const vs: app.gl.uint = app.gl.CreateShader(app.gl.VERTEX_SHADER);
    app.gl.ShaderSource(
        vs,
        1,
        &.{shader.vertexShaderImpl},
        &.{shader.vertexShaderImpl.len},
    );
    app.gl.CompileShader(vs);
    var success: c_int = undefined;
    var infoLog: [512:0]u8 = undefined;
    app.verifyShader(vs, &success, &infoLog) catch {
        std.debug.print("ERROR IN THE VERTEX SHADER", .{});
        return;
    };

    // fragment shader
    const fs: app.gl.uint = app.gl.CreateShader(app.gl.FRAGMENT_SHADER);
    app.gl.ShaderSource(
        fs,
        1,
        &.{shader.fragmentShaderImpl},
        &.{shader.fragmentShaderImpl.len},
    );
    app.gl.CompileShader(fs);
    app.verifyShader(fs, &success, &infoLog) catch {
        std.debug.print("ERROR IN THE FRAGMENT SHADER", .{});
        return;
    };

    // Now put all the shaders into the program
    program = app.gl.CreateProgram();
    app.gl.AttachShader(program, vs);
    app.gl.AttachShader(program, fs);

    app.gl.LinkProgram(program);
    app.gl.DeleteShader(vs);
    app.gl.DeleteShader(fs);

    app.gl.GenVertexArrays(1, (&vao)[0..1]);
    app.gl.BindVertexArray(vao);

    // load the alien texture
    const page = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page);
    defer arena.deinit();

    _ = ktx.load(arena.allocator(), "src/media/textures/aliens.ktx", &tex_alien_array) catch {
        std.debug.print("ERROR IN TEXTURE LOAD", .{});
    };
    app.gl.BindTexture(app.gl.TEXTURE_2D_ARRAY, tex_alien_array);
    app.gl.TexParameteri(app.gl.TEXTURE_2D_ARRAY, app.gl.TEXTURE_MIN_FILTER, app.gl.LINEAR_MIPMAP_LINEAR);

    // create a buffer which will be used for calculating the movement of individual rain drops
    app.gl.GenBuffers(1, @ptrCast(&rain_buffer));
    app.gl.BindBuffer(app.gl.UNIFORM_BUFFER, rain_buffer);
    app.gl.BufferData(app.gl.UNIFORM_BUFFER, @sizeOf(zm.Vec4f) * RAIN_SIZE, null, app.gl.DYNAMIC_DRAW);

    // This defines the initial speed, orientation, and location.
    inline for (0..RAIN_SIZE) |i| {
        droplet_x_offset[i] = std.crypto.random.float(f32) * 2 - 1;
        droplet_rot_speed[i] = (std.crypto.random.float(f32) + 0.5) * (@as(f32, @floatFromInt(i % 2)) - 0.5) * 6;
        droplet_fall_speed[i] = std.crypto.random.float(f32) + 0.2;
    }

    app.gl.BindVertexArray(vao);

    // These two functions remove the background color so that the program
    // won't draw the hideous rectangle angle at the border of the alien textures.
    app.gl.Enable(app.gl.BLEND);
    app.gl.BlendFunc(app.gl.SRC_ALPHA, app.gl.ONE_MINUS_SRC_ALPHA);
}

fn render(current_time: f64) callconv(.c) void {
    const black: [4]app.gl.float = .{ 0.0, 0.0, 0.0, 0.0 };
    app.gl.ClearBufferfv(app.gl.COLOR, 0, &black);
    app.gl.Viewport(0, 0, app.info.windowWidth, app.info.windowHeight);

    const t = @as(f32, @floatCast(current_time));

    app.gl.UseProgram(program);

    app.gl.BindBufferBase(app.gl.UNIFORM_BUFFER, 0, rain_buffer);

    const droplet_raw = app.gl.MapBufferRange(app.gl.UNIFORM_BUFFER, 0, RAIN_SIZE * @sizeOf(zm.Vec3f), app.gl.MAP_WRITE_BIT | app.gl.MAP_INVALIDATE_BUFFER_BIT);
    var droplet = @as([*c]zm.Vec3f, @ptrCast(@alignCast(droplet_raw.?)));

    inline for (0..RAIN_SIZE) |i| {
        const fmodf_result = std.math.mod(f32, t + @as(f32, @floatFromInt(i)) * droplet_fall_speed[i], 4.31) catch 0;

        droplet[i][0] = droplet_x_offset[i];
        droplet[i][1] = 2.0 - fmodf_result;
        droplet[i][2] = t * droplet_rot_speed[i];
    }

    _ = app.gl.UnmapBuffer(app.gl.UNIFORM_BUFFER);

    inline for (0..RAIN_SIZE) |alien_index| {
        // This is where the layout (location = 0) does its job
        app.gl.VertexAttribI1i(0, @intCast(alien_index));
        app.gl.DrawArrays(app.gl.TRIANGLE_STRIP, 0, 4);
    }
}

fn shutdown() callconv(.c) void {
    app.gl.BindVertexArray(0);
    app.gl.DeleteVertexArrays(1, (&vao)[0..1]);
    app.gl.DeleteProgram(program);
}
