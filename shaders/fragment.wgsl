const PI = 3.14159265;

@group(1) @binding(0) var<uniform> lights: array<Light, 10>;
@group(1) @binding(1) var diffuse_tex: texture_2d<f32>;
@group(1) @binding(2) var roughness_tex: texture_2d<f32>;
@group(1) @binding(3) var metallic_tex: texture_2d<f32>;
@group(1) @binding(4) var ao_tex: texture_2d<f32>;
@group(1) @binding(5) var normal_tex: texture_2d<f32>;
@group(1) @binding(6) var sample: sampler;

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
    @location(3) world_tangent: vec3<f32>,
    @location(4) world_bitangent: vec3<f32>,
    @location(5) world_normal: vec3<f32>,
    @location(6) tangent: vec3<f32>,
    @location(7) bitangent: vec3<f32>,
}

struct Camera {
    view_proj: mat4x4<f32>,
    inv_view_proj: mat4x4<f32>,
    pos: vec4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;

fn chi(x: f32) -> f32 {
    if x > 0.0 {
        return 1.0;
    } else {
        return 0.0;
    }
}

fn fresnel(f_0: vec3<f32>, f_90: vec3<f32>, cos_angle: f32) -> vec3<f32> {
    // return f_0 + (vec3f(1.0) - f_0) * pow(1.0 - dot(normal, w_o), 0.0, 1.0, 5.0);
    return mix(f_0, f_90, pow(clamp(1.0 - cos_angle, 0.0, 1.0), 5.0));
}

fn isotropic_ggx(alpha_g_sqr: f32, dot_norm_half: f32) -> f32 {
    let denom = (1.0 + dot_norm_half * dot_norm_half * (alpha_g_sqr - 1.0));

    let ggx_normal_distribution = alpha_g_sqr / (PI * denom * denom);
    return ggx_normal_distribution;
}

fn combined_isotropic_geometric_attenuation(alpha_g_sqr: f32, normal: vec3<f32>, w_i: vec3<f32>, w_o: vec3<f32>) -> f32 {
    let mu_o = clamp(dot(normal, w_o), 0.0, 1.0);
    let mu_i = clamp(dot(normal, w_i), 0.0, 1.0);

    return 0.5 / (mu_o * sqrt(alpha_g_sqr + mu_i * (mu_i - alpha_g_sqr * mu_i)) + mu_i * sqrt(alpha_g_sqr + mu_o * (mu_o - alpha_g_sqr * mu_o)));
}

fn isotropic_geometric_attenuation(alpha_g_sqr: f32, normal: vec3<f32>, w_o: vec3<f32>, w_i: vec3<f32>) -> f32 {
    let mu_o = clamp(dot(normal, w_o), 0.0, 1.0);
    let mu_i = clamp(dot(normal, w_i), 0.0, 1.0);

    return 0.5 / (mu_o * sqrt(alpha_g_sqr + mu_i * (mu_i - alpha_g_sqr * mu_i)) + mu_i * sqrt(alpha_g_sqr + mu_o * (mu_o - alpha_g_sqr * mu_o)));
}

fn anisotropic_ggx(alpha_x: f32, alpha_y: f32, dot_norm_half: f32, hdotx: f32, hdoty: f32) -> f32 {
    let denom = ((hdotx * hdotx) / (alpha_x * alpha_x) + (hdoty * hdoty) / (alpha_y * alpha_y) + dot_norm_half * dot_norm_half);
    return 1.0 / (PI * alpha_x * alpha_y * denom * denom);
}

fn anisotropic_ggx_lambda(alpha_x: f32, alpha_y: f32, s: vec3<f32>, normal: vec3<f32>, tangent: vec3<f32>, bitangent: vec3<f32>) -> f32 {
    let x_term = alpha_x * dot(tangent, s);
    let y_term = alpha_y * dot(bitangent, s);
    let a = dot(normal, s) / sqrt(x_term * x_term + y_term * y_term);
    return (-1.0 + sqrt(1.0 + 1.0 / (a * a))) / 2.0;
}

fn anisotropic_geometric_attenuation(
    alpha_x: f32,
    alpha_y: f32,
    normal: vec3<f32>,
    w_i: vec3<f32>,
    w_o: vec3<f32>,
    half_vector: vec3<f32>,
    tangent: vec3<f32>,
    bitangent: vec3<f32>
) -> f32 {
    let lambda_w_o = anisotropic_ggx_lambda(alpha_x, alpha_y, w_o, normal, tangent, bitangent);
    let lambda_w_i = anisotropic_ggx_lambda(alpha_x, alpha_y, w_i, normal, tangent, bitangent);
    return (chi(dot(half_vector, w_i)) * chi(dot(half_vector, w_o))) / (1.0 + lambda_w_o + lambda_w_i);
}

fn eval_specular(base_color: vec3<f32>, roughness: f32, anisotropy: f32, normal: vec3<f32>, half_vector: vec3<f32>, w_i: vec3<f32>, w_o: vec3<f32>, tangent: vec3<f32>, bitangent: vec3<f32>) -> vec3<f32> {
    let alpha_g = roughness * roughness;

    let dot_norm_half = dot(normal, half_vector);

    let alpha_g_sqr = alpha_g * alpha_g;
    let alpha_x = roughness * roughness * (1.0 + anisotropy);
    let alpha_y = roughness * roughness * (1.0 - anisotropy);
    let ggx_normal_distribution = anisotropic_ggx(alpha_x, alpha_y, dot_norm_half, dot(half_vector, tangent), dot(half_vector, bitangent));

    let combined_geometric_attenuation_term = anisotropic_geometric_attenuation(alpha_x, alpha_y, normal, w_i, w_o, half_vector, tangent, bitangent) / (4.0 * abs(dot(normal, w_o)) * abs(dot(normal, w_i)));

    let fresnel = fresnel(base_color, vec3f(1.0), dot(normal, w_o));

    return fresnel * ggx_normal_distribution * combined_geometric_attenuation_term;
}

fn eval_clearcoat(clearcoat_gloss: f32, w_i: vec3<f32>, w_o: vec3<f32>, half_vector: vec3<f32>, normal: vec3<f32>, tangent: vec3<f32>, bitangent: vec3<f32>) -> vec3<f32> {
    let alpha_g = mix(0.1, 0.001, clearcoat_gloss);
    let alpha_g_sqr = alpha_g * alpha_g;
    let half_dot_norm = dot(half_vector, normal);
    let ndf = isotropic_ggx(alpha_g_sqr, half_dot_norm); //(alpha_g_sqr - 1.0) / (PI * log(alpha_g_sqr) * (1.0 + (alpha_g_sqr - 1.0) * half_dot_norm * half_dot_norm));
    let geometric_attenuation_term = anisotropic_geometric_attenuation(0.25, 0.25, normal, w_i, w_o, half_vector, tangent, bitangent);
    let ehta = 1.5;
    let r_0 = ((ehta - 1.0) * (ehta - 1.0)) / ((ehta + 1.0) * (ehta + 1.0));
    let fresnel_term = fresnel(vec3f(r_0), vec3f(1.0), dot(normal, w_o));
    return (ndf * geometric_attenuation_term * fresnel_term) / (4.0 * abs(dot(normal, w_i)));
}

@fragment
fn main(in: VertexOut) -> @location(0) vec4<f32> {
    let albedo = textureSample(diffuse_tex, sample, in.tex_coords).xyz;
    let roughness = textureSample(roughness_tex, sample, in.tex_coords).x;
    let anisotropy = 0.9;
    let metallic = textureSample(metallic_tex, sample, in.tex_coords).x;
    let ao = textureSample(ao_tex, sample, in.tex_coords).x;
    let normal_sample = textureSample(normal_tex, sample, in.tex_coords).xyz;
    let clearcoat = 1.0;
    let clearcoat_gloss = 1.0;

    let normal_strength = 0.8;

    let tbn = mat3x3(in.world_tangent, in.world_bitangent, in.world_normal);

    let tangent_normal = normalize(normal_sample * 2.0 - 1.0) * vec3f(normal_strength, normal_strength, 1.0);
    let world_normal = normalize(tbn * tangent_normal);

    let base_color = albedo * ao;

    let w_o = normalize(camera.pos.xyz - in.world_pos);

    var full_color = vec3f(0.0);

    for (var i = 0; i < 10; i++) {
        if lights[i].enabled == 0 {
            continue;
        }

        let w_i = normalize(lights[i].pos - in.world_pos);
        let reflection = -w_i - 2.0 * (-dot(w_i, world_normal) * world_normal);
        let half_vector = normalize(w_i + w_o);

        let diffuse = base_color * dot(world_normal, lights[i].pos);

        let dist = distance(lights[i].pos, in.world_pos);
        let attenuation = lights[i].brightness / (dist * dist);

        let specular_lobe = eval_specular(vec3(0.0), roughness, anisotropy, world_normal, half_vector, w_i, w_o, in.tangent, in.bitangent);

        let clearcoat_lobe = eval_clearcoat(clearcoat_gloss, w_i, w_o, half_vector, world_normal, in.tangent, in.bitangent);

        // full_color = specular_lobe;
        full_color = (diffuse * (1.0 - metallic) + specular_lobe * mix(vec3f(1.0), base_color, metallic) + 0.25 * clearcoat * clearcoat_lobe) * lights[i].color * attenuation;
    }
    return vec4f(full_color, 1.0);
}
