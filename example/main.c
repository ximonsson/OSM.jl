/**
 * This is a test application with exported nodes and ways defined in nodes.c and ways.c
 * that represent Vitoria, Esperito Santo, Brazil.
 */

#include <maprender.h>
#include <SDL2/SDL.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include "nodes.c"
#include "ways.c"
#include <assert.h>

#define W 1000
#define H 1000
#define NWAYS 28663
#define NNODES 167123
#define OX -40.497
#define OY -20.516
#define ViewW .5
#define ViewH .5


static SDL_Window* win;
static SDL_GLContext ctx;

static GLfloat origx = OX;
static GLfloat origy = OY;
static GLfloat view_width = ViewW;
static GLfloat view_height = ViewH;
static GLuint tex;


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

float texCoords[] = {
	0.0f, 0.0f,  // lower-left corner
	1.0f, 0.0f,  // lower-right corner
	0.5f, 1.0f   // top-center corner
};

/*
float vertices[] = {
// positions          // colors           // texture coords
0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f,   // top right
0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f,   // bottom right
-0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f,   // bottom left
-0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f    // top left
};
*/

float vertices[] = {
	0.5f,  0.5f, 0.0f,  // top right
	0.5f, -0.5f, 0.0f,  // bottom right
	-0.5f, -0.5f, 0.0f,  // bottom left
	-0.5f,  0.5f, 0.0f   // top left
};
unsigned int indices[] = {  // note that we start from 0!
	0, 1, 3,   // first triangle
	1, 2, 3    // second triangle
};

const char* vertexSource = "#version 460\n"
	"in vec2 position;\n"
	"void main()\n"
	"{\n"
	"	gl_Position = vec4(position, 0.0, 1.0);\n"
	"}\n";


const char* fragSource = "#version 460\n"
	"out vec4 FragColor;\n"
	"void main()\n"
	"{\n"
	"	FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
	"}\n";

int main ()
{
	init_win (W, H);
	assert (map_init (W, H, &tex) == 0);
	map_load_nodes (vitoria_nodes, NNODES);
	map_load_primary_ways (way_idx, way_counts, NWAYS);
	//map_load_secondary_ways (way_idx + 5000, way_counts + 5000, 5000);
	//map_load_tertiary_ways (way_idx + 10000, way_counts + 10000, NWAYS - 10000);

	unsigned int vertexShader;
	vertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vertexShader, 1, &vertexSource, NULL);
	glCompileShader(vertexShader);

	unsigned int fragmentShader;
	fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fragmentShader, 1, &fragSource, NULL);
	glCompileShader(fragmentShader);

	unsigned int shaderProgram;
	shaderProgram = glCreateProgram();

	glAttachShader(shaderProgram, vertexShader);
	glAttachShader(shaderProgram, fragmentShader);
	glLinkProgram(shaderProgram);


	unsigned int VBO;
	glGenBuffers(1, &VBO);
	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

	int done = 0;
	while (!done)
	{
		map_draw (origx, origy, view_width, view_height);

		glUseProgram (shaderProgram);

		glBindTexture (GL_TEXTURE_2D, tex);

		// 1. then set the vertex attributes pointers
		//glEnableVertexAttribArray(VBO);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
		glEnableVertexAttribArray(0);

		glUseProgram (0);

		//glBindTexture (GL_TEXTURE_2D, 0);

		SDL_GL_SwapWindow (win);
		handle_events (&done);
	}

	destroy_win ();
}
