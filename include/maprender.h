#include <stdlib.h>

void map_load_nodes (float* nodes, size_t n) ;

void map_load_primary_ways (int* way_idx, int* way_size, size_t m) ;

void map_load_secondary_ways (int* way_idx, int* way_size, size_t m) ;

void map_load_tertiary_ways (int* way_idx, int* way_size, size_t m) ;

int map_init (int, int) ;

void map_draw (float origx, float origy, float view_width, float view_height) ;
