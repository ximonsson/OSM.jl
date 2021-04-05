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

int main ()
{
	init_win (W, H);
	map_init (W, H);
	map_load_nodes (vitoria_nodes, NNODES);
	map_load_primary_ways (way_idx, way_counts, 5000);
	map_load_secondary_ways (way_idx + 5000, way_counts + 5000, 5000);
	map_load_tertiary_ways (way_idx + 10000, way_counts + 10000, NWAYS - 10000);
	map_draw (origx, origy, view_width, view_height);

	int done = 0;
	while (!done)
	{
		map_draw (origx, origy, view_width, view_height);
		SDL_GL_SwapWindow (win);
		handle_events (&done);
	}

	destroy_win ();
}
