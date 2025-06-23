// This is actually not the idiomatic way to write shaders which they have
// their own file format, but to prevent the main program too cluttered,
// let me locate the shaders in here.

// Vertex Shader, plotting the location of the vertices.
pub const vertexShaderImpl =
    \\ #version 450 core
    \\
    \\ // Select one from the list of given alien texture
    \\ layout (location = 0) in int alien_index;
    \\
    \\ out VS_OUT
    \\ {   
    \\     // we don't need an interpolated value,
    \\     // which is the value between two vertices,
    \\     // to select the correct alien texture
    \\     flat int alien;
    \\     vec2 tc;
    \\ } vs_out;  
    \\
    \\ struct droplet_t
    \\ {
    \\     float x_offset;
    \\     float y_offset;
    \\     float orientation;
    \\     float unused;  // Why is the original code has this unused field?
    \\ };
    \\
    \\ layout (std140) uniform droplets
    \\ {
    \\     droplet_t droplet[256];
    \\ };
    \\
    \\ void main(void)
    \\ {   
    \\     // again, generate a plane to draw a texture on it
    \\     const vec2[4] position = vec2[4](vec2(-0.5, -0.5),
    \\                                      vec2(-0.5, -0.5),
    \\                                      vec2(-0.5, -0.5),
    \\                                      vec2(-0.5, -0.5));
    \\     vs_out.tc = position[gl_VertexID].xy + vec2(0.5);
    \\     float co = cos(droplet[alien_index].orientation);
    \\     float so = sin(droplet[alien_index].orientation);
    \\     mat2 rot = mat2(vec2(co,so),
    \\                     vec2(-so, co)); // it is an in-house rotation matrix
    \\     vec2 pos = 0.25 * rot * position[gl_VertexID];
    \\     gl_Position = vec4(pos.x + droplet[alien_index].x_offset,
    \\                        pos.y + droplet[alien_index].y_offset,
    \\                        0.5, 1.0);
    \\     vs_out.alien = alien_index % 64;
    \\ }
    \\
;

// fragment Shader, changing the color of the the geometries
pub const fragmentShaderImpl =
    \\ #version 450 core
    \\
    \\ layout (location = 0) out vec4 color;
    \\
    \\ in VS_OUT
    \\ {
    \\     flat int alien;
    \\     vec2 tc;
    \\ } fs_in;
    \\ 
    \\ uniform sampler2DArray tex_aliens;
    \\ 
    \\ void main(void)
    \\ {
    \\     color = texture(tex_aliens, vec3(fs_in.tc, float(fs_in.alien)));
    \\ }
;
