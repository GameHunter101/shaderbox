const PI = 3.14159265;

@group(1) @binding(0) var<uniform> lights: array<Light, 10>;

struct Light {
    pos: vec3<f32>,
    enabled: i32,
    color: vec3<f32>,
    brightness: f32,
}

struct VertexOut {
    @builtin(position) clip_pos: vec4<f32>,
    @location(0) world_pos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) tex_coords: vec2<f32>,
}

struct Camera {
    view_proj: mat4x4<f32>,
    inv_view_proj: mat4x4<f32>,
    pos: vec4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;

fn chi(x: f32) -> f32 {
    if (x > 0.0) {
        return 1.0;
    } else {
        return 0.0;
    }
}

@fragment
fn main(in: VertexOut) -> @location(0) vec4<f32> {
    let base_color = vec3f(0.2, 0.0, 0.0);
    let w_o = normalize(camera.pos.xyz - in.world_pos);

    var full_color = vec3f(0.0);

    for (var i = 0; i < 10; i++) {
        if (lights[i].enabled == 0) {
            continue;
        }

        var diffuse = vec3f(0.0);
        var specular = vec3f(0.0);

        let w_i = normalize(lights[i].pos - in.world_pos);
        let reflection = -w_i - 2.0 * (-dot(w_i, in.normal) * in.normal);
        let half_vector = normalize(w_i + w_o);

        let alpha_p = 100.0;

        diffuse += base_color * dot(in.normal, lights[i].pos);
        let blinn = dot(in.normal, half_vector);
        let dist = distance(lights[i].pos, in.world_pos);
        specular += chi(blinn) * (alpha_p + 2.0)/(2.0 * PI) * (pow(blinn, alpha_p) / (dist * dist)) * lights[i].brightness;

        full_color += (diffuse + specular) * lights[i].color;
    }
    return vec4f(full_color, 1.0);
}
