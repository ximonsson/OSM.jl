#version 460

in vec2 vertex;
in vec4 color_in;
in vec2 d;
in vec2 o;

out vec4 color;

void main ()
{
	mat4 P = mat4(
		2.,  0., 0., 0.,
		0., 2.,  0., 0.,
		0., 0., 1., 0.,
		-1., -1., 0., 1.
	);

	mat4 V = mat4(
		1./d.x, 0., 0., 0.,
		0., 1./d.y, 0., 0.,
		0., 0., 1., 0.,
		0., 0., 0., 1.
	);

	mat4 M = mat4(
		1., 0., 0., 0.,
		0., 1., 0., 0.,
		0., 0., 1., 0,
		-o.x, -o.y, 0., 1.
	);

	vec4 v = P * V * M * vec4 (vertex, 0., 1.);

	gl_Position = v;
	color = color_in;
}
