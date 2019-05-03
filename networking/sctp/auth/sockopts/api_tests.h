#ifndef SCTP_API_TEST_H
#define SCTP_API_TEST_H

#define REGISTER_APITEST(suite, case) {0, #suite"_"#case, #suite, suite##case}
#define DECLARE_APITEST(suite, case) extern char *suite##case(void)
#define DEFINE_APITEST(suite, case) char *suite##case(void)
#define RETURN_FAILED(format, ...) \
		do { \
			snprintf(description, 41, format, ##__VA_ARGS__); \
			return (description); \
		} while (0)
#define RETURN_FAILED_WITH_ERRNO \
		return (strerror(errno))
#define RETURN_PASSED return (NULL)

struct test {
	int enabled;
	char *case_name;
	char *suite_name;
	char *(*func)(void);
};

char description[41];

#define I_AM_HERE \
		do { \
			printf("%s:%d at %s\n", __FILE__, __LINE__ , __FUNCTION__); \
		} while (0)

#endif
