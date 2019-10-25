/******************************************************************************
 * change the expect rules during the status of bugs
 * ***************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct filter {
	char *path;
	int error;
	int nocheck;
};

static struct filter *filter_init(char *except_file)
{
	static struct filter filters[8192];
	char cmd[256];
	FILE *in;
	size_t len;
	char *line;
	int i;
	int total;

	snprintf(cmd, sizeof(cmd), "exceptions %s", except_file);
	if (!(in = popen(cmd, "r"))) {
		fprintf(stderr, "popen exceptions failed");
		return NULL;
	}

	i = 0;
	total = 0;
	len = 0;
	line = NULL;
	while (-1 != getline(&line, &len, in)){
		line[strlen(line) -1] = '\0';
		if (0 == (total % 2)) {
			filters[i].path = strdup(line);
		} else {
			sscanf(line, "%d %d\n", &filters[i].error, &filters[i].nocheck);
			i++;
			if (i > (sizeof(filters) / sizeof(struct filter) - 1)) {
				fprintf(stderr, "filter exceeds the array");
				break;
			}
		}
		total++;
	}
	
	return filters;
}

void filter_result(char *path, int *error, int *nocheck, char *except_file)
{
	int i;
	static struct filter *filters = NULL;

	if(nocheck)*nocheck = 0;
	if (!filters) filters = filter_init(except_file);

	if (!filters) return;

	i = 0;
	while (filters[i].path) {
		if (0 == strcmp(path, filters[i].path)) {
			*error = filters[i].error;
			if(nocheck)*nocheck = filters[i].nocheck;
		}
		i++;
	}
}
