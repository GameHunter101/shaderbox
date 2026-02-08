const PI = 3.14159265;

@group(1) @binding(0) var<uniform> lights: array<Light, 10>;
@group(1) @binding(1) var diffuse_tex: texture_2d<f32>;
@group(1) @binding(2) var sample: sampler;

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

/* fn chi(x: f32) -> f32 {
    if (x > 0.0) {
        return 1.0;
    } else {
        return 0.0;
    }
} */

fn isotropic_ggx(alpha_g_sqr: f32, dot_norm_half: f32) -> f32 {
        let denom = (1.0 + dot_norm_half * dot_norm_half * (alpha_g_sqr - 1.0));

        let ggx_normal_distribution = alpha_g_sqr/(PI * denom * denom);
        return ggx_normal_distribution;
}

/* fn anisotropic_ggx(alpha_x: f32, alpha_y: f32, dot_norm_half: f32) -> f32 {
    let denom = 
    return 1.0 / (PI * alpha_x * alpha_y * )
} */

fn eval_specular(roughness: f32, normal: vec3<f32>, half_vector: vec3<f32>, w_i: vec3<f32>, w_o: vec3<f32>) -> f32 {
        let alpha_g = roughness * roughness;

        let dot_norm_half = dot(normal, half_vector);

        let alpha_g_sqr = alpha_g * alpha_g;
        let ggx_normal_distribution = isotropic_ggx(alpha_g_sqr, dot_norm_half);

        let mu_o = clamp(dot(normal, w_o), 0.0, 1.0);
        let mu_i = clamp(dot(normal, w_i), 0.0, 1.0);

        let combined_geometric_attenuation_term = 0.5 / (mu_o * sqrt(alpha_g_sqr + mu_i * (mu_i - alpha_g_sqr * mu_i)) + mu_i * sqrt(alpha_g_sqr + mu_o * (mu_o - alpha_g_sqr * mu_o)));

        let f_90 = 0.5 + 2.0 * (roughness * dot(w_i, half_vector) * dot(w_i, half_vector));
        let f_0 = 1.0;
        let fresnel = f_0 + (f_90 - f_0) * pow(1.0 - clamp(dot(normal, w_i), 0.0, 1.0), 5.0);

        return fresnel * ggx_normal_distribution * combined_geometric_attenuation_term;
}

@fragment
fn main(in: VertexOut) -> @location(0) vec4<f32> {
    let base_color = textureSample(diffuse_tex, sample, vec2f(in.tex_coords.x, 1.0 - in.tex_coords.y)).xyz;
    let w_o = normalize(camera.pos.xyz - in.world_pos);

    var full_color = vec3f(0.0);

    for (var i = 0; i < 10; i++) {
        if (lights[i].enabled == 0) {
            continue;
        }

        let w_i = normalize(lights[i].pos - in.world_pos);
        let reflection = -w_i - 2.0 * (-dot(w_i, in.normal) * in.normal);
        let half_vector = normalize(w_i + w_o);

        let diffuse = base_color * dot(in.normal, lights[i].pos);

        let dist = distance(lights[i].pos, in.world_pos);
        let attenuation = lights[i].brightness / (dist * dist);

        let specular = eval_specular(0.4, in.normal, half_vector, w_i, w_o);

        full_color = (diffuse + vec3f(specular)) * lights[i].color * attenuation;
    }
    return vec4f(full_color, 1.0);
}
