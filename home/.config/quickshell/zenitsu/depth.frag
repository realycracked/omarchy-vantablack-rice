#version 440
// Effet de profondeur léger (style waydeeper) : chaque pixel est décalé selon
// sa profondeur (carte IA) et la position de la souris.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 offset;   // souris (-1..1) * force
    float zoom;    // léger zoom pour ne jamais voir les bords
    float pivot;   // profondeur qui ne bouge pas
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D depth;

void main() {
    vec2 uv = (qt_TexCoord0 - 0.5) / zoom + 0.5;
    // recherche itérative : on retrouve le pixel qui atterrit ici
    vec2 o = vec2(0.0);
    for (int i = 0; i < 4; i++) {
        float d = texture(depth, uv - o).r;
        o = offset * (d - pivot);
    }
    fragColor = texture(src, clamp(uv - o, 0.0, 1.0)) * qt_Opacity;
}
