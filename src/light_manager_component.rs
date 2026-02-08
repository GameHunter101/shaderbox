use algoe::bivector::Bivector;
use nalgebra::Vector3;
use v4::{
    builtin_components::transform_component::TransformComponent,
    component,
    ecs::{
        component::{ComponentDetails, ComponentId, ComponentSystem, UpdateParams},
        material::ShaderAttachment,
    },
};

#[derive(Debug, Clone, Copy)]
pub struct Light {
    pub position: Vector3<f32>,
    pub color: [f32; 3],
    pub brightness: f32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, bytemuck::Pod, bytemuck::Zeroable, Default)]
pub struct RawLight {
    position: [f32; 3],
    enabled: i32,
    color: [f32; 3],
    brightness: f32,
}

#[component]
pub struct LightManagerComponent {
    lights: Vec<Light>,
    material: ComponentId,
    shaderball_transform: ComponentId,
}

impl ComponentSystem for LightManagerComponent {
    fn update(
        &mut self,
        UpdateParams {
            queue,
            materials,
            engine_details,
            other_components,
            ..
        }: UpdateParams<'_, '_>,
    ) -> v4::ecs::actions::ActionQueue {
        /* if let Some(light) = self.lights.get_mut(0) {
            light.position = Bivector::new(0.0, 0.0, 0.001).exponentiate() * light.position;
        } */

        let cursor_delta = engine_details.cursor_delta.0;
        if engine_details
            .mouse_state
            .contains(&winit::event::MouseButton::Left)
            && let Some(component) = other_components
                .iter_mut()
                .filter(|comp| comp.id() == self.shaderball_transform)
                .next()
            && let Some(transform) = component.downcast_mut::<TransformComponent>()
        {
            let rotation = transform.get_rotation();
            let updated_rotation = (rotation * Bivector::new(0.0, 0.0, cursor_delta * 0.005).exponentiate()).normalize();
            transform.set_rotation(updated_rotation);
        }

        let shaderball_mat = materials
            .iter_mut()
            .filter(|mat| mat.id() == self.material)
            .next();
        if let Some(material) = shaderball_mat
            && let ShaderAttachment::Buffer(buf) = &material.attachments()[0]
        {
            let raw_data: Vec<RawLight> = (0..10)
                .map(|i| {
                    if let Some(light) = self.lights.get(i) {
                        RawLight {
                            position: light.position.into(),
                            enabled: 1,
                            color: light.color,
                            brightness: light.brightness,
                        }
                    } else {
                        RawLight::default()
                    }
                })
                .collect();
            queue.write_buffer(buf.buffer(), 0, bytemuck::cast_slice(&raw_data));
        }
        Vec::new()
    }
}
