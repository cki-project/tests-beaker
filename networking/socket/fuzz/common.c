#include	"func.h"

#undef rand
int tst_rand(int start, int end)
{
	struct timeval t;
	/* get time seed */
	gettimeofday(&t, NULL);
	srand(t.tv_usec * t.tv_sec);
	return ((rand() % (end - start + 1)) + start);
}

int likely()
{
	if(tst_rand(0, 9) > 0)
		return TRUE;
	else
		return FALSE;
}

int unlikely()
{
	if(tst_rand(0, 9) < 1)
		return TRUE;
	else
		return FALSE;
}
