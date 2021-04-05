#include <stdlib.h>
#include <GL/gl.h>

/**
 * map_load_nodes loads all the nodes into the vertex buffer ready for rendering.
 */
void map_load_nodes (float* nodes, size_t n) ;

/**
 * map_load_primary_ways loads the primary ways.
 * These ways are ways like motorways and highways.
 *
 *		- way_idx is a list of indices pointing to the first node that were loaded
 *		using `map_load_nodes`.
 *		- way_size is a list of number of nodes that each corresponding way is made up of.
 *		- m is the total number of ways in `way_idx` and `way_size`.
 */
void map_load_primary_ways (int* way_idx, int* way_size, size_t m) ;

/**
 * map_load_secondary loads the secondary ways.
 * These are the more important roads within a country.
 *
 *		- way_idx is a list of indices pointing to the first node that were loaded
 *		using `map_load_nodes`.
 *		- way_size is a list of number of nodes that each corresponding way is made up of.
 *		- m is the total number of ways in `way_idx` and `way_size`.
 */
void map_load_secondary_ways (int* way_idx, int* way_size, size_t m) ;

/**
 * map_load_tertiary_ways loads the tertiary ways.
 * These are the smallest kind of roads such as residential.
 *
 *		- way_idx is a list of indices pointing to the first node that were loaded
 *		using `map_load_nodes`.
 *		- way_size is a list of number of nodes that each corresponding way is made up of.
 *		- m is the total number of ways in `way_idx` and `way_size`.
 */
void map_load_tertiary_ways (int* way_idx, int* way_size, size_t m) ;

/**
 * map_init initializes the map renderer to the given size in pixels.
 */
int map_init (int, int, GLuint*) ;

/**
 * map_draw will render the map with the loaded nodes and ways.
 *
 *		- origx is x coordinate of the origin (upper left corner) in WGS48.
 *		- origy is y coordinate of the origin (upper left corner) in WGS48.
 *		- view_width is the width of the view box in WGS48.
 *		- view_width is the height of the view box in WGS48.
 */
void map_draw (float origx, float origy, float view_width, float view_height) ;
