use crate::light_manager_component::{Light, LightManagerComponent, RawLight};
use algoe::bivector::Bivector;
use image::{EncodableLayout, GenericImageView};
use nalgebra::Vector3;
use v4::{
    V4,
    builtin_components::{
        camera_component::CameraComponent,
        mesh_component::{MeshComponent, VertexData, VertexDescriptor},
        transform_component::TransformComponent,
    },
    engine_support::texture_support::{TextureBundle, TextureProperties},
    scene,
};
use wgpu::{Color, TextureFormat, vertex_attr_array};

mod light_manager_component;

#[tokio::main]
async fn main() {
    let mut engine = V4::builder()
        .window_settings(800, 800, "Shaderbox", None)
        .antialiasing_enabled(true)
        .clear_color(Color {
            r: 0.02,
            g: 0.02,
            b: 0.02,
            a: 1.0,
        })
        .build()
        .await;

    let rendering_manager = engine.rendering_manager();
    let device = rendering_manager.device();
    let queue = rendering_manager.queue();

    let textures = [
        (
            "./assets/shaderball_diffuse.jpg",
            TextureFormat::Rgba8UnormSrgb,
        ),
        ("./assets/shaderball_roughness.png", TextureFormat::R8Unorm),
        ("./assets/shaderball_metallic.png", TextureFormat::R8Unorm),
        ("./assets/shaderball_ao.jpg", TextureFormat::R8Unorm),
        ("./assets/shaderball_normal.jpg", TextureFormat::Rgba8Unorm),
    ];

    let handles = textures.map(|(path, ty)| {
        tokio::spawn(async move {
            let raw_image = tokio::fs::read(path).await.unwrap();
            let img = image::load_from_memory(&raw_image).expect("Failed to create image");
            let dims = img.dimensions();
            let bytes = if ty.components() != 1 {
                let rgba8 = img.into_rgba8();
                rgba8.as_bytes().to_vec()
            } else {
                img.as_bytes().to_vec()
            };

            (bytes, dims, ty)
        })
    });

    let bytes_res: Result<Vec<_>, _> = futures::future::join_all(handles)
        .await
        .into_iter()
        .collect();
    let bytes: [(Vec<u8>, (u32, u32), TextureFormat); 5] = bytes_res.unwrap().try_into().unwrap();
    let [diffuse, roughness, metallic, ao, normal] = bytes.map(|(bytes, dimensions, format)| {
        TextureBundle::from_bytes(
            &bytes,
            dimensions,
            device,
            queue,
            TextureProperties {
                format,
                ..Default::default()
            },
        )
        .1
    });

    scene! {
        scene: sandbox_scene,
        active_camera: "cam",
        "cam_ent" = {
            components: [
                CameraComponent(field_of_view: 60.0, aspect_ratio: 1.0, near_plane: 0.1, far_plane: 50.0, sensitivity: 0.0, movement_speed: 0.0, ident: "cam"),
                TransformComponent(position: Vector3::new(0.0, 1.5, -4.0), rotation: Bivector::new(0.0, -std::f32::consts::FRAC_PI_6 / 2.0, 0.0).exponentiate(), ident: "cam_transform")
            ]
        },
        "shader_model" = {
            material: {
                pipeline: {
                    vertex_shader_path: "shaders/vertex.wgsl",
                    fragment_shader_path: "shaders/fragment.wgsl",
                    vertex_layouts: [Vertex::vertex_layout(), TransformComponent::vertex_layout::<5>()],
                    uses_camera: true,
                },
                attachments: [
                    Buffer(
                        device: device,
                        data: bytemuck::cast_slice(&[RawLight::default(); 10]),
                        buffer_type: wgpu::BufferBindingType::Uniform,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        extra_usages: wgpu::BufferUsages::COPY_DST
                    ),
                    Texture(
                        texture_bundle: diffuse,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                    ),
                    Texture(
                        texture_bundle: roughness,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                    ),
                    Texture(
                        texture_bundle: metallic,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                    ),
                    Texture(
                        texture_bundle: ao,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                    ),
                    Texture(
                        texture_bundle: normal,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                    ),
                ],
                ident: "shader_mat"
            },
            components: [
                MeshComponent<Vertex>::from_obj("assets/shaderball.obj", true).ident("_").await.unwrap(),
                TransformComponent(position: Vector3::zeros(), rotation: Bivector::new(0.0, 0.0, std::f32::consts::FRAC_PI_2).exponentiate(), ident: "transform"),
                LightManagerComponent(
                    lights: vec![Light {position: Vector3::new(4.0, 4.0, 0.0), color: [1.0; 3], brightness: 5.0}],
                    material: ident("shader_mat"),
                    shaderball_transform: ident("transform"),
                    camera_transform: ident("cam_transform")
                )
            ]
        }
    }

    engine.attach_scene(sandbox_scene);

    engine.main_loop().await;
}

#[repr(C)]
#[derive(Debug, Clone, Copy, bytemuck::Zeroable, bytemuck::Pod)]
struct Vertex {
    pos: [f32; 3],
    normal: [f32; 3],
    tex_coords: [f32; 2],
    tangent: [f32; 3],
    bitangent: [f32; 3],
}

impl VertexDescriptor for Vertex {
    const ATTRIBUTES: &[wgpu::VertexAttribute] = &vertex_attr_array![0 => Float32x3, 1 => Float32x3, 2 => Float32x2, 3 => Float32x3, 4 => Float32x3];

    fn from_data(
        VertexData {
            pos,
            normal,
            tex_coords,
            tangent,
            bitangent,
        }: VertexData,
    ) -> Self {
        Self {
            pos,
            normal,
            tex_coords,
            tangent,
            bitangent,
        }
    }
}
