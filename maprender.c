#include <maprender.h>
#include <SDL2/SDL.h>
#include <assert.h>
#include <GL/gl.h>
#include <GL/glext.h>

static SDL_Window* win;
static SDL_GLContext ctx;

int init_win (int w, int h)
{
	int ret = SDL_Init (SDL_INIT_VIDEO);
	if (ret != 0)
		return ret;

	SDL_GL_SetAttribute (SDL_GL_DOUBLEBUFFER, 1);
	SDL_GL_SetAttribute (SDL_GL_DEPTH_SIZE,  24);
	SDL_GL_SetAttribute (SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
	SDL_GL_SetAttribute (SDL_GL_CONTEXT_MAJOR_VERSION, 2);
	SDL_GL_SetAttribute (SDL_GL_CONTEXT_MINOR_VERSION, 0);

	win = SDL_CreateWindow (
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

static GLfloat nodes_[3 * 3] =
{
	-.25, -.25, 0.,
	0, 0, 0,
	.1, .5, 0
};

static const GLfloat nodes[] = {
	-1.0f, -1.0f, 0.0f,
	1.0f, -1.0f, 0.0f,
	0.0f,  1.0f, 0.0f,
};

int init_gl (int w, int h)
{
	//if (compile_shaders () != 0)
	//return 1;

	GLuint foo;
	glGenVertexArrays (1, &foo);
	glBindVertexArray (foo);

	glClearColor (.9f, .1f, .1f, 1.f);
	glViewport (0, 0, w, h);

	// gen texture
	//glEnable (GL_TEXTURE_2D);
	//glActiveTexture	(GL_TEXTURE0);
	//glGenTextures (1, &tex);
	//glBindTexture (GL_TEXTURE_2D, tex);
	//glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	//glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	//glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	//glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

	// generate vertex buffer for vertices and texture coords
	glGenBuffers (1, &vbo_nodes);
	//glGenBuffers (1, &vbo_tex);

	glBindBuffer (GL_ARRAY_BUFFER, vbo_nodes);
	glBufferData (GL_ARRAY_BUFFER, 3 * 3 * sizeof (GLfloat), nodes, GL_STATIC_DRAW);
	//GLuint vertex_attrib_location = glGetAttribLocation (program, "vertex");
	glEnableVertexAttribArray (0);
	glVertexAttribPointer (0, 3, GL_FLOAT, 0, 0, 0);

	//glBindBuffer (GL_ARRAY_BUFFER, texture_vbo);
	//glBufferData (GL_ARRAY_BUFFER, 6 * 2 * sizeof (GLfloat), texture_coords, GL_STATIC_DRAW);
	//GLuint texture_attrib_location = glGetAttribLocation (program, "texture_coords_in");
	//glEnableVertexAttribArray (texture_attrib_location);
	//glVertexAttribPointer (texture_attrib_location, 2, GL_FLOAT, 0, 0, 0);

	//glUniform1i (glGetUniformLocation (program, "tex"), 0);

	//color_uniform = glGetAttribLocation (program, "color_in");
	//glVertexAttrib4f (color_uniform, 1.0, 1.0, 1.0, 1.0);

	return 0;
}

#define W 800
#define H 600

void init ()
{
	assert (init_win (W, H) == 0);
	assert (init_gl (W, H) == 0);
}

void draw ()
{
	glClear (GL_COLOR_BUFFER_BIT);
	//glColor3b (255, 255, 255);

	glEnableVertexAttribArray (0);
	glBindBuffer (GL_ARRAY_BUFFER, vbo_nodes);
	glDrawArrays (GL_TRIANGLES, 0, 3);
	glDisableVertexAttribArray (0);

	SDL_GL_SwapWindow (win);
}

void handle_events (int* done)
{
	static SDL_Event ev;
	while (SDL_PollEvent (&ev))
	{
		if (ev.type == SDL_QUIT)
			*done = 1;
		if (ev.type == SDL_KEYUP && ev.key.keysym.sym == SDLK_q)
			*done = 1;
	}
}

int main ()
{
	int w = 800, h = 600;
	init ();
	draw ();

	int done = 0;
	while (!done)
	{
		draw ();
		handle_events (&done);
	}
}
