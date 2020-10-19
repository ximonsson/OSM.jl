
typedef
struct way
{
	int n;
	float* points;
}
way;

void new_way (way *, int nodes);

void destroy_way (way * v);

