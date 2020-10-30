#version 460
precision highp float;

uniform sampler2D tex;

in vec2 texture_coords;
in vec4 color;

layout (location = 0) out vec4 frag_color;

void main ()
{
	vec4 bg = vec4 (1.0, 1.0, 1.0, 1.0);
	frag_color = texture2D (tex, texture_coords) * color * bg;
}
