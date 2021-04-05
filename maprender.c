#include <maprender.h>
#include <assert.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include <stdio.h>


static void check_errors()
{
	GLenum e = glGetError ();
	if (e != GL_NO_ERROR)
	{
		switch (e)
		{
			case GL_NO_ERROR:
				fprintf (stderr, "GL_NO_ERROR\n");
				break;

			case GL_INVALID_ENUM:
				fprintf (stderr, "GL_INVALID_ENUM\n");
				break;

			case GL_INVALID_VALUE:
				fprintf (stderr, "GL_INVALID_VALUE\n");
				break;

			case GL_INVALID_OPERATION:
				fprintf (stderr, "GL_INVALID_OPERATION\n");
				break;

			case GL_STACK_OVERFLOW:
				fprintf (stderr, "GL_STACK_OVERFLOW\n");
				break;

			case GL_STACK_UNDERFLOW:
				fprintf (stderr, "GL_STACK_UNDERFLOW\n");
				break;

			case GL_OUT_OF_MEMORY:
				fprintf (stderr, "GL_OUT_OF_MEMORY\n");
				break;
		}
	}
}

/**
 * Compile the shader at `filepath` as `shadertype`.
 * The resulting shader can be referenced `*shader`.
 */
static int compile_shader (const char* filepath, GLuint* shader, GLuint shadertype)
{
	size_t result, file_size;

	// open file and get the size of it
	FILE* fp = fopen (filepath, "rb");
	if (!fp)
	{
		fprintf (stderr, "could not open shader source file\n");
		return 1;
	}
	fseek (fp, 0, SEEK_END);
	file_size = ftell (fp);
	rewind (fp);

	// read content of shader
	uint8_t* src = (uint8_t *) calloc (file_size, 1);
	if ((result = fread (src, 1, file_size - 1, fp)) != file_size - 1)
	{
		fprintf (stderr, "could not read entire shader\n");
		return 1;
	}
	fclose (fp);

	// compile the shader
	int status;
	*shader = glCreateShader (shadertype);
	glShaderSource (*shader, 1, (const char **) &src, 0);
	glCompileShader (*shader);
	glGetShaderiv (*shader, GL_COMPILE_STATUS, &status);
	if (status == GL_FALSE)
	{
		GLint log_size = 0;
		glGetShaderiv (*shader, GL_INFO_LOG_LENGTH, &log_size);

		char error_log[log_size];
		glGetShaderInfoLog (*shader, log_size, &log_size, error_log);

		fprintf (stderr, "error compiling shader\n%s\n", error_log);
		return 1;
	}

	// cleanup
	free (src);
	return 0;
}

/**
 * Shader programs.
 */
static GLuint vertexshader, fragmentshader, program;

/**
 * Compile all the shaders and link to a program.
 */
static int compile_shaders ()
{
	int res;

	res = compile_shader ("vertex.glsl", &vertexshader, GL_VERTEX_SHADER);
	if (res != 0)
	{
		fprintf (stderr, "error compiling vertex shader: %d\n", res);
		return res;
	}

	res = compile_shader ("fragment.glsl", &fragmentshader, GL_FRAGMENT_SHADER);
	if (res != 0)
	{
		fprintf (stderr, "error compiling fragment shader: %d\n", res);
		return res;
	}

	// create the shader program and attach the shaders
	program = glCreateProgram ();
	glAttachShader (program, fragmentshader);
	glAttachShader (program, vertexshader);
	glLinkProgram (program);
	glUseProgram (program);

	return 0;
}

static GLuint tex;
static GLuint vbo_nodes;
static GLuint vbo_tex;
static GLuint color;
static GLuint vx;
static GLuint vxo;
static GLuint vxd;

#define N_WAYS_DRAW 1024

static GLsizei w, h;

int map_init (int w_, int h_)
{
	if (compile_shaders () != 0)
		return 1;

	// generate vertex buffer for vertices and texture coords
	glGenBuffers (1, &vbo_nodes);
	glGenBuffers (1, &vbo_tex);

	vx = glGetAttribLocation (program, "vertex");
	color = glGetAttribLocation (program, "color_in");
	vxo = glGetAttribLocation (program, "o");
	vxd = glGetAttribLocation (program, "d");

	// viewport
	w = w_, h = h_;

	return 0;
}

static int* ways_idx_primary;
static int* ways_idx_secondary;
static int* ways_idx_tertiary;

static int* ways_size_primary;
static int* ways_size_secondary;
static int* ways_size_tertiary;

static size_t ways_n_primary;
static size_t ways_n_secondary;
static size_t ways_n_tertiary;

void map_load_nodes (float* nodes, size_t n)
{
	glBindBuffer (GL_ARRAY_BUFFER, vbo_nodes);
	glBufferData (GL_ARRAY_BUFFER, n * 2 * sizeof (GLfloat), nodes, GL_STATIC_DRAW);
}

void map_load_primary_ways (int* way_idx, int* way_size, size_t wn)
{
	ways_idx_primary = way_idx;
	ways_size_primary = way_size;
	ways_n_primary = wn;
}

void map_load_secondary_ways (int* way_idx, int* way_size, size_t wn)
{
	ways_idx_secondary = way_idx;
	ways_size_secondary = way_size;
	ways_n_secondary = wn;
}

void map_load_tertiary_ways (int* way_idx, int* way_size, size_t wn)
{
	ways_idx_tertiary = way_idx;
	ways_size_tertiary = way_size;
	ways_n_tertiary = wn;
}

static void draw_highways (GLint* way_idx, GLsizei* way_size, GLsizei n)
{
	for (int i = 0; i < n; i += N_WAYS_DRAW)
		glMultiDrawArrays (GL_LINE_STRIP, way_idx + i, way_size + i, N_WAYS_DRAW);

	int reset = n % N_WAYS_DRAW;
	glMultiDrawArrays (GL_LINE_STRIP, way_idx + n - reset, way_size + n - reset, n % N_WAYS_DRAW);
}

void map_draw (float origx, float origy, float view_width, float view_height)
{
	glUseProgram (program);
	glClearColor (.1f, .1f, .1f, 1.f);
	glClear (GL_COLOR_BUFFER_BIT);
	glViewport (0, 0, w, h);

	glBindBuffer (GL_ARRAY_BUFFER, vbo_nodes);
	glEnableVertexAttribArray (vx);
	glVertexAttribPointer (vx, 2, GL_FLOAT, 0, 0, 0);

	glVertexAttrib2f (vxo, origx, origy);
	glVertexAttrib2f (vxd, view_width, view_height);

	glVertexAttrib4f (color, 0.0, 1.0, 1.0, 1.0);
	glLineWidth (1.);
	draw_highways (ways_idx_primary, ways_size_primary, ways_n_primary);

	glVertexAttrib4f (color, 1.0, 0.0, 1.0, 1.0);
	glLineWidth (1.);
	draw_highways (ways_idx_secondary, ways_size_secondary, ways_n_secondary);

	glVertexAttrib4f (color, 1.0, 1.0, 1.0, 1.0);
	glLineWidth (1.);
	draw_highways (ways_idx_tertiary, ways_size_tertiary, ways_n_tertiary);

	glDisableVertexAttribArray (vx);
}
