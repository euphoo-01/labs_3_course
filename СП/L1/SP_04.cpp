#include <dlfcn.h>
#include <stdio.h>

typedef int (*BinaryOperation)(int, int);

int main()
{
    void* library = dlopen("./SP_XX.so", RTLD_LAZY);

    if (library == NULL)
    {
        printf("Failed to load SP_XX.so: %s\n", dlerror());
        return 1;
    }

    BinaryOperation sumFunc =
        (BinaryOperation)dlsym(library, "sum");

    BinaryOperation subFunc =
        (BinaryOperation)dlsym(library, "sub");

    BinaryOperation mulFunc =
        (BinaryOperation)dlsym(library, "mul");

    BinaryOperation divFunc =
        (BinaryOperation)dlsym(library, "div");

    char* error = dlerror();

    if (error != NULL)
    {
        printf("Failed to find function: %s\n", error);
        dlclose(library);
        return 1;
    }

    int x = 10;
    int y = 2;

    printf("sum(%d, %d) = %d\n", x, y, sumFunc(x, y));
    printf("sub(%d, %d) = %d\n", x, y, subFunc(x, y));
    printf("mul(%d, %d) = %d\n", x, y, mulFunc(x, y));
    printf("div(%d, %d) = %d\n", x, y, divFunc(x, y));

    dlclose(library);

    return 0;
}
