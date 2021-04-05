#version 460

in vec2 vertex;
in vec2 texture_coords_in;
in vec4 color_in;
in vec2 d;
in vec2 o;

out vec2 texture_coords;
out vec4 color;

void main ()
{

	/*
	mat4 P = mat4(
		2.,  0., 0., 40.497,
		0., 2.,  0., 20.516,
		0., 0., 1., 0.,
		0., 0., 0., 1.
	);
	*/

	mat4 P = mat4(
		4.,  0., 0., -1.,
		0., 4.,  0., -1.,
		0., 0., 1., 0.,
		0., 0., 0., 1.
	);

	mat4 V = mat4(
		1., 0., 0., 40.497,
		0., 1., 0., 20.516,
		0., 0., 1., 0,
		0., 0., 0., 1.
	);
	//*/

	//mat4 P = V * T;

	//vec4 v = V * vec4 (vertex, 0., 1.);
	vec4 v = vec4 ((vertex - o) / d, 0., 1);
	v = v * 2. - 1.;

	gl_Position = v;

	texture_coords = texture_coords_in;
	color = color_in;
}
