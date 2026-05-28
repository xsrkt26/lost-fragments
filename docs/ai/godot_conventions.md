# Godot Conventions

- Prefer Godot-native scene/resource workflows over ad hoc runtime construction.
- Keep scene scripts focused on scene behavior; move reusable logic into services, resources, or small helpers.
- Use exported properties for designer-tuned values when they belong in the editor.
- Keep node paths stable and document intentional scene tree contracts.
