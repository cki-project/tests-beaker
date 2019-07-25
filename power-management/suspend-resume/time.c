#include <stdio.h>
#include <time.h>

int main(int argc, const char *argv[])
{
	time_t result;

	result = time(NULL);

	printf("%s%ju secs since the Epoch\n",
			asctime(localtime(&result)),
			result);

	return 0;
}
