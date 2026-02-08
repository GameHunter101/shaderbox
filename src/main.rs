use crate::light_manager_component::{LightManagerComponent, RawLight, Light};
use algoe::bivector::Bivector;
use nalgebra::Vector3;
use v4::{
    V4,
    builtin_components::{
        camera_component::CameraComponent,
        mesh_component::{MeshComponent, VertexDescriptor},
        transform_component::TransformComponent,
    },
    scene,
};
use wgpu::{Color, vertex_attr_array};

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

    scene! {
        scene: sandbox_scene,
        active_camera: "cam",
        "cam_ent" = {
            components: [
                CameraComponent(field_of_view: 60.0, aspect_ratio: 1.0, near_plane: 0.1, far_plane: 50.0, sensitivity: 0.000, movement_speed: 0.0, ident: "cam"),
                TransformComponent(position: Vector3::new(0.0, 1.5, -4.0), rotation: Bivector::new(0.0, -std::f32::consts::FRAC_PI_6 / 2.0, 0.0).exponentiate())
            ]
        },
        "shader_model" = {
            material: {
                pipeline: {
                    vertex_shader_path: "shaders/vertex.wgsl",
                    fragment_shader_path: "shaders/fragment.wgsl",
                    vertex_layouts: [Vertex::vertex_layout(), TransformComponent::vertex_layout::<3>()],
                    uses_camera: true,
                },
                attachments: [
                    Buffer(
                        device: device,
                        data: bytemuck::cast_slice(&[RawLight::default(); 10]),
                        buffer_type: wgpu::BufferBindingType::Uniform,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        extra_usages: wgpu::BufferUsages::COPY_DST
                    )
                ],
                ident: "shader_mat"
            },
            components: [
                MeshComponent<Vertex>::from_obj("assets/shaderball.obj", true).ident("_").await.unwrap(),
                TransformComponent(position: Vector3::zeros(), rotation: Bivector::new(0.0, 0.0, std::f32::consts::FRAC_PI_2).exponentiate(), ident: "transform"),
                LightManagerComponent(
                    lights: vec![Light {position: Vector3::new(4.0, 2.0, 0.0), color: [0.18, 0.149, 0.431], brightness: 2.0}],
                    material: ident("shader_mat"),
                    shaderball_transform: ident("transform")
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
}

impl VertexDescriptor for Vertex {
    const ATTRIBUTES: &[wgpu::VertexAttribute] =
        &vertex_attr_array![0 => Float32x3, 1 => Float32x3, 2 => Float32x2];

    fn from_pos_normal_coords(pos: Vec<f32>, normal: Vec<f32>, tex_coords: Vec<f32>) -> Self {
        Self {
            pos: pos.try_into().unwrap(),
            normal: normal.try_into().unwrap(),
            tex_coords: tex_coords.try_into().unwrap(),
        }
    }
}
