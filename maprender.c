#include <maprender.h>
#include <SDL2/SDL.h>
#include <assert.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include "nodes.c"
#include "ways.c"

static SDL_Window* win;
static SDL_GLContext ctx;

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

static GLuint vertexshader, fragmentshader, program;

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
	glLinkProgram  (program);
	glUseProgram   (program);

	return 0;
}

int init_win (int w, int h)
{
	int ret = SDL_Init (SDL_INIT_VIDEO);
	if (ret != 0)
		return ret;

	SDL_GL_SetAttribute (SDL_GL_DOUBLEBUFFER, 1);
	SDL_GL_SetAttribute (SDL_GL_DEPTH_SIZE,  24);
	SDL_GL_SetAttribute (SDL_GL_CONTEXT_PROFILE_MASK, 1);
	SDL_GL_SetAttribute (SDL_GL_CONTEXT_MAJOR_VERSION, 2);
	SDL_GL_SetAttribute (SDL_GL_CONTEXT_MINOR_VERSION, 0);

	win = SDL_CreateWindow
	(
		"map viewer",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		w,
		h,
		SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN
	);

	ctx = SDL_GL_CreateContext (win);
	SDL_GL_SetSwapInterval (1);
	return 0;
}

void destroy_win ()
{
	SDL_GL_DeleteContext (ctx);
	SDL_DestroyWindow (win);
	SDL_Quit ();
}

static GLuint tex;
static GLuint vbo_nodes;
static GLuint vbo_tex;
static GLuint color;
static GLuint vx;
static GLuint vxo;
static GLuint vxd;

#define W 1000
#define H 1000
#define NWAYS 28663
#define NNODES 167123
#define OX -40.497
#define OY -20.516
#define ViewW .5
#define ViewH .5

int init_gl (int w, int h)
{
	if (compile_shaders () != 0)
		return 1;

	glClearColor (.1f, .1f, .1f, 1.f);
	glViewport (0, 0, w, h);

	// generate vertex buffer for vertices and texture coords
	glGenBuffers (1, &vbo_nodes);
	glGenBuffers (1, &vbo_tex);

	vx = glGetAttribLocation (program, "vertex");
	color = glGetAttribLocation (program, "color_in");
	vxo = glGetAttribLocation (program, "o");
	vxd = glGetAttribLocation (program, "d");

	return 0;
}

static void init ()
{
	assert (init_win (W, H) == 0);
	assert (init_gl (W, H) == 0);
}

void load_nodes (GLfloat* nodes_, size_t n)
{
	//memcpy(nodes, nodes_, n * sizeof(float));
	glBindBuffer (GL_ARRAY_BUFFER, vbo_nodes);
	glBufferData (GL_ARRAY_BUFFER, n * 2 * sizeof (GLfloat), nodes_, GL_STATIC_DRAW);
}

static GLfloat origx = OX;
static GLfloat origy = OY;
static GLfloat view_width = ViewW;
static GLfloat view_height = ViewH;

static void draw ()
{
	glClear (GL_COLOR_BUFFER_BIT);

	glBindBuffer (GL_ARRAY_BUFFER, vbo_nodes);
	glEnableVertexAttribArray (vx);
	glVertexAttribPointer (vx, 2, GL_FLOAT, 0, 0, 0);

	glVertexAttrib2f (vxo, origx, origy);
	glVertexAttrib2f (vxd, view_width, view_height);

	glVertexAttrib4f (color, 1.0, 1.0, 1.0, 1.0);
	glLineWidth (1.);

	int *wi = way_idx;
	int *wc = way_counts;

	int nn = 1000;
	int i = 0;
	for (; i < (NWAYS / nn); i ++)
		glMultiDrawArrays (GL_LINE_STRIP, wi + i * nn, wc + i * nn, nn);
	glMultiDrawArrays (GL_LINE_STRIP, wi + i * nn, wc + i * nn, NWAYS % nn);

	//for (int i = 0; i < NWAYS; i ++)
		//glDrawArrays (GL_LINE_STRIP, wi[i], wc[i]);

	glDisableVertexAttribArray (vx);

	SDL_GL_SwapWindow (win);
}

void handle_events (int* done)
{
	float delta = 0.01;
	static SDL_Event ev;
	while (SDL_PollEvent (&ev))
	{
		if (ev.type == SDL_QUIT)
			*done = 1;
		else if (ev.type == SDL_KEYUP && ev.key.keysym.sym == SDLK_q)
			*done = 1;

		if (ev.type == SDL_KEYDOWN)
		{
			switch (ev.key.keysym.sym)
			{
				case SDLK_w:
					origy += delta;
					break;

				case SDLK_s:
					origy -= delta;
					break;

				case SDLK_a:
					origx -= delta;
					break;

				case SDLK_d:
					origx += delta;
					break;

				case SDLK_j:
					view_width -= delta;
					view_height -= delta;
					origx += delta / 2.;
					origy += delta / 2.;
					break;

				case SDLK_k:
					view_width += delta;
					view_height += delta;
					origx -= delta / 2.;
					origy -= delta / 2.;
					break;
			}
		}
	}
}

int main ()
{
	int w = W, h = H;
	init ();
	load_nodes (vitoria_nodes, NNODES);
	draw ();

	int done = 0;
	while (!done)
	{
		draw ();
		handle_events (&done);
	}

	destroy_win ();
}
