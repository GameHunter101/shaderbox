struct VertexIn {
    @location(0) pos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) tex_coords: vec2<f32>,
}

struct VertexOut {
    @builtin(position) clip_pos: vec4<f32>,
    @location(0) world_pos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) tex_coords: vec2<f32>,
}

struct TransformData {
    @location(3) mat_0: vec4<f32>,
    @location(4) mat_1: vec4<f32>,
    @location(5) mat_2: vec4<f32>,
    @location(6) mat_3: vec4<f32>,
}

struct Camera {
    view_proj: mat4x4<f32>,
    inv_view_proj: mat4x4<f32>,
    pos: vec4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;

@vertex
fn main(in: VertexIn, transform: TransformData) -> VertexOut {
    let mat = mat4x4<f32>(
        transform.mat_0,
        transform.mat_1,
        transform.mat_2,
        transform.mat_3,
    );

    let world_pos = mat * vec4f(in.pos, 1.0);

    var out: VertexOut;
    out.clip_pos = camera.view_proj * world_pos;
    out.world_pos = world_pos.xyz;
    out.normal = normalize((mat * vec4f(in.normal, 1.0)).xyz);
    out.tex_coords = in.tex_coords;

    return out;
}
